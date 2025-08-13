// src/msgs/std_msgs_types.dart
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:rcldart/src/gen/rcldart_bindings_generated.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

base class std_msgs__msg__Bool extends ffi.Struct {
  @ffi.Uint8()
  external int data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}

// Bool type
class StdMsgsBool extends BaseRosMessage<std_msgs__msg__Bool> {
  @override
  String get typeName => 'Bool';

  StdMsgsBool(bool value) {
    data = calloc<std_msgs__msg__Bool>();
    data.ref.data = value ? 1 : 0;
  }

  bool get value {
    data = nativeData.cast<std_msgs__msg__Bool>();
    return data.ref.data == 1;
  }
  set value(bool val) {
    var data_ = nativeData.cast<std_msgs__msg__Bool>();
    data_.ref.data = val ? 1 : 0;
    data = data_;
  }
}


base class std_msgs__msg__Byte extends ffi.Struct {
  @ffi.Uint8()
  external int data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}

// Byte type
class StdMsgsByte extends BaseRosMessage<std_msgs__msg__Byte> {
  @override
  String get typeName => 'Byte';

  StdMsgsByte(int value) {
    data = calloc<std_msgs__msg__Byte>();
    data.ref.data = value;
  }

  int get value => data.ref.data;
  set value(int val) => data.ref.data = val;
}


base class std_msgs__msg__Char extends ffi.Struct {
  @ffi.Uint8()
  external int data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}


// Char type
class StdMsgsChar extends BaseRosMessage<std_msgs__msg__Char> {
  @override
  String get typeName => 'Char';

  StdMsgsChar(int value) {
    data = calloc<std_msgs__msg__Char>();
    data.ref.data = value;
  }

  int get value => data.ref.data;
  set value(int val) => data.ref.data = val;
}


base class std_msgs__msg__Int8 extends ffi.Struct {
  @ffi.Int8()
  external int data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}


// Int8 type
class StdMsgsInt8 extends BaseRosMessage<std_msgs__msg__Int8> {
  @override
  String get typeName => 'Int8';

  StdMsgsInt8(int value) {

    var valuePtr = calloc<std_msgs__msg__Int8>();
    valuePtr.ref.data = value;
    data = valuePtr;
  }

  int get value => data.ref.data;
  set value(int val) => data.ref.data = val;
}



base class std_msgs__msg__Int16 extends ffi.Struct {
  @ffi.Int16()
  external int data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}


// Int16 type
class StdMsgsInt16 extends BaseRosMessage<std_msgs__msg__Int16> {
  @override
  String get typeName => 'Int16';

  StdMsgsInt16(int value) {

    var valuePtr = calloc<std_msgs__msg__Int16>();
    valuePtr.ref.data = value;
    data = valuePtr;
  }

  int get value => data.ref.data;
  set value(int val) => data.ref.data = val;
}


base class std_msgs__msg__Int32 extends ffi.Struct {
  @ffi.Int32()
  external int data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}


// Int32 type - Following your existing pattern
class StdMsgsInt32 extends BaseRosMessage<std_msgs__msg__Int32> {
  @override
  String get typeName => 'Int32';

  StdMsgsInt32(int value) {

    var value2 = calloc<std_msgs__msg__Int32>();
    value2.ref.data = value;
    data = value2;
  }

  int get value => data.ref.data;
  set value(int val) => data.ref.data = val;
}

base class std_msgs__msg__Int64 extends ffi.Struct {
  @ffi.Int64()
  external int data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}

// Int64 type
class StdMsgsInt64 extends BaseRosMessage<std_msgs__msg__Int64> {
  @override
  String get typeName => 'Int64';

  StdMsgsInt64(int value) {
    var valuePtr = calloc<std_msgs__msg__Int64>();
    valuePtr.ref.data = value;
    data = valuePtr;
  }

  int get value => data.ref.data;
  set value(int val) => data.ref.data = val;
}

base class std_msgs__msg__Uint8 extends ffi.Struct {
  @ffi.Uint8()
  external int data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}

// UInt8 type
class StdMsgsUInt8 extends BaseRosMessage<std_msgs__msg__Uint8> {
  @override
  String get typeName => 'UInt8';

