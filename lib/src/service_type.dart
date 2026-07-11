// src/service_type.dart
//
// Service type support for rcldart. The service *definition* itself
// (`BaseRosService`: Request/Response factories + type-support symbol) lives in
// `rcldart_utils` so it can be shared with, and produced by, the rosidl Dart
// generator. This file only adds the piece that needs rcldart's generated
// bindings: resolving the native `rosidl_service_type_support_t*` handle.
import 'dart:ffi';

import 'package:rcldart_utils/rcldart_utils.dart';

import 'gen/rcldart_bindings_generated.dart';

/// Native signature of a `..._get_service_type_support_handle__...` function.
typedef ServiceTypeSupportFunc = Pointer<rosidl_service_type_support_t>
    Function();

extension ServiceTypeSupport on BaseRosService {
  /// Resolves and returns the native service type-support handle by looking up
  /// [BaseRosService.typeSupportName] in [BaseRosService.rosidlGeneratorDylib].
  Pointer<rosidl_service_type_support_t> get typeSupportHandle {
    final fn = rosidlGeneratorDylib
        .lookup<NativeFunction<ServiceTypeSupportFunc>>(typeSupportName)
        .asFunction<ServiceTypeSupportFunc>();
    return fn();
  }
}
