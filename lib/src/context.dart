import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'package:rcldart/src/rcldart.dart';

import 'gen/rcldart_bindings_generated.dart';

class Context {
  final Pointer<rcl_context_t> nativeContext;

  Context._internal(this.nativeContext);

  factory Context() {
    final nativeContext = malloc<rcl_context_s>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_context();

    return Context._internal(nativeContext);
  }
}