  StdMsgsUInt8(int value) {
    var valuePtr = calloc<std_msgs__msg__Uint8>();
    valuePtr.ref.data = value;
    data = valuePtr;
  }

  
  int get value => data.ref.data;
  set value(int val) => data.ref.data = val;
}

base class std_msgs__msg__Uint16 extends ffi.Struct {
  @ffi.Uint16()
  external int data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}

// UInt16 type
class StdMsgsUInt16 extends BaseRosMessage<std_msgs__msg__Uint16> {
  @override
  String get typeName => 'UInt16';

  StdMsgsUInt16(int value) {
    var valuePtr = calloc<std_msgs__msg__Uint16>();
    valuePtr.ref.data = value;
    data = valuePtr;
  }

  int get value => data.ref.data;
  set value(int val) => data.ref.data = val;
}

base class std_msgs__msg__Uint32 extends ffi.Struct {
  @ffi.Uint32()
  external int data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}

// UInt32 type
class StdMsgsUInt32 extends BaseRosMessage<std_msgs__msg__Uint32> {
  @override
  String get typeName => 'UInt32';

  StdMsgsUInt32(int value) {
    var valuePtr = calloc<std_msgs__msg__Uint32>();
    valuePtr.ref.data = value;
    data = valuePtr;
  }

  int get value => data.ref.data;
  set value(int val) => data.ref.data = val;
}

base class std_msgs__msg__Uint64 extends ffi.Struct {
  @ffi.Uint64()
  external int data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}

// UInt64 type
class StdMsgsUInt64 extends BaseRosMessage<std_msgs__msg__Uint64> {
  @override
  String get typeName => 'UInt64';

  StdMsgsUInt64(int value) {
    var valuePtr = calloc<std_msgs__msg__Uint64>();
    valuePtr.ref.data = value;
    data = valuePtr;
  }

  int get value => data.ref.data;
  set value(int val) => data.ref.data = val;
}

base class std_msgs__msg__Float32 extends ffi.Struct {
  @ffi.Float()
  external double data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}

// Float32 type - Following your existing pattern from std_msgs_float.dart
class StdMsgsFloat32 extends BaseRosMessage<std_msgs__msg__Float32> {
  @override
  String get typeName => 'Float32';

  StdMsgsFloat32(double value) {
    var value2 = calloc<std_msgs__msg__Float32>();
    value2.ref.data = value;
    this.data = value2;
  }

  double get value => data.ref.data;
  set value(double val) => data.ref.data = val;
}

base class std_msgs__msg__Float64 extends ffi.Struct {
  @ffi.Double()
  external double data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}

// Float64 type
class StdMsgsFloat64 extends BaseRosMessage<std_msgs__msg__Float64> {
  @override
  String get typeName => 'Float64';

  StdMsgsFloat64(double value) {
    var valuePtr = calloc<std_msgs__msg__Float64>();
    valuePtr.ref.data = value;
    data = valuePtr;
  }

  double get value => data.ref.data;
  set value(double val) => data.ref.data = val;
}

// String type - Following your existing pattern from std_msgs_string.dart
class StdMsgsString extends BaseRosMessage<rosidl_runtime_c__String> {
  @override
  String get typeName => 'String';

  StdMsgsString(String message) {

    var valuePtr = calloc<rosidl_runtime_c__String>();
    valuePtr.ref.data = message.toNativeUtf8().cast<ffi.Char>();
    data = valuePtr;
  }

  String get value {
    return data.ref.data.cast<Utf8>().toDartString();
  }

  set value(String val) {
    final rosidl_runtime_c__String__assign = rosidlGeneratorDylib
        .lookup<
            ffi.NativeFunction<
                ffi.Bool Function(ffi.Pointer<rosidl_runtime_c__String>,
                    ffi.Pointer<ffi.Char>)>>('rosidl_runtime_c__String__assign')
        .asFunction<
            bool Function(ffi.Pointer<rosidl_runtime_c__String>,
                ffi.Pointer<ffi.Char>)>();

    var rc = rosidl_runtime_c__String__assign(
        data, val.toNativeUtf8().cast<ffi.Char>());
    if (!rc) {
      throw Exception("unable to assign value to stringMsg");
    }
  }
}

