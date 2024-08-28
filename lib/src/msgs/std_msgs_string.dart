import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart' ;


import '../util/dynamic_library_loader.dart';

class StdMsgsString {
  late ffi.Pointer<std_msgs__msg__String> strMsg;

  static final rosidlGenerateorDylib =
      dynamiclibraryloader("std_msgs__rosidl_generator_c");

  StdMsgsString(String message) {
    var tmp =  calloc<rosidl_runtime_c__String>();
    final _rosidl_runtime_c__String__assign = rosidlGenerateorDylib
        .lookup<
            ffi.NativeFunction<
                ffi.Bool Function(ffi.Pointer<rosidl_runtime_c__String>,
                    ffi.Pointer<ffi.Char>)>>('rosidl_runtime_c__String__assign')
        .asFunction<
            bool Function(ffi.Pointer<rosidl_runtime_c__String>,
                ffi.Pointer<ffi.Char>)>();

    var rc = _rosidl_runtime_c__String__assign(
        tmp, message.toNativeUtf8().cast<ffi.Char>());
    if (!rc) {
      throw Exception("unable to assign value to stringMsg");
    }

    strMsg = malloc<std_msgs__msg__String>()..ref.data = tmp.ref;
  }
}

/// Struct defined in msg/String in the package std_msgs.
/// /**
///   * This was originally provided as an example message.
///   * It is deprecated as of Foxy
///   * It is recommended to create your own semantically meaningful message.
///   * However if you would like to continue using this please use the equivalent in example_msgs.
///  */
base class std_msgs__msg__String extends ffi.Struct {
  external rosidl_runtime_c__String data;
}

/// An array of 8-bit characters terminated by a null byte.
base class rosidl_runtime_c__String extends ffi.Struct {
  /// The pointer to the first character, the sequence ends with a null byte.
  external ffi.Pointer<ffi.Char> data;

  /// The length of the string (excluding the null byte).
  @ffi.Size()
  external int size;

  /// The capacity represents the number of allocated bytes (including the null byte).
  @ffi.Size()
  external int capacity;
}


