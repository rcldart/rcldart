// src/node.dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:rcldart/src/publisher.dart';
import 'package:rcldart/src/rcldart.dart';
import 'package:rcldart/src/subscriber.dart';
import 'package:rcldart/src/service.dart';
import 'package:rcldart/src/client.dart';
import 'package:rcldart/src/service_type.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

import './context.dart';
import 'dynamic_subscription.dart';
import 'gen/rcldart_bindings_generated.dart';
import 'node_options.dart';

class Node {
  late final Pointer<rcl_node_s> nativeNode;
  final String nodeName;
  final String nameSpace;
  final NodeOptions nodeOptions;

  // Entities owned by this node. An [Executor] collects these via addNode(),
  // mirroring rclcpp where the executor spins a node's entities.
  final List<Subscriber> subscriptions = [];
  final List<Service> services = [];
  final List<Client> clients = [];

  Node._(this.nativeNode, this.nodeName, this.nameSpace, Context context,
      this.nodeOptions);

  factory Node(String nodeName, String nameSpace, Context context) {
    var nodeOptions = NodeOptions();
    return Node.withOptions(nodeName, nameSpace, context, nodeOptions);
  }

  factory Node.withOptions(String nodeName, String nameSpace, Context context,
      NodeOptions nodeOptions) {
    var nativeNode = malloc<rcl_node_s>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_node();

    var rc = rcldartbindings.rcl_node_init(
        nativeNode,
        nodeName.toNativeUtf8().cast<Char>(),
        nameSpace.toNativeUtf8().cast<Char>(),
        context.nativeContext,
        nodeOptions.nativeNodeOptions);
    if (rc != RCL_RET_OK) {
      throw Exception("unable to init node");
    }
    return Node._(nativeNode, nodeName, nameSpace, context, nodeOptions);
  }

  Subscriber createSubscriber<T extends BaseRosMessage>({
    required String topic_name,
    required T messageType, // the message type provides its own type support
    void Function(T)? callback,
  }) {
    var subscription = malloc<rcl_subscription_t>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_subscription();

    // Subscription options
    var options = malloc<rcl_subscription_options_t>()
      ..ref = rcldartbindings.rcl_subscription_get_default_options();

    // Type support comes from the message type itself (its generated
    // <pkg>__rosidl_typesupport_c library + handle symbol) — no hard-coded
    // std_msgs default.
    final ttt = messageType.rosidlGeneratorDylib
        .lookup<NativeFunction<_typesupportMsgFunc>>(messageType.typeSupportName)
        .asFunction<_typesupportMsgFunc>();

    // Subscription initialization
    var rc = rcldartbindings.rcl_subscription_init(subscription, nativeNode,
        ttt(), topic_name.toNativeUtf8().cast<Char>(), options);

    if (rc != RCL_RET_OK) {
      throw Exception("unable to create subscriber, error code: $rc");
    }

    print("Subscription created successfully for topic: $topic_name");

    final sub = Subscriber<T>(subscription, nativeNode,
        callback: callback, messageType: messageType);
    subscriptions.add(sub);
    return sub;
  }

  Publisher createPublisher<T extends BaseRosMessage>({
    required String topic_name,
    required T messageType, // the message type provides its own type support
  }) {
    var publisher = malloc<rcl_publisher_s>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_publisher();

    var options = malloc<rcl_publisher_options_s>()
      ..ref = rcldartbindings.rcl_publisher_get_default_options();

    final ttt = messageType.rosidlGeneratorDylib
        .lookup<NativeFunction<_typesupportMsgFunc>>(messageType.typeSupportName)
        .asFunction<_typesupportMsgFunc>();

    var rc = rcldartbindings.rcl_publisher_init(publisher, nativeNode, ttt(),
        topic_name.toNativeUtf8().cast<Char>(), options);
    if (rc != RCL_RET_OK) {
      throw Exception("unable to create publisher");
    }

    return Publisher<T>(publisher);
  }

