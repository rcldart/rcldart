// src/topic_hub.dart
//
// A Foxglove-style central message pipeline for rcldart.
//
// Foxglove never talks to the data source from a panel directly: panels push
// "I want topic X" up to a single MessagePipeline that (1) DE-DUPLICATES — one
// underlying subscription per topic no matter how many panels want it — and
// (2) ROUTES each incoming message to every listener that asked for that topic,
// via an inverted index. This class is that pipeline for rcldart.
//
// Difference from Foxglove: Foxglove decodes any topic generically from a
// runtime schema. rcldart uses compile-time generated message classes, so the
// hub needs a [MessageTypeRegistry] mapping a ROS type name (e.g.
// `sensor_msgs/msg/LaserScan`) to a factory for its generated wrapper. Register
// the message types your app knows; the hub then binds any *live* topic of a
// registered type to a panel at runtime.
import 'package:rcldart_utils/rcldart_utils.dart';

import 'node.dart';
import 'subscriber.dart';

typedef MessageFactory = BaseRosMessage Function();
typedef MessageListener = void Function(BaseRosMessage message);

/// Maps a ROS 2 type name (`<pkg>/msg/<Type>`) to a factory for its generated
/// wrapper.
class MessageTypeRegistry {
  final Map<String, MessageFactory> _byType = {};

  /// Registers a type by an explicit ROS name.
  void register(String rosType, MessageFactory factory) =>
      _byType[rosType] = factory;

  /// Registers using a sample instance — the ROS name is derived from the
  /// message's own packageName/typeName (`<pkg>/msg/<Type>`).
  void registerMessage(BaseRosMessage sample, MessageFactory factory) =>
      _byType[rosTypeOf(sample)] = factory;

  MessageFactory? factoryFor(String rosType) => _byType[rosType];

  bool supports(String rosType) => _byType.containsKey(rosType);

  Iterable<String> get types => _byType.keys;

  static String rosTypeOf(BaseRosMessage m) =>
      '${m.packageName}/msg/${m.typeName}';
}

/// Central subscription hub: de-duplicates subscriptions per topic and routes
/// messages to the panels/listeners that requested them.
class TopicHub {
  final Node node;
  final MessageTypeRegistry registry;

  final Map<String, Subscriber> _subs = {}; // one per topic (de-dup)
  final Map<String, List<MessageListener>> _listeners = {}; // inverted index
  Map<String, List<String>> _graph = {}; // topic -> types (advertise)

  TopicHub(this.node, this.registry);

  /// Refreshes the topic list from the ROS graph (the "advertise" step).
  Map<String, List<String>> refreshGraph() =>
      _graph = node.getTopicNamesAndTypes();

  Map<String, List<String>> get graph => _graph;

  /// Topics whose type is registered (i.e. can be bound to a panel now).
  Iterable<String> get bindableTopics => _graph.entries
      .where((e) => e.value.any(registry.supports))
      .map((e) => e.key);

  String? typeOf(String topic) => _graph[topic]?.firstOrNull;

  /// Binds [listener] to [topic]. Creates at most ONE rcl subscription per
  /// topic (shared by all listeners). Returns false if the topic's type is not
  /// registered. Refreshes the graph on demand if the topic is unknown.
  bool subscribe(String topic, MessageListener listener) {
    if (!_graph.containsKey(topic)) refreshGraph();
    if (_subs.containsKey(topic)) {
      _listeners[topic]!.add(listener);
      return true;
    }
    final type = _graph[topic]?.firstWhere(registry.supports, orElse: () => '');
    final factory = (type == null || type.isEmpty)
        ? null
        : registry.factoryFor(type);
    if (factory == null) return false; // unknown/unregistered type
    _listeners[topic] = [listener];
    _subs[topic] = node.createSubscriber(
      topic_name: topic,
      messageType: factory(),
      callback: (m) {
        for (final l in List<MessageListener>.of(_listeners[topic] ?? const [])) {
          l(m);
        }
      },
    );
    return true;
  }

  /// Removes one listener; the underlying subscription is kept (rcl fini is not
  /// wired yet) but stops routing once no listeners remain.
  void unsubscribe(String topic, MessageListener listener) {
    _listeners[topic]?.remove(listener);
  }

  /// Drives the hub's subscriptions (call from a spin loop / Timer).
  void spinOnce() {
    for (final s in _subs.values) {
      s.take();
    }
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
