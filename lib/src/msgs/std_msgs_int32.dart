import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:rcldart/src/util/dynamic_library_loader.dart';

import 'package:rcldart/src/gen/rcldart_bindings_generated.dart';


/// Struct defined in msg/Int32 in the package std_msgs.
// class std_msgs__msg__Int32 extends ffi.Struct {
//   // external rosidl_runtime_c__int32_t data;
//   external ffi.Pointer<rosidl_runtime_c__int32> data;
// }



class StdMsgsInt32 {
  late ffi.Pointer<ffi.Int32> int32Msg;

  static final rosidlGeneratorDylib =
      dynamiclibraryloader("std_msgs__rosidl_generator_c");

  StdMsgsInt32(int value) {
    // Allocate memory for rosidl_runtime_c__int32_t
    // var tmp = calloc<std_msgs__msg__Int32>();
    var tmp2 = calloc<ffi.Int32>();

    // Assign the int value to rosidl_runtime_c__int32_t
    var _rosidl_runtime_c__int32_t__assign_native = rosidlGeneratorDylib
        .lookup<
            ffi.NativeFunction<
                ffi.Bool Function(ffi.Pointer<ffi.Int32>,
                    ffi.Size)>>('rosidl_runtime_c__int32__Sequence__init')
        .asFunction<bool Function(ffi.Pointer<ffi.Int32>, int)>();

    var _rosidl_runtime_c__float_t__assign_native = rosidlGeneratorDylib
        .lookup<
            ffi.NativeFunction<
                ffi.Bool Function(ffi.Pointer<ffi.Float>,
                    ffi.Size)>>('rosidl_runtime_c__int32__Sequence__init')
        .asFunction<bool Function(ffi.Pointer<ffi.Float>, int)>();

    // .lookupFunction<
    //     ffi.Int32 Function(
    //         ffi.Pointer<rosidl_runtime_c__int32__Sequence>, ffi.Int32),
    //     int Function(ffi.Pointer<rosidl_runtime_c__int32__Sequence>,
    //         int)>('rosidl_runtime_c__int32__Sequence__init');

    // final _rosidl_runtime_c__int32_t__assign = rosidlGeneratorDylib
    //     .lookup<
    //             ffi.NativeFunction<
    //                 ffi.Bool Function(
    //                     ffi.Pointer<std_msgs__msg__Int32>,
    //                     ffi.Size)>>(
    //         'rosidl_runtime_c__int32__Sequence__init')
    //     .asFunction<
    //         bool Function(ffi.Pointer<std_msgs__msg__Int32>,
    //             int)>();

    final ffi.Pointer<ffi.Int32> myIntValue = calloc<ffi.Int32>(1);
    myIntValue.value = 42; // Set your integer value
    // tmp.ref.data=myIntValue;
    // var rc = _rosidl_runtime_c__int32_t__assign(
    //     tmp, ffi.Pointer<ffi.Int32>.fromAddress(myIntValue));

    // var rc = _rosidl_runtime_c__int32_t__assign(tmp, ffi.sizeOf<std_msgs__msg__Int32>());
    // print(rc);

    // print(myIntValue.address);
    var rc2 = _rosidl_runtime_c__int32_t__assign_native(
        tmp2, ffi.sizeOf<ffi.Int32>());
    // print(rc2);
    if (!rc2) {
      throw Exception("Unable to assign value to int32Msg");
    }

    // var rc = _rosidl_runtime_c__int32_t__assign(tmp, value.toString().toNativeUtf8().cast<ffi.Int32>());
    // if (rc!=0) {
    //   throw Exception("Unable to assign value to int32Msg");
    // }

    // tmp2=myIntValue;

    // print(tmp.ref.data.address);
    // int32Msg = calloc<std_msgs__msg__Int32>()
    //   ..ref.data = tmp.ref.data;
    // int32Msg = calloc<std_msgs__msg__Int32>()
    //   ..ref.data = tmp.ref.data;
    // print(int32Msg.address);
    // print(int32Msg.ref.data.ref.data);

    // int32Msg = tmp;
    // Allocate memory for std_msgs__msg__Int32
    var value2 = calloc<ffi.Int32>();
    value2.value = 15;
    // value.ref.data=myIntValue;
    // value.ref=tmp2.ref;
    int32Msg = value2;

    // Allocate memory for int32_t
    // var myIntValue2 = calloc<ffi.Int32>(1);
    // myIntValue2.value = value;

    // Set size and data fields of rosidl_runtime_c__int32__Sequence
    // int32Msg.ref.size = 1;
    // int32Msg.ref.data = myIntValue2;

    // Assign the data field
    // int32Msg.ref.data = tmp.ref;
  }
}