  /// Creates a service *server* for [serviceName].
  ///
  /// [serviceType] binds the concrete ROS service type (Request/Response +
  /// type-support symbol) and [handler] maps each incoming request to a
  /// response. Drive [Service.spinOnce]/[Service.spin] on a timer to serve
  /// requests (see the subscriber polling pattern in the example).
  Service<Req, Resp>
      createService<Req extends BaseRosMessage, Resp extends BaseRosMessage>({
    required String serviceName,
    required BaseRosService<Req, Resp> serviceType,
    required Resp Function(Req request) handler,
  }) {
    var service = malloc<rcl_service_t>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_service();

    var options = malloc<rcl_service_options_t>()
      ..ref = rcldartbindings.rcl_service_get_default_options();

    var rc = rcldartbindings.rcl_service_init(
        service,
        nativeNode,
        serviceType.typeSupportHandle,
        serviceName.toNativeUtf8().cast<Char>(),
        options);
    if (rc != RCL_RET_OK) {
      throw Exception("unable to create service, error code: $rc");
    }

    print("Service created successfully for service: $serviceName");
    final srv = Service<Req, Resp>(service, serviceType, serviceName, handler);
    services.add(srv);
    return srv;
  }

  /// Creates a service *client* for [serviceName].
  ///
  /// Use [Client.call] to send a request and await the response, or the
  /// lower-level [Client.sendRequest]/[Client.takeResponse] pair.
  Client<Req, Resp>
      createClient<Req extends BaseRosMessage, Resp extends BaseRosMessage>({
    required String serviceName,
    required BaseRosService<Req, Resp> serviceType,
    void Function(Resp response)? onResponse,
  }) {
    var client = malloc<rcl_client_t>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_client();

    var options = malloc<rcl_client_options_t>()
      ..ref = rcldartbindings.rcl_client_get_default_options();

    var rc = rcldartbindings.rcl_client_init(
        client,
        nativeNode,
        serviceType.typeSupportHandle,
        serviceName.toNativeUtf8().cast<Char>(),
        options);
    if (rc != RCL_RET_OK) {
      throw Exception("unable to create client, error code: $rc");
    }

    print("Client created successfully for service: $serviceName");
    final cli = Client<Req, Resp>(client, serviceType, serviceName,
        onResponse: onResponse);
    clients.add(cli);
    return cli;
  }

  /// Creates a [DynamicSubscription] for [topic] carrying [rosType]
  /// (`<pkg>/msg/<Type>`) with NO compiled Dart message class — the layout is
  /// read at runtime from the type's rosidl introspection typesupport. Powers
  /// "decode any topic" UIs. The type's `*__rosidl_typesupport_introspection_c`
  /// library must be on the library path.
  DynamicSubscription createDynamicSubscription(String topic, String rosType) {
    final sub = DynamicSubscription.create(nativeNode, topic, rosType);
    return sub;
  }

  /// Discovers the topics currently on the ROS 2 graph and their type(s) —
  /// like `ros2 topic list -t`. Powers Foxglove-style "pick a topic" UIs where
  /// a panel is bound to any live topic at runtime.
  Map<String, List<String>> getTopicNamesAndTypes() {
    final allocator = malloc<rcl_allocator_t>()
      ..ref = rcldartbindings.rcutils_get_default_allocator();
    final nat = malloc<rcl_names_and_types_t>()
      ..ref = rcldartbindings.rmw_get_zero_initialized_names_and_types();
    try {
      final rc = rcldartbindings.rcl_get_topic_names_and_types(
          nativeNode, allocator, false, nat);
      if (rc != RCL_RET_OK) {
        throw Exception('rcl_get_topic_names_and_types failed: $rc');
      }
      final result = <String, List<String>>{};
      final names = nat.ref.names;
      for (var i = 0; i < names.size; i++) {
        final topic = names.data[i].cast<Utf8>().toDartString();
        final ta = nat.ref.types[i];
        result[topic] = [
          for (var j = 0; j < ta.size; j++)
            ta.data[j].cast<Utf8>().toDartString(),
        ];
      }
      return result;
    } finally {
      rcldartbindings.rcl_names_and_types_fini(nat);
      malloc.free(nat);
      malloc.free(allocator);
    }
  }

  /// Finalizes this node (rcl_node_fini) and frees its native handle. Call this
  /// before `RclDart().shutdown()` / `reinitialize()` — the rcl context cannot
  /// be finalized cleanly while a node is still alive (rcl otherwise logs
  /// "Not all nodes were finished before finishing the context" and DDS may
  /// abort at teardown). Best-effort and idempotent-ish: safe to ignore errors
  /// during app shutdown. `rcl_node_fini` takes ONLY the node (single arg).
  void dispose() {
    final rc = rcldartbindings.rcl_node_fini(nativeNode);
    malloc.free(nativeNode);
    if (rc != RCL_RET_OK) {
      print('rcl_node_fini returned $rc');
    }
  }
}

typedef _typesupportMsgFunc = Pointer<rosidl_message_type_support_t> Function();
