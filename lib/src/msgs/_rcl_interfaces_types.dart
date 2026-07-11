// src/msgs/_rcl_interfaces_types.dart
//
// Hand-written FFI bindings for the `rcl_interfaces` messages/services used by
// the ROS 2 parameter protocol. In a full setup these would be generated the
// same way `std_msgs` is; they are provided here so `NodeParameters.attachToRos`
// can expose parameters over the standard `~/get_parameters`,
// `~/set_parameters`, `~/list_parameters`, ... services.
//
// The struct field order + types below match the `rcl_interfaces` ABI for ROS 2
// Humble. Sequence storage is managed through the generated
// `__create/__destroy` and `..__Sequence__init` functions loaded at runtime
// (present in any ROS 2 install), so this stays memory-safe without a code
// generator.
//
// NOTE: this path talks to FastDDS and therefore can only be validated on a
// live ROS 2 system; treat it as "implemented, pending on-device validation".
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

import '../gen/rcldart_bindings_generated.dart';

// ---------------------------------------------------------------------------
// Runtime libraries (resolved lazily).
// ---------------------------------------------------------------------------
final DynamicLibrary _rosidlRuntime = dynamiclibraryloader('rosidl_runtime_c');
final DynamicLibrary _ifaceGen =
    dynamiclibraryloader('rcl_interfaces__rosidl_generator_c');

// rosidl_runtime_c__String__assign(String* str, const char* value) -> bool
typedef _StrAssignC = Bool Function(
    Pointer<rosidl_runtime_c__String>, Pointer<Char>);
typedef _StrAssignD = bool Function(
    Pointer<rosidl_runtime_c__String>, Pointer<Char>);
final _strAssign = _rosidlRuntime
    .lookup<NativeFunction<_StrAssignC>>('rosidl_runtime_c__String__assign')
    .asFunction<_StrAssignD>();

// rosidl_runtime_c__String__Sequence__init(seq*, size_t) -> bool
typedef _SeqInitC = Bool Function(Pointer<Void>, Size);
typedef _SeqInitD = bool Function(Pointer<Void>, int);
_SeqInitD _seqInit(DynamicLibrary lib, String symbol) =>
    lib.lookup<NativeFunction<_SeqInitC>>(symbol).asFunction<_SeqInitD>();

final _stringSeqInit =
    _seqInit(_rosidlRuntime, 'rosidl_runtime_c__String__Sequence__init');
final _uint8SeqInit =
    _seqInit(_rosidlRuntime, 'rosidl_runtime_c__uint8__Sequence__init');
final _paramValueSeqInit =
    _seqInit(_ifaceGen, 'rcl_interfaces__msg__ParameterValue__Sequence__init');
final _setResultSeqInit = _seqInit(
    _ifaceGen, 'rcl_interfaces__msg__SetParametersResult__Sequence__init');

/// Assigns a Dart [value] into a native `rosidl_runtime_c__String`.
void assignString(Pointer<rosidl_runtime_c__String> str, String value) {
  final c = value.toNativeUtf8();
  try {
    if (!_strAssign(str, c.cast<Char>())) {
      throw StateError('rosidl String assign failed for "$value"');
    }
  } finally {
    malloc.free(c);
  }
}

/// Reads a native `rosidl_runtime_c__String` back into a Dart string.
String readString(Pointer<rosidl_runtime_c__String> str) {
  if (str.ref.data == nullptr || str.ref.size == 0) return '';
  return str.ref.data.cast<Utf8>().toDartString(length: str.ref.size);
}

// ---------------------------------------------------------------------------
// Message structs (ABI-accurate, ROS 2 Humble).
// ---------------------------------------------------------------------------

/// `rcl_interfaces/msg/ParameterValue`.
base class ParameterValueC extends Struct {
  @Uint8()
  external int type;
  @Bool()
  external bool bool_value;
  @Int64()
  external int integer_value;
  @Double()
  external double double_value;
  external rosidl_runtime_c__String string_value;
  external rosidl_runtime_c__octet__Sequence byte_array_value;
  external rosidl_runtime_c__boolean__Sequence bool_array_value;
  external rosidl_runtime_c__int64__Sequence integer_array_value;
  external rosidl_runtime_c__double__Sequence double_array_value;
  external rosidl_runtime_c__String__Sequence string_array_value;
}

