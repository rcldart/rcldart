// generated from rosidl_generator_dart (test harness)
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:rcldart_utils/rcldart_utils.dart';
import 'package:std_msgs/std_msgs.dart';

final class rosidl_runtime_c__String extends ffi.Struct {
  external ffi.Pointer<ffi.Char> data;
  @ffi.Size()
  external int size;
  @ffi.Size()
  external int capacity;
}

final class rosidl_runtime_c__String__Sequence extends ffi.Struct {
  external ffi.Pointer<rosidl_runtime_c__String> data;
  @ffi.Size()
  external int size;
  @ffi.Size()
  external int capacity;
}

final class rosidl_runtime_c__double__Sequence extends ffi.Struct {
  external ffi.Pointer<ffi.Double> data;
  @ffi.Size()
  external int size;
  @ffi.Size()
  external int capacity;
}

// ---- sensor_msgs__msg__JointState ----
base class sensor_msgs__msg__JointState extends ffi.Struct {
  external std_msgs__msg__Header header;
  external rosidl_runtime_c__String__Sequence name;
  external rosidl_runtime_c__double__Sequence position;
  external rosidl_runtime_c__double__Sequence velocity;
  external rosidl_runtime_c__double__Sequence effort;
}

class SensorMsgsJointState extends BaseRosMessage<sensor_msgs__msg__JointState> {
  @override
  String get typeName => 'JointState';
  @override
  String get packageName => 'sensor_msgs';

  SensorMsgsJointState() {
    data = calloc<sensor_msgs__msg__JointState>();
  }

  // TODO(dart-gen): high-level accessor for 'header' not generated;
  // reach the field directly via `data.ref.header`.
  List<String> get name {
    final s = data.ref.name;
    return List.generate(s.size, (i) {
      final e = s.data[i];
      if (e.data == ffi.nullptr || e.size == 0) return '';
      return e.data.cast<Utf8>().toDartString(length: e.size);
    });
  }
  set name(List<String> value) {
    final a = calloc<rosidl_runtime_c__String>(value.length);
    for (var i = 0; i < value.length; i++) {
      final b = value[i].toNativeUtf8();
      a[i].data = b.cast<ffi.Char>();
      a[i].size = b.length;
      a[i].capacity = b.length + 1;
    }
    data.ref.name.data = a;
    data.ref.name.size = value.length;
    data.ref.name.capacity = value.length;
  }
  List<double> get position {
    final s = data.ref.position;
    return List.generate(s.size, (i) => s.data[i]);
  }
  set position(List<double> value) {
    final a = calloc<ffi.Double>(value.length);
    for (var i = 0; i < value.length; i++) {
      a[i] = value[i];
    }
    data.ref.position.data = a;
    data.ref.position.size = value.length;
    data.ref.position.capacity = value.length;
  }
  List<double> get velocity {
    final s = data.ref.velocity;
    return List.generate(s.size, (i) => s.data[i]);
  }
  set velocity(List<double> value) {
    final a = calloc<ffi.Double>(value.length);
    for (var i = 0; i < value.length; i++) {
      a[i] = value[i];
    }
    data.ref.velocity.data = a;
    data.ref.velocity.size = value.length;
    data.ref.velocity.capacity = value.length;
  }
  List<double> get effort {
    final s = data.ref.effort;
    return List.generate(s.size, (i) => s.data[i]);
  }
  set effort(List<double> value) {
    final a = calloc<ffi.Double>(value.length);
    for (var i = 0; i < value.length; i++) {
      a[i] = value[i];
    }
    data.ref.effort.data = a;
    data.ref.effort.size = value.length;
    data.ref.effort.capacity = value.length;
  }
}
