// generated from rosidl_generator_dart (test harness)
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

final class rosidl_runtime_c__String extends ffi.Struct {
  external ffi.Pointer<ffi.Char> data;
  @ffi.Size()
  external int size;
  @ffi.Size()
  external int capacity;
}

// ---- example_interfaces__msg__String ----
base class example_interfaces__msg__String extends ffi.Struct {
  external rosidl_runtime_c__String data;
}

class ExampleInterfacesString extends BaseRosMessage<example_interfaces__msg__String> {
  @override
  String get typeName => 'String';
  @override
  String get packageName => 'example_interfaces';

  ExampleInterfacesString() {
    data = calloc<example_interfaces__msg__String>();
    value = '';
  }

  String get value {
    final s = data.ref.data;
    if (s.data == ffi.nullptr || s.size == 0) return '';
    return s.data.cast<Utf8>().toDartString(length: s.size);
  }
  set value(String val) {
    final b = val.toNativeUtf8();
    data.ref.data.data = b.cast<ffi.Char>();
    data.ref.data.size = b.length;
    data.ref.data.capacity = b.length + 1;
  }
}
