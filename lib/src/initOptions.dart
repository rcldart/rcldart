import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'package:rcldart/src/rcldart.dart';

import 'gen/rcldart_bindings_generated.dart';

class InitOptions {
  final Pointer<rcl_init_options_t> nativeInitOptions;

  InitOptions._internal(this.nativeInitOptions);

  factory InitOptions() {
    var allocator = rcldartbindings.rcutils_get_default_allocator();
    return InitOptions.withAllocator(allocator);
  }

  factory InitOptions.withAllocator(rcutils_allocator_s allocator) {
    var initOptions = malloc<rcl_init_options_t>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_init_options();

    var rc = rcldartbindings.rcl_init_options_init(initOptions, allocator);
    if (rc != RCL_RET_OK) {
      throw Exception("unable to initialize init_options");
    }
    return InitOptions._internal(initOptions);
  }
}
