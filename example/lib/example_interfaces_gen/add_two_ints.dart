// generated from rosidl_generator_dart (test harness)
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

// ---- example_interfaces__srv__AddTwoInts_Request ----
base class example_interfaces__srv__AddTwoInts_Request extends ffi.Struct {
  @ffi.Int64()
  external int a;
  @ffi.Int64()
  external int b;
}

class ExampleInterfacesAddTwoInts_Request extends BaseRosMessage<example_interfaces__srv__AddTwoInts_Request> {
  @override
  String get typeName => 'AddTwoInts_Request';
  @override
  String get packageName => 'example_interfaces';

  ExampleInterfacesAddTwoInts_Request() {
    data = calloc<example_interfaces__srv__AddTwoInts_Request>();
  }

  int get a =>
      data.ref.a;
  set a(int val) =>
      data.ref.a = val;
  int get b =>
      data.ref.b;
  set b(int val) =>
      data.ref.b = val;
}

// ---- example_interfaces__srv__AddTwoInts_Response ----
base class example_interfaces__srv__AddTwoInts_Response extends ffi.Struct {
  @ffi.Int64()
  external int sum;
}

class ExampleInterfacesAddTwoInts_Response extends BaseRosMessage<example_interfaces__srv__AddTwoInts_Response> {
  @override
  String get typeName => 'AddTwoInts_Response';
  @override
  String get packageName => 'example_interfaces';

  ExampleInterfacesAddTwoInts_Response() {
    data = calloc<example_interfaces__srv__AddTwoInts_Response>();
  }

  int get sum =>
      data.ref.sum;
  set sum(int val) =>
      data.ref.sum = val;
}

// ---- ExampleInterfacesAddTwoInts (service) ----
class ExampleInterfacesAddTwoInts
    extends BaseRosService<ExampleInterfacesAddTwoInts_Request, ExampleInterfacesAddTwoInts_Response> {
  @override
  String get typeName => 'AddTwoInts';
  @override
  String get packageName => 'example_interfaces';

  @override
  ExampleInterfacesAddTwoInts_Request createRequest() => ExampleInterfacesAddTwoInts_Request();

  @override
  ExampleInterfacesAddTwoInts_Response createResponse() => ExampleInterfacesAddTwoInts_Response();
}
