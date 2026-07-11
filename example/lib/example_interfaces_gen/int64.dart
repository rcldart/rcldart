// generated from rosidl_generator_dart (test harness)
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

// ---- example_interfaces__msg__Int64 ----
base class example_interfaces__msg__Int64 extends ffi.Struct {
  @ffi.Int64()
  external int data;
}

class ExampleInterfacesInt64 extends BaseRosMessage<example_interfaces__msg__Int64> {
  @override
  String get typeName => 'Int64';
  @override
  String get packageName => 'example_interfaces';

  ExampleInterfacesInt64() {
    data = calloc<example_interfaces__msg__Int64>();
  }

  int get value =>
      data.ref.data;
  set value(int val) =>
      data.ref.data = val;
}