final class ParameterValueSeq extends Struct {
  external Pointer<ParameterValueC> data;
  @Size()
  external int size;
  @Size()
  external int capacity;
}

/// `rcl_interfaces/msg/Parameter`.
base class ParameterC extends Struct {
  external rosidl_runtime_c__String name;
  external ParameterValueC value;
}

final class ParameterSeq extends Struct {
  external Pointer<ParameterC> data;
  @Size()
  external int size;
  @Size()
  external int capacity;
}

/// `rcl_interfaces/msg/SetParametersResult`.
base class SetParametersResultC extends Struct {
  @Bool()
  external bool successful;
  external rosidl_runtime_c__String reason;
}

final class SetParametersResultSeq extends Struct {
  external Pointer<SetParametersResultC> data;
  @Size()
  external int size;
  @Size()
  external int capacity;
}

/// `rcl_interfaces/msg/ListParametersResult`.
base class ListParametersResultC extends Struct {
  external rosidl_runtime_c__String__Sequence names;
  external rosidl_runtime_c__String__Sequence prefixes;
}

// --- Service request/response structs ---

base class GetParametersRequestC extends Struct {
  external rosidl_runtime_c__String__Sequence names;
}

base class GetParametersResponseC extends Struct {
  external ParameterValueSeq values;
}

base class GetParameterTypesRequestC extends Struct {
  external rosidl_runtime_c__String__Sequence names;
}

base class GetParameterTypesResponseC extends Struct {
  external rosidl_runtime_c__uint8__Sequence types;
}

base class SetParametersRequestC extends Struct {
  external ParameterSeq parameters;
}

base class SetParametersResponseC extends Struct {
  external SetParametersResultSeq results;
}

base class SetParametersAtomicallyRequestC extends Struct {
  external ParameterSeq parameters;
}

base class SetParametersAtomicallyResponseC extends Struct {
  external SetParametersResultC result;
}

base class ListParametersRequestC extends Struct {
  external rosidl_runtime_c__String__Sequence prefixes;
  @Uint64()
  external int depth;
}

base class ListParametersResponseC extends Struct {
  external ListParametersResultC result;
}

// ---------------------------------------------------------------------------
// Sequence init helpers (exposed to the bridge).
// ---------------------------------------------------------------------------
void initStringSeq(Pointer seq, int size) =>
    _stringSeqInit(seq.cast<Void>(), size);
void initUint8Seq(Pointer seq, int size) =>
    _uint8SeqInit(seq.cast<Void>(), size);
void initParameterValueSeq(Pointer seq, int size) =>
    _paramValueSeqInit(seq.cast<Void>(), size);
void initSetResultSeq(Pointer seq, int size) =>
    _setResultSeqInit(seq.cast<Void>(), size);

// ---------------------------------------------------------------------------
// Message wrappers + service type descriptors.
//
// createRequest/createResponse use the generated `__create()` so the message
// (including its empty sequences) is correctly initialized before rcl fills or
// reads it.
// ---------------------------------------------------------------------------

/// Wraps a `<pkg>__srv__<Srv>_(Request|Response)` allocated via its generated
/// `__create` function.
///
/// The `__create` symbol is looked up with a `Pointer<Void>` return (FFI native
/// signatures cannot contain a type variable), then cast to the concrete struct
/// pointer type.
class _GeneratedMessage<T extends Struct> extends BaseRosMessage<T> {
  @override
  final String typeName;
  _GeneratedMessage(this.typeName, String createSymbol) {
    final create = _ifaceGen
        .lookup<NativeFunction<Pointer<Void> Function()>>(createSymbol)
        .asFunction<Pointer<Void> Function()>();
    final ptr = create();
    if (ptr == nullptr) {
      throw StateError('$createSymbol returned null');
    }
    data = ptr.cast<T>();
    // The generated message owns its own storage; leave nativeData null so the
    // inherited dispose() does not try to free a second (unset) pointer.
    nativeData = nullptr;
  }
}

