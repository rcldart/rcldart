import 'dart:ffi';
import 'package:rcldart/src/msgs/std_msgs_float.dart';
import 'package:rcldart/src/msgs/std_msgs_int32.dart';

import 'package:rcldart/src/rcldart.dart';

import 'gen/rcldart_bindings_generated.dart';
import 'msgs/std_msgs_string.dart';

class Publisher {
  final Pointer<rcl_publisher_s> nativePublisher;

  late StdMsgsString msg;

  late StdMsgsInt32 intmsg;
  late StdMsgsFloat floatmsg;
  //late StdMsgsFloatX int64msg;

  Publisher(this.nativePublisher) {
    msg = StdMsgsString(
        "Hello Flutter/Dart Lover, I publishing over rcldart for ROS2 <3");
    intmsg = StdMsgsInt32(32);
    floatmsg = StdMsgsFloat(15.0);
    //int64msg = StdMsgsFloatX(160.0);
  }

  void publish() {
    // print(intmsg.int32Msg.value);
    print(floatmsg.int32Msg.value);
    // rcldartbindings.rcl_publish(nativePublisher, intmsg.int32Msg.cast(), nullptr);
    rcldartbindings.rcl_publish(nativePublisher, floatmsg.int32Msg.cast(), nullptr);
    // rcldartbindings.rcl_publish(nativePublisher, msg.strMsg.cast(), nullptr);

    // ffi.calloc.free(intmsg.int32Msg.ref.data);
    // ffi.calloc.free(intmsg.int32Msg);
  }
}