// Empty type
class StdMsgsEmpty extends BaseRosMessage<ffi.Uint8> {
  @override
  String get typeName => 'Empty';

  StdMsgsEmpty() {
    data = calloc<ffi.Uint8>();
    data.value = 0; // Empty message has no meaningful data
  }
}

// ColorRGBA type - needs proper ROS2 struct definition
class StdMsgsColorRGBA extends BaseRosMessage<std_msgs__msg__ColorRGBA> {
  @override
  String get typeName => 'ColorRGBA';

  StdMsgsColorRGBA(
      {double r = 0.0, double g = 0.0, double b = 0.0, double a = 1.0}) {
    data = malloc<std_msgs__msg__ColorRGBA>();
    data.ref.r = r;
    data.ref.g = g;
    data.ref.b = b;
    data.ref.a = a;
  }

  double get r => data.ref.r;
  double get g => data.ref.g;
  double get b => data.ref.b;
  double get a => data.ref.a;

  set r(double val) => data.ref.r = val;
  set g(double val) => data.ref.g = val;
  set b(double val) => data.ref.b = val;
  set a(double val) => data.ref.a = val;
}

// Header type - needs proper ROS2 struct definition
class StdMsgsHeader extends BaseRosMessage<std_msgs__msg__Header> {
  @override
  String get typeName => 'Header';

  late StdMsgsTime stamp;
  late StdMsgsString frameId;

  StdMsgsHeader({String frameId = 'base_link'}) {
    data = malloc<std_msgs__msg__Header>();
    stamp = StdMsgsTime();
    this.frameId = StdMsgsString(frameId);

    // Set current time
    var now = DateTime.now();
    stamp.sec = now.millisecondsSinceEpoch ~/ 1000;
    stamp.nanosec = (now.microsecondsSinceEpoch % 1000000) * 1000;

    data.ref.stamp = stamp.data.ref;
    data.ref.frame_id = this.frameId.data.ref;
  }

  @override
  void dispose() {
    stamp.dispose();
    frameId.dispose();
    super.dispose();
  }
}

// Time type
class StdMsgsTime extends BaseRosMessage<builtin_interfaces__msg__Time> {
  @override
  String get typeName => 'Time';

  StdMsgsTime({int sec = 0, int nanosec = 0}) {
    data = malloc<builtin_interfaces__msg__Time>();
    data.ref.sec = sec;
    data.ref.nanosec = nanosec;
  }

  int get sec => data.ref.sec;
  int get nanosec => data.ref.nanosec;

  set sec(int val) => data.ref.sec = val;
  set nanosec(int val) => data.ref.nanosec = val;

  DateTime toDateTime() {
    return DateTime.fromMillisecondsSinceEpoch(sec * 1000 + nanosec ~/ 1000000);
  }
}

// Duration type
class StdMsgsDuration
    extends BaseRosMessage<builtin_interfaces__msg__Duration> {
  @override
  String get typeName => 'Duration';

  StdMsgsDuration({int sec = 0, int nanosec = 0}) {
    data = malloc<builtin_interfaces__msg__Duration>();
    data.ref.sec = sec;
    data.ref.nanosec = nanosec;
  }

  int get sec => data.ref.sec;
  int get nanosec => data.ref.nanosec;

  set sec(int val) => data.ref.sec = val;
  set nanosec(int val) => data.ref.nanosec = val;
}

// Required ROS2 struct definitions (these should be in your generated bindings)
base class std_msgs__msg__ColorRGBA extends ffi.Struct {
  @ffi.Float()
  external double r;
  @ffi.Float()
  external double g;
  @ffi.Float()
  external double b;
  @ffi.Float()
  external double a;
}

base class std_msgs__msg__Header extends ffi.Struct {
  external builtin_interfaces__msg__Time stamp;
  external rosidl_runtime_c__String frame_id;
}

base class builtin_interfaces__msg__Time extends ffi.Struct {
  @ffi.Int32()
  external int sec;
  @ffi.Uint32()
  external int nanosec;
}

base class builtin_interfaces__msg__Duration extends ffi.Struct {
  @ffi.Int32()
  external int sec;
  @ffi.Uint32()
  external int nanosec;
}