/// All six parameter services live in the `rcl_interfaces` package; concrete
/// subclasses only differ by [typeName] and their request/response structs.
/// [fullTypeName], [typeSupportName] and [rosidlGeneratorDylib] are derived by
/// [BaseRosService].
abstract class _ParamService<Req extends BaseRosMessage,
    Resp extends BaseRosMessage> extends BaseRosService<Req, Resp> {
  @override
  String get packageName => 'rcl_interfaces';
}

class GetParametersService
    extends _ParamService<BaseRosMessage<GetParametersRequestC>,
        BaseRosMessage<GetParametersResponseC>> {
  @override
  String get typeName => 'GetParameters';
  @override
  BaseRosMessage<GetParametersRequestC> createRequest() =>
      _GeneratedMessage<GetParametersRequestC>('GetParameters_Request',
          'rcl_interfaces__srv__GetParameters_Request__create');
  @override
  BaseRosMessage<GetParametersResponseC> createResponse() =>
      _GeneratedMessage<GetParametersResponseC>('GetParameters_Response',
          'rcl_interfaces__srv__GetParameters_Response__create');
}

class SetParametersService
    extends _ParamService<BaseRosMessage<SetParametersRequestC>,
        BaseRosMessage<SetParametersResponseC>> {
  @override
  String get typeName => 'SetParameters';
  @override
  BaseRosMessage<SetParametersRequestC> createRequest() =>
      _GeneratedMessage<SetParametersRequestC>('SetParameters_Request',
          'rcl_interfaces__srv__SetParameters_Request__create');
  @override
  BaseRosMessage<SetParametersResponseC> createResponse() =>
      _GeneratedMessage<SetParametersResponseC>('SetParameters_Response',
          'rcl_interfaces__srv__SetParameters_Response__create');
}

class ListParametersService
    extends _ParamService<BaseRosMessage<ListParametersRequestC>,
        BaseRosMessage<ListParametersResponseC>> {
  @override
  String get typeName => 'ListParameters';
  @override
  BaseRosMessage<ListParametersRequestC> createRequest() =>
      _GeneratedMessage<ListParametersRequestC>('ListParameters_Request',
          'rcl_interfaces__srv__ListParameters_Request__create');
  @override
  BaseRosMessage<ListParametersResponseC> createResponse() =>
      _GeneratedMessage<ListParametersResponseC>('ListParameters_Response',
          'rcl_interfaces__srv__ListParameters_Response__create');
}

class GetParameterTypesService
    extends _ParamService<BaseRosMessage<GetParameterTypesRequestC>,
        BaseRosMessage<GetParameterTypesResponseC>> {
  @override
  String get typeName => 'GetParameterTypes';
  @override
  BaseRosMessage<GetParameterTypesRequestC> createRequest() =>
      _GeneratedMessage<GetParameterTypesRequestC>('GetParameterTypes_Request',
          'rcl_interfaces__srv__GetParameterTypes_Request__create');
  @override
  BaseRosMessage<GetParameterTypesResponseC> createResponse() =>
      _GeneratedMessage<GetParameterTypesResponseC>('GetParameterTypes_Response',
          'rcl_interfaces__srv__GetParameterTypes_Response__create');
}

class SetParametersAtomicallyService
    extends _ParamService<BaseRosMessage<SetParametersAtomicallyRequestC>,
        BaseRosMessage<SetParametersAtomicallyResponseC>> {
  @override
  String get typeName => 'SetParametersAtomically';
  @override
  BaseRosMessage<SetParametersAtomicallyRequestC> createRequest() =>
      _GeneratedMessage<SetParametersAtomicallyRequestC>(
          'SetParametersAtomically_Request',
          'rcl_interfaces__srv__SetParametersAtomically_Request__create');
  @override
  BaseRosMessage<SetParametersAtomicallyResponseC> createResponse() =>
      _GeneratedMessage<SetParametersAtomicallyResponseC>(
          'SetParametersAtomically_Response',
          'rcl_interfaces__srv__SetParametersAtomically_Response__create');
}
