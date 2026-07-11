// ros_cdr/src/introspection.dart
//
// FFI mirror of the rosidl **introspection** typesupport ABI (ROS 2 Jazzy).
// The introspection typesupport describes a message's fields (name, type, byte
// offset, array-ness) at runtime — this is what lets us decode ANY topic
// without a compiled Dart class for it. Struct layouts here match
// rosidl_typesupport_introspection_c/message_introspection.h EXACTLY, including
// the Jazzy-era `is_key_` / `has_any_key_member_` fields (get the order wrong
// and every offset shifts).
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

/// rosidl introspection field type ids (field_types.h).
class RosType {
  static const int float = 1;
  static const int double_ = 2;
  static const int longDouble = 3;
  static const int char = 4;
  static const int wchar = 5;
  static const int boolean = 6;
  static const int octet = 7;
  static const int uint8 = 8;
  static const int int8 = 9;
  static const int uint16 = 10;
  static const int int16 = 11;
  static const int uint32 = 12;
  static const int int32 = 13;
  static const int uint64 = 14;
  static const int int64 = 15;
  static const int string = 16;
  static const int wstring = 17;
  static const int message = 18;
}

/// rosidl_message_type_support_t — we only need `.data` (→ MessageMembers).
final class RosMessageTypeSupport extends Struct {
  external Pointer<Utf8> typesupportIdentifier;
  external Pointer<Void> data;
  // remaining fields (func, type_hash, ...) unused here
}

/// rosidl_typesupport_introspection_c__MessageMember (Jazzy layout).
final class RosMember extends Struct {
  external Pointer<Utf8> name;
  @Uint8()
  external int typeId;
  @IntPtr()
  external int stringUpperBound; // size_t
  external Pointer<RosMessageTypeSupport> members; // nested msg typesupport
  @Bool()
  external bool isKey;
  @Bool()
  external bool isArray;
  @IntPtr()
  external int arraySize; // size_t
  @Bool()
  external bool isUpperBound;
  @Uint32()
  external int offset;
  external Pointer<Void> defaultValue;
  external Pointer<NativeFunction<IntPtr Function(Pointer<Void>)>> sizeFunction;
  external Pointer<NativeFunction<Pointer<Void> Function(Pointer<Void>, IntPtr)>>
      getConstFunction;
  external Pointer<NativeFunction<Pointer<Void> Function(Pointer<Void>, IntPtr)>>
      getFunction;
  external Pointer<NativeFunction<Void Function(Pointer<Void>, IntPtr, Pointer<Void>)>>
      fetchFunction;
  external Pointer<NativeFunction<Void Function(Pointer<Void>, IntPtr, Pointer<Void>)>>
      assignFunction;
  external Pointer<NativeFunction<Bool Function(Pointer<Void>, IntPtr)>>
      resizeFunction;
}

/// rosidl_typesupport_introspection_c__MessageMembers (Jazzy layout).
final class RosMembers extends Struct {
  external Pointer<Utf8> messageNamespace;
  external Pointer<Utf8> messageName;
  @Uint32()
  external int memberCount;
  @IntPtr()
  external int sizeOf; // size_t — bytes of the in-memory struct
  @Bool()
  external bool hasAnyKeyMember;
  external Pointer<RosMember> members; // array [memberCount]
  external Pointer<NativeFunction<Void Function(Pointer<Void>, Int32)>> initFunction;
  external Pointer<NativeFunction<Void Function(Pointer<Void>)>> finiFunction;
}

/// rosidl_runtime_c__String (and __U16String share the {ptr,size,cap} shape).
final class RosString extends Struct {
  external Pointer<Utf8> data;
  @IntPtr()
  external int size;
  @IntPtr()
  external int capacity;
}

typedef _GetHandle = Pointer<RosMessageTypeSupport> Function();
typedef _GetHandleC = Pointer<RosMessageTypeSupport> Function();

/// A loaded introspection schema for one ROS 2 message type.
class MessageSchema {
  /// `<pkg>/msg/<Type>`.
  final String rosType;

  /// The introspection type_support handle — also valid to create an rmw
  /// subscription with (rmw_cyclonedds/fastrtps accept introspection ts).
  final Pointer<RosMessageTypeSupport> typeSupport;

  /// The top-level members descriptor.
  final Pointer<RosMembers> members;

  MessageSchema._(this.rosType, this.typeSupport, this.members);

  int get sizeOf => members.ref.sizeOf;

  /// Loads the introspection schema for [rosType] (e.g. `sensor_msgs/msg/Image`)
  /// by dlopen-ing `<pkg>__rosidl_typesupport_introspection_c` and calling its
  /// generated `get_message_type_support_handle` symbol. Throws if the type's
  /// introspection library/symbol is not available on the library path.
  factory MessageSchema.load(String rosType) {
    final parts = rosType.split('/'); // pkg / (msg) / Type
    if (parts.length < 2) {
      throw ArgumentError('bad ROS type "$rosType" (want <pkg>/msg/<Type>)');
    }
    final pkg = parts.first;
    final type = parts.last;
    final lib = dynamiclibraryloader('${pkg}__rosidl_typesupport_introspection_c');
    final sym = 'rosidl_typesupport_introspection_c__'
        'get_message_type_support_handle__${pkg}__msg__$type';
    final getHandle = lib
        .lookup<NativeFunction<_GetHandleC>>(sym)
        .asFunction<_GetHandle>();
    final ts = getHandle();
    final members = ts.ref.data.cast<RosMembers>();
    return MessageSchema._(rosType, ts, members);
  }
}
