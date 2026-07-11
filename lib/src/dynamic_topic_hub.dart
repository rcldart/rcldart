// src/dynamic_topic_hub.dart
//
// Like [TopicHub], but for the runtime-schema world: it can bind to ANY topic
// on the graph — no MessageTypeRegistry, no compiled Dart class — because it
// decodes each message generically via the rosidl introspection typesupport
// (see DynamicSubscription / ros_cdr). Panels receive a plain
// `Map<String, Object?>`.
//
// This is the closest rcldart gets to Foxglove's "subscribe to anything" model.
import 'dynamic_subscription.dart';
import 'node.dart';

typedef DynamicListener = void Function(Map<String, Object?> message);

class DynamicTopicHub {
  final Node node;

  final Map<String, DynamicSubscription> _subs = {}; // one per topic (de-dup)
  final Map<String, List<DynamicListener>> _listeners = {}; // inverted index
  final Map<String, Map<String, Object?>> _latest = {}; // last value per topic
  Map<String, List<String>> _graph = {};
  final Set<String> _undecodable = {}; // types with no introspection lib

  DynamicTopicHub(this.node);

  Map<String, List<String>> refreshGraph() =>
      _graph = node.getTopicNamesAndTypes();

  Map<String, List<String>> get graph => _graph;

  /// EVERY topic on the graph — all are decodable in principle (subject to the
  /// type's introspection library being present).
  Iterable<String> get topics =>
      _graph.keys.where((t) => !_undecodable.contains(_graph[t]?.firstOrNull));

  String? typeOf(String topic) => _graph[topic]?.firstOrNull;

  /// Last decoded message for [topic], if any.
  Map<String, Object?>? latest(String topic) => _latest[topic];

  /// Binds [listener] to [topic], creating at most one dynamic subscription per
  /// topic. Returns false if the type is unknown/undecodable (e.g. its
  /// introspection library is not bundled).
  bool subscribe(String topic, DynamicListener listener) {
    if (!_graph.containsKey(topic)) refreshGraph();
    if (_subs.containsKey(topic)) {
      _listeners[topic]!.add(listener);
      return true;
    }
    final type = typeOf(topic);
    if (type == null || _undecodable.contains(type)) return false;
    try {
      _subs[topic] = node.createDynamicSubscription(topic, type);
      _listeners[topic] = [listener];
      return true;
    } catch (_) {
      _undecodable.add(type); // missing introspection lib — don't retry
      return false;
    }
  }

  void unsubscribe(String topic, DynamicListener listener) {
    _listeners[topic]?.remove(listener);
  }

  /// Drains all subscriptions (call from a spin loop / Timer).
  void spinOnce() {
    for (final entry in _subs.entries) {
      Map<String, Object?>? m;
      while ((m = entry.value.take()) != null) {
        _latest[entry.key] = m!;
        for (final l in List<DynamicListener>.of(_listeners[entry.key] ?? const [])) {
          l(m);
        }
      }
    }
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
