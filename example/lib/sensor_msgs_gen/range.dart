// generated from rosidl_generator_dart (test harness)
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:rcldart_utils/rcldart_utils.dart';
import 'package:std_msgs/std_msgs.dart';

// ---- sensor_msgs__msg__Range ----
base class sensor_msgs__msg__Range extends ffi.Struct {
  external std_msgs__msg__Header header;
  @ffi.Uint8()
  external int radiation_type;
  @ffi.Float()
  external double field_of_view;
  @ffi.Float()
  external double min_range;
  @ffi.Float()
  external double max_range;
  @ffi.Float()
  external double range;
  @ffi.Float()
  external double variance;
}

class SensorMsgsRange extends BaseRosMessage<sensor_msgs__msg__Range> {
  @override
  String get typeName => 'Range';
  @override
  String get packageName => 'sensor_msgs';

  SensorMsgsRange() {
    data = calloc<sensor_msgs__msg__Range>();
  }

  static const int ULTRASOUND =
      0;
  static const int INFRARED =
      1;
  // TODO(dart-gen): high-level accessor for 'header' not generated;
  // reach the field directly via `data.ref.header`.
  int get radiationType =>
      data.ref.radiation_type;
  set radiationType(int val) =>
      data.ref.radiation_type = val;
  double get fieldOfView =>
      data.ref.field_of_view;
  set fieldOfView(double val) =>
      data.ref.field_of_view = val;
  double get minRange =>
      data.ref.min_range;
  set minRange(double val) =>
      data.ref.min_range = val;
  double get maxRange =>
      data.ref.max_range;
  set maxRange(double val) =>
      data.ref.max_range = val;
  double get range_ =>
      data.ref.range;
  set range_(double val) =>
      data.ref.range = val;
  double get variance =>
      data.ref.variance;
  set variance(double val) =>
      data.ref.variance = val;
}
