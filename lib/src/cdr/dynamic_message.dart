// ros_cdr/src/dynamic_message.dart
//
// Walks an in-memory ROS 2 message (the C struct that rcl_take fills) using an
// introspection [MessageSchema] and produces a plain Dart map. Nested messages
// become nested maps; fixed arrays and sequences become Lists (typed lists for
// primitives). No generated Dart class is involved — this decodes ANY type
// whose introspection library is on the path.
//
// PERFORMANCE: primitive arrays/sequences are read in BULK via `asTypedList`
// (a single native→Dart memcpy), NOT element-by-element. A per-element loop
// would pay one FFI call to `get_const_function` plus one boxed allocation for
// EVERY value — ruinous for LaserScan (1000s of floats) or PointCloud2
// (megabytes). Bulk typed reads turn that into one copy with no boxing.
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'introspection.dart';

/// Default cap on how many elements of a single array/sequence are copied out.
/// Big enough for full-HD images (1920×1080×4 = 8,294,400) and dense laser
/// scans; guards only against pathological multi-megabyte payloads. Raise it if
/// you need every element of even larger arrays (e.g. 4K images, big clouds).
const int kDefaultMaxArrayElements = 1 << 24; // 16,777,216

/// Decodes the message at [base] (pointer to the C struct) described by
/// [members] into a `Map<String, Object?>`. Arrays longer than
/// [maxArrayElements] are truncated (their reported length in [numericLeaves]
/// reflects the copied length).
Map<String, Object?> decodeMessage(
  Pointer<Uint8> base,
  Pointer<RosMembers> members, {
  int maxArrayElements = kDefaultMaxArrayElements,
}) {
  final out = <String, Object?>{};
  final count = members.ref.memberCount;
  final arr = members.ref.members;
  for (var i = 0; i < count; i++) {
    final m = (arr + i).ref;
    final name = m.name.toDartString();
    final fieldPtr = Pointer<Void>.fromAddress(base.address + m.offset);
    out[name] = m.isArray
        ? _readArray(m, fieldPtr, maxArrayElements)
        : _readScalar(m.typeId, fieldPtr, m.members, maxArrayElements);
  }
  return out;
}

Object? _readArray(RosMember m, Pointer<Void> fieldPtr, int maxArray) {
  final sizeFn = m.sizeFunction;
  final n = sizeFn != nullptr
      ? sizeFn.asFunction<int Function(Pointer<Void>)>()(fieldPtr)
      : m.arraySize;
  if (n <= 0 || n > 1 << 27) return const [];
  final getFn = m.getConstFunction;
  if (getFn == nullptr) return const [];
  final get = getFn.asFunction<Pointer<Void> Function(Pointer<Void>, int)>();
  final elem0 = get(fieldPtr, 0); // base of the contiguous element storage
  final copyN = n > maxArray ? maxArray : n;

  // Bulk path: primitive elements are contiguous — one memcpy, no boxing.
  switch (m.typeId) {
    case RosType.float:
      return Float32List.fromList(elem0.cast<Float>().asTypedList(copyN));
    case RosType.double_:
    case RosType.longDouble:
      return Float64List.fromList(elem0.cast<Double>().asTypedList(copyN));
    case RosType.uint8:
    case RosType.octet:
      return Uint8List.fromList(elem0.cast<Uint8>().asTypedList(copyN));
    case RosType.int8:
    case RosType.char:
      return Int8List.fromList(elem0.cast<Int8>().asTypedList(copyN));
    case RosType.uint16:
    case RosType.wchar:
      return Uint16List.fromList(elem0.cast<Uint16>().asTypedList(copyN));
    case RosType.int16:
      return Int16List.fromList(elem0.cast<Int16>().asTypedList(copyN));
    case RosType.uint32:
      return Uint32List.fromList(elem0.cast<Uint32>().asTypedList(copyN));
    case RosType.int32:
      return Int32List.fromList(elem0.cast<Int32>().asTypedList(copyN));
    case RosType.uint64:
      return Uint64List.fromList(elem0.cast<Uint64>().asTypedList(copyN));
    case RosType.int64:
      return Int64List.fromList(elem0.cast<Int64>().asTypedList(copyN));
    case RosType.boolean:
      final v = elem0.cast<Uint8>().asTypedList(copyN);
      return List<bool>.generate(copyN, (i) => v[i] != 0, growable: false);
    case RosType.string:
    case RosType.message:
      // Non-primitive elements: index each via the accessor and read/recurse.
      // These arrays (strings, sub-messages) are small in practice.
      return List<Object?>.generate(copyN,
          (i) => _readScalar(m.typeId, get(fieldPtr, i), m.members, maxArray),
          growable: false);
    default:
      return const [];
  }
}

Object? _readScalar(
    int typeId, Pointer<Void> p, Pointer<RosMessageTypeSupport> nested, int maxArray) {
  switch (typeId) {
    case RosType.float:
      return p.cast<Float>().value;
    case RosType.double_:
    case RosType.longDouble:
      return p.cast<Double>().value;
    case RosType.char:
    case RosType.int8:
      return p.cast<Int8>().value;
    case RosType.wchar:
    case RosType.uint16:
      return p.cast<Uint16>().value;
    case RosType.boolean:
      return p.cast<Uint8>().value != 0;
    case RosType.octet:
    case RosType.uint8:
      return p.cast<Uint8>().value;
    case RosType.int16:
      return p.cast<Int16>().value;
    case RosType.uint32:
      return p.cast<Uint32>().value;
    case RosType.int32:
      return p.cast<Int32>().value;
    case RosType.uint64:
      return p.cast<Uint64>().value;
    case RosType.int64:
      return p.cast<Int64>().value;
    case RosType.string:
      final s = p.cast<RosString>().ref;
      if (s.data == nullptr || s.size == 0) return '';
      return s.data.cast<Utf8>().toDartString(length: s.size);
    case RosType.wstring:
      return '';
    case RosType.message:
      return decodeMessage(p.cast<Uint8>(), nested.ref.data.cast<RosMembers>(),
          maxArrayElements: maxArray);
    default:
      return null;
  }
}

/// Flattens a decoded map to dotted numeric leaves — handy for plotting an
/// arbitrary field of any topic (e.g. `pose.pose.position.x`). Arrays are
/// summarised by length under `<name>.length`.
Map<String, num> numericLeaves(Map<String, Object?> msg, [String prefix = '']) {
  final out = <String, num>{};
  msg.forEach((k, v) {
    final key = prefix.isEmpty ? k : '$prefix.$k';
    if (v is num) {
      out[key] = v;
    } else if (v is bool) {
      out[key] = v ? 1 : 0;
    } else if (v is Map<String, Object?>) {
      out.addAll(numericLeaves(v, key));
    } else if (v is List) {
      out['$key.length'] = v.length;
    }
  });
  return out;
}
