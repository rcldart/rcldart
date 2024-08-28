import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:rcldart/src/util/dynamic_library_loader.dart';

class StdMsgsFloat {
  late ffi.Pointer<ffi.Float> int32Msg;

  static final rosidlGeneratorDylib =
      dynamiclibraryloader("std_msgs__rosidl_generator_c");

  StdMsgsFloat(double value) {

    var tmp2 = calloc<ffi.Float>();
    

   var _rosidl_runtime_c__float_t__assign_native =
        rosidlGeneratorDylib
            .lookup<
                ffi.NativeFunction<
                    ffi.Bool Function(
                        ffi.Pointer<ffi.Float>,
                        ffi.Size)>>(
            'rosidl_runtime_c__float__Sequence__init')
        .asFunction<
            bool Function(ffi.Pointer<ffi.Float>,
                int)>();

  

    final ffi.Pointer<ffi.Int32> myIntValue = calloc<ffi.Int32>(1);
    myIntValue.value = 42;

    var rc2=_rosidl_runtime_c__float_t__assign_native(tmp2,ffi.sizeOf<ffi.Int32>());
      if (!rc2) {
      throw Exception("Unable to assign value to int32Msg");
    }

    var value2=calloc<ffi.Float>();
    value2.value=15.toDouble();
    int32Msg = value2 ;

  }
}


class StdMsgsInt64 {
  late ffi.Pointer<ffi.Int64> int32Msg;

  static final rosidlGeneratorDylib =
      dynamiclibraryloader("std_msgs__rosidl_generator_c");

  StdMsgsInt64(double value) {

    var tmp2 = calloc<ffi.Int64>();
    

   var _rosidl_runtime_c__float_t__assign_native =
        rosidlGeneratorDylib
            .lookup<
                ffi.NativeFunction<
                    ffi.Bool Function(
                        ffi.Pointer<ffi.Int64>,
                        ffi.Size)>>(
            'rosidl_runtime_c__int64__Sequence__init')
        .asFunction<
            bool Function(ffi.Pointer<ffi.Int64>,
                int)>();

  

    final ffi.Pointer<ffi.Int64> myIntValue = calloc<ffi.Int64>();
    myIntValue.value = 42;

    var rc2=_rosidl_runtime_c__float_t__assign_native(tmp2,ffi.sizeOf<ffi.Int64>());
      if (!rc2) {
      throw Exception("Unable to assign value to int32Msg");
    }

    var value2=calloc<ffi.Int64>();
    value2.value=15;
    int32Msg = value2 ;

  }
}

class RosMessage<T extends ffi.NativeType> {
  late ffi.Pointer<T> data;
  //late ffi.Pointer<ffi.NativeFunction<ffi.Bool Function(ffi.Pointer<T>,ffi.Size)>> _destroyFn;

  RosMessage(String type, String subfolder, String msgName, ffi.Pointer<T> Function() initFn) {
    data = initFn();
  }


}

class StdMsgsFloatX extends RosMessage<ffi.Float> {
  late ffi.Pointer<ffi.Float> msg;
  static final rosidlGeneratorDylib = dynamiclibraryloader("std_msgs__rosidl_generator_c");

  static final _initFloatMsg = rosidlGeneratorDylib
      .lookup<ffi.NativeFunction<ffi.Pointer<ffi.Float> Function()>>('rosidl_runtime_c__float__Sequence__init')
      .asFunction<ffi.Pointer<ffi.Float> Function()>();

  static final _destroyFloatMsg = rosidlGeneratorDylib
      .lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Float>)>>('rosidl_runtime_c__float_Sequence__init');

  StdMsgsFloatX(double value) : super('std_msgs', 'msg', 'Float', _initFloatMsg) {
    data.value = value;
  }

  double getValue() {
    return data.value;
  }

  void setValue(double value) {
    data.value = value;
  }
}

