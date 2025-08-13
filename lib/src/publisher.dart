// src/publisher.dart
import 'dart:ffi';

import 'package:rcldart/src/rcldart.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

import 'gen/rcldart_bindings_generated.dart';

class Publisher <T extends BaseRosMessage> {
  final Pointer<rcl_publisher_s> nativePublisher;

  Publisher(this.nativePublisher);

  void publish(T message) {
    if (message.data == null) {
      throw ArgumentError('Message data cannot be null');
    }
    // print("📦 Publishing message: ${message.data}");

    rcldartbindings.rcl_publish(
        nativePublisher, message.data.cast(), nullptr);
  }
}
