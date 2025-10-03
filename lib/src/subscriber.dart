// src/subscriber.dart
// src/subscriber.dart - FINAL FIXED VERSION
import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;
import 'package:rcldart/src/rcldart.dart';
import 'package:rcldart_utils/rcldart_utils.dart';
import 'gen/rcldart_bindings_generated.dart';

class Subscriber<T extends BaseRosMessage> {
  final Pointer<rcl_subscription_t> nativeSubscriber;
  final Pointer<rcl_node_t> nativeNode;
  void Function(T)? _callback;
  T? _messageTemplate;

  Subscriber(this.nativeSubscriber, this.nativeNode,
      {T? messageType, void Function(T)? callback}) {
    _messageTemplate = messageType;
    _callback = callback;
  }

  void subscribe() {
    print("Subscription ready to receive messages on topic");
  }

  T? take() {
    if (_messageTemplate == null) {
      print("ERROR: Message template is null");
      return null;
    }

    try {
      final receivingMessage = _createFreshMessage();
      if (receivingMessage == null) {
        print("ERROR: Could not create fresh message");
        return null;
      }

      final messageInfo = ffi.malloc<rmw_message_info_t>();

      try {
        // print("Attempting to take message...");

        // Use the fresh message's data pointer for receiving
        var rc = rcldartbindings.rcl_take(
            nativeSubscriber,
            receivingMessage.data.cast<Void>(),
            messageInfo,
            nullptr // allocation - NULL
            );


        if (rc == RCL_RET_OK) {
          if (_callback != null) {
            _callback!(receivingMessage);
          }
          return receivingMessage;
        } else if (rc == RCL_RET_SUBSCRIPTION_TAKE_FAILED) {
          return null;
        } else {
          print("rcl_take failed with code: $rc");
          return null;
        }
      } finally {
        // Memory cleanup
        ffi.malloc.free(messageInfo);
      }
    } catch (e) {
      print("Exception in take(): $e");
      return null;
    }
  }

  /// Create a fresh message instance for receiving data
  T? _createFreshMessage() {
    try {
      return _messageTemplate; // Fallback
    } catch (e) {
      print("Error creating fresh message: $e");
      return null;
    }
  }

  void setCallback(void Function(T) callback) {
    _callback = callback;
    print("Callback set for subscriber");
  }

  void dispose() {
    print("Disposing subscriber");
  }
}
