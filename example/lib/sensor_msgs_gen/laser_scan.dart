// generated from rosidl_generator_dart (test harness)
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:rcldart_utils/rcldart_utils.dart';
import 'package:std_msgs/std_msgs.dart';

final class rosidl_runtime_c__float__Sequence extends ffi.Struct {
  external ffi.Pointer<ffi.Float> data;
  @ffi.Size()
  external int size;
  @ffi.Size()
  external int capacity;
}

// ---- sensor_msgs__msg__LaserScan ----
base class sensor_msgs__msg__LaserScan extends ffi.Struct {
  external std_msgs__msg__Header header;
  @ffi.Float()
  external double angle_min;
  @ffi.Float()
  external double angle_max;
  @ffi.Float()
  external double angle_increment;
  @ffi.Float()
  external double time_increment;
  @ffi.Float()
  external double scan_time;
  @ffi.Float()
  external double range_min;
  @ffi.Float()
  external double range_max;
  external rosidl_runtime_c__float__Sequence ranges;
  external rosidl_runtime_c__float__Sequence intensities;
}

class SensorMsgsLaserScan extends BaseRosMessage<sensor_msgs__msg__LaserScan> {
  @override
  String get typeName => 'LaserScan';
  @override
  String get packageName => 'sensor_msgs';

  SensorMsgsLaserScan() {
    data = calloc<sensor_msgs__msg__LaserScan>();
  }

  // TODO(dart-gen): high-level accessor for 'header' not generated;
  // reach the field directly via `data.ref.header`.
  double get angleMin =>
      data.ref.angle_min;
  set angleMin(double val) =>
      data.ref.angle_min = val;
  double get angleMax =>
      data.ref.angle_max;
  set angleMax(double val) =>
      data.ref.angle_max = val;
  double get angleIncrement =>
      data.ref.angle_increment;
  set angleIncrement(double val) =>
      data.ref.angle_increment = val;
  double get timeIncrement =>
      data.ref.time_increment;
  set timeIncrement(double val) =>
      data.ref.time_increment = val;
  double get scanTime =>
      data.ref.scan_time;
  set scanTime(double val) =>
      data.ref.scan_time = val;
  double get rangeMin =>
      data.ref.range_min;
  set rangeMin(double val) =>
      data.ref.range_min = val;
  double get rangeMax =>
      data.ref.range_max;
  set rangeMax(double val) =>
      data.ref.range_max = val;
  List<double> get ranges {
    final s = data.ref.ranges;
    return List.generate(s.size, (i) => s.data[i]);
  }
  set ranges(List<double> value) {
    final a = calloc<ffi.Float>(value.length);
    for (var i = 0; i < value.length; i++) {
      a[i] = value[i];
    }
    data.ref.ranges.data = a;
    data.ref.ranges.size = value.length;
    data.ref.ranges.capacity = value.length;
  }
  List<double> get intensities {
    final s = data.ref.intensities;
    return List.generate(s.size, (i) => s.data[i]);
  }
  set intensities(List<double> value) {
    final a = calloc<ffi.Float>(value.length);
    for (var i = 0; i < value.length; i++) {
      a[i] = value[i];
    }
    data.ref.intensities.data = a;
    data.ref.intensities.size = value.length;
    data.ref.intensities.capacity = value.length;
  }
}
