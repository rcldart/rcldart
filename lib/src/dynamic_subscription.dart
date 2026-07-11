// src/dynamic_subscription.dart
//
// A subscription to ANY topic with NO compiled Dart message class. It creates
// the rcl subscription using the type's rosidl *introspection* typesupport
// (loaded at runtime from the type name on the graph), takes into a raw buffer
// sized/initialised by that typesupport, and decodes each message into a Dart
// map via ros_cdr. This is the runtime-schema path (Foxglove-style generic
// decode) as opposed to the compile-time generated wrappers used elsewhere.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'cdr/cdr.dart';
import 'rcldart.dart';
import 'gen/rcldart_bindings_generated.dart';

class DynamicSubscription {
  final String topic;
  final MessageSchema schema;

  final Pointer<rcl_subscription_t> _sub;
  final Pointer<Uint8> _buf;
  final Pointer<rmw_message_info_t> _info;
  final void Function(Pointer<Void>, int) _init;
  final void Function(Pointer<Void>) _fini;

  DynamicSubscription._(this.topic, this.schema, this._sub, this._buf,
      this._info, this._init, this._fini);

  /// Creates a dynamic subscription on [node] for [topic] carrying [rosType]
  /// (`<pkg>/msg/<Type>`). Throws if the type's introspection library is not on
  /// the library path or the rmw rejects the introspection typesupport.
  factory DynamicSubscription.create(
      Pointer<rcl_node_s> node, String topic, String rosType) {
    final schema = MessageSchema.load(rosType);
    final init = schema.members.ref.initFunction
        .asFunction<void Function(Pointer<Void>, int)>();
    final fini = schema.members.ref.finiFunction
        .asFunction<void Function(Pointer<Void>)>();

    // Buffer for the in-memory C struct; init so owned strings/sequences are
    // valid before the first take. 0 == ROSIDL_RUNTIME_C_MSG_INIT_ALL.
    final buf = calloc<Uint8>(schema.sizeOf);
    init(buf.cast(), 0);

    final sub = malloc<rcl_subscription_t>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_subscription();
    final opts = malloc<rcl_subscription_options_t>()
      ..ref = rcldartbindings.rcl_subscription_get_default_options();

    // Adapt the subscription QoS to the publisher's. The default options are
    // RELIABLE + VOLATILE, which do NOT match BEST_EFFORT publishers (most
    // sensor/streaming topics) or receive latched TRANSIENT_LOCAL data (e.g.
    // /map) — that is why such topics would sit at "waiting". Copy the actual
    // publisher reliability/durability so the reader matches, Foxglove-style.
    _matchPublisherQos(node, topic, opts);

    final rc = rcldartbindings.rcl_subscription_init(
      sub,
      node,
      schema.typeSupport.cast(), // introspection ts is a valid message ts
      topic.toNativeUtf8().cast<Char>(),
      opts,
    );
    if (rc != RCL_RET_OK) {
      throw Exception('dynamic subscription init failed for $topic: $rc');
    }
    final info = malloc<rmw_message_info_t>()
      ..ref = rcldartbindings.rmw_get_zero_initialized_message_info();

    return DynamicSubscription._(topic, schema, sub, buf, info, init, fini);
  }

  /// Sets [opts].qos reliability + durability to match the topic's publisher(s),
  /// so a BEST_EFFORT / TRANSIENT_LOCAL publisher is actually received. No-op if
  /// the topic has no publisher yet (keeps the default reliable/volatile QoS).
  static void _matchPublisherQos(Pointer<rcl_node_s> node, String topic,
      Pointer<rcl_subscription_options_t> opts) {
    final allocator = malloc<rcl_allocator_t>()
      ..ref = rcldartbindings.rcutils_get_default_allocator();
    final arr = malloc<rcl_topic_endpoint_info_array_t>()
      ..ref = rcldartbindings.rmw_get_zero_initialized_topic_endpoint_info_array();
    final topicC = topic.toNativeUtf8();
    try {
      final rc = rcldartbindings.rcl_get_publishers_info_by_topic(
          node.cast(), allocator, topicC.cast<Char>(), false, arr.cast());
      if (rc == RCL_RET_OK && arr.ref.size > 0) {
        final pub = arr.ref.info_array.ref.qos_profile; // first publisher
        opts.ref.qos.reliability = pub.reliability;
        opts.ref.qos.durability = pub.durability;
      }
    } catch (_) {
      // leave default QoS
    } finally {
      rcldartbindings.rmw_topic_endpoint_info_array_fini(arr.cast(), allocator);
      malloc.free(topicC);
      malloc.free(arr);
      malloc.free(allocator);
    }
  }

  /// Takes one pending message, or null if none is ready. Decodes into a map,
  /// then resets the buffer (fini+init) so the next take starts clean.
  Map<String, Object?>? take() {
    if (!takeRaw()) return null;
    final map = decodeCurrent();
    reset();
    return map;
  }

  /// Lower-level: takes one pending message into the buffer WITHOUT decoding or
  /// resetting. Returns true if a message was taken. Pair with [decodeCurrent]
  /// and [reset]. (Used to decode a buffer more than once, e.g. benchmarks.)
  bool takeRaw() =>
      rcldartbindings.rcl_take(_sub, _buf.cast(), _info, nullptr) == RCL_RET_OK;

  /// Decodes whatever is currently in the buffer (does not take or reset).
  Map<String, Object?> decodeCurrent() => decodeMessage(_buf, schema.members);

  /// Frees owned strings/sequences and re-initialises the buffer for the next
  /// take.
  void reset() {
    _fini(_buf.cast());
    _init(_buf.cast(), 0);
  }
}
