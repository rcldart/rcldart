import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:rcldart/src/msgs/std_msgs_int32.dart';

import 'package:rcldart/src/rcldart.dart';

import 'gen/rcldart_bindings_generated.dart';
import 'msgs/std_msgs_string.dart';

class Subscriber {
  final Pointer<rcl_subscription_t> nativeSubscriber;
  // final Pointer<rcl_publisher_s> nativePublisher;

  Pointer<rcl_event_s> event;
  late StdMsgsString msg;

  late StdMsgsInt32 intmsg;

  Subscriber(this.event,this.nativeSubscriber) {
    // msg = StdMsgsString("valuevalu!!");
    intmsg = StdMsgsInt32(32);
  }

  void publish() {
    rcldartbindings.rcl_subscription_event_init(
        event, nativeSubscriber, 1);
    // rcldartbindings.rcl_publish(nativePublisher, msg.strMsg.cast(), nullptr);
  }
}
