// src/node.dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:rcldart/src/msgs/_std_msgs_types.dart';
import 'package:rcldart/src/publisher.dart';
import 'package:rcldart/src/rcldart.dart';
import 'package:rcldart/src/subscriber.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

import './context.dart';
import 'gen/rcldart_bindings_generated.dart';
import 'node_options.dart';

class Node {
  late final Pointer<rcl_node_s> nativeNode;
  final String nodeName;
  final String nameSpace;
  final NodeOptions nodeOptions;

  static final dylib = dynamiclibraryloader("std_msgs__rosidl_typesupport_c");

  Node._(this.nativeNode, this.nodeName, this.nameSpace, Context context,
      this.nodeOptions);

  factory Node(String nodeName, String nameSpace, Context context) {
    var nodeOptions = NodeOptions();
    return Node.withOptions(nodeName, nameSpace, context, nodeOptions);
  }

  factory Node.withOptions(String nodeName, String nameSpace, Context context,
      NodeOptions nodeOptions) {
    var nativeNode = malloc<rcl_node_s>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_node();

    var rc = rcldartbindings.rcl_node_init(
        nativeNode,
        nodeName.toNativeUtf8().cast<Char>(),
        nameSpace.toNativeUtf8().cast<Char>(),
        context.nativeContext,
        nodeOptions.nativeNodeOptions);
    if (rc != RCL_RET_OK) {
      throw Exception("unable to init node");
    }
    return Node._(nativeNode, nodeName, nameSpace, context, nodeOptions);
  }

Subscriber createSubscriber<T extends BaseRosMessage>({
  required String topic_name,
  T? messageType, // Optional message type
  void Function(T)? callback, // Callback function for received messages
}) {
  var subscription = malloc<rcl_subscription_t>()
    ..ref = rcldartbindings.rcl_get_zero_initialized_subscription();

  // Subscription options
  var options = malloc<rcl_subscription_options_t>()
    ..ref = rcldartbindings.rcl_subscription_get_default_options();

  // Type support function lookup
  final ttt = (messageType?.rosidlGeneratorDylib ?? dylib)
    .lookup<NativeFunction<_typesupportMsgFunc>>(messageType
        ?.typeSupportName ??
        'rosidl_typesupport_c__get_message_type_support_handle__std_msgs__msg__String')
    .asFunction<_typesupportMsgFunc>();

  // Subscription initialization
  var rc = rcldartbindings.rcl_subscription_init(subscription, nativeNode,
      ttt(), topic_name.toNativeUtf8().cast<Char>(), options);
      
  if (rc != RCL_RET_OK) {
    throw Exception("unable to create subscriber, error code: $rc");
  }

  print("Subscription created successfully for topic: $topic_name");

  // UPDATED: Pass nativeNode and remove event parameter
  return Subscriber<T>(subscription, nativeNode, callback: callback, messageType: messageType);
}

  Publisher createPublisher<T extends BaseRosMessage>({
    required String topic_name,
    T? messageType, // Optional message type
  }) {
    var publisher = malloc<rcl_publisher_s>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_publisher();

    var options = malloc<rcl_publisher_options_s>()
      ..ref = rcldartbindings.rcl_publisher_get_default_options();

    final ttt = (messageType?.rosidlGeneratorDylib ?? dylib)
        .lookup<NativeFunction<_typesupportMsgFunc>>(messageType
                ?.typeSupportName ??
            'rosidl_typesupport_c__get_message_type_support_handle__std_msgs__msg__Float32')
        .asFunction<_typesupportMsgFunc>();

    var rc = rcldartbindings.rcl_publisher_init(publisher, nativeNode, ttt(),
        topic_name.toNativeUtf8().cast<Char>(), options);
    if (rc != RCL_RET_OK) {
      throw Exception("unable to create publisher");
    }

    return Publisher<T>(publisher);
  }
}

typedef _typesupportMsgFunc = Pointer<rosidl_message_type_support_t> Function();
typedef _typesupportSrvFunc = Pointer<rosidl_service_type_support_t> Function();
