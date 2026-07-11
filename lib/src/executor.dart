// src/executor.dart
//
// A wait_set based executor — the proper rcl idiom that replaces the ad-hoc
// per-entity `Timer.periodic(... take())` polling used in the example.
//
// Instead of blindly calling `take()`/`spinOnce()` on every entity each tick,
// the executor asks rcl (via `rcl_wait`) which subscriptions/services/clients
// actually have work pending, and dispatches only those.
//
// Blocking model: `rcl_wait` blocks the calling thread up to its timeout. To
// avoid freezing the Dart isolate / Flutter UI we drive it *non-blocking*
// (timeout 0) from a `Timer.periodic` on the event loop via [spin]. For a
// dedicated background isolate you can call [spinOnce] with a real timeout.
import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'client.dart';
import 'context.dart';
import 'node.dart';
import 'rcldart.dart';
import 'service.dart';
import 'subscriber.dart';
import 'gen/rcldart_bindings_generated.dart';

/// Waits on the entities of the nodes (and any directly-added entities) added
/// to it and dispatches the ready ones — the rclcpp `Executor` model:
///
/// ```dart
/// final executor = Executor()..addNode(node);
/// executor.spin(); // non-blocking on the UI isolate
/// ```
class Executor {
  final Context context;

  final List<Node> _nodes = [];
  final List<Subscriber> _subscriptions = [];
  final List<Service> _services = [];
  final List<Client> _clients = [];

  Timer? _spinTimer;

  /// Uses the default context when none is provided.
  Executor([Context? context])
      : context = context ?? RclDart().getDefaultContext();

  /// Adds a node; the executor then spins ALL of the node's entities
  /// (subscriptions, services, clients) — like `rclcpp::Executor::add_node`.
  void addNode(Node node) {
    if (!_nodes.contains(node)) _nodes.add(node);
  }

  void removeNode(Node node) => _nodes.remove(node);

  // --- fine-grained registration (optional; addNode covers the common case) ---
  void addSubscription(Subscriber subscriber) =>
      _subscriptions.add(subscriber);
  void addService(Service service) => _services.add(service);
  void addClient(Client client) => _clients.add(client);

  // All entities to spin = directly-added + those owned by added nodes.
  List<Subscriber> get _allSubs =>
      [..._subscriptions, for (final n in _nodes) ...n.subscriptions];
  List<Service> get _allServices =>
      [..._services, for (final n in _nodes) ...n.services];
  List<Client> get _allClients =>
      [..._clients, for (final n in _nodes) ...n.clients];

  bool get isEmpty =>
      _allSubs.isEmpty && _allServices.isEmpty && _allClients.isEmpty;

  /// Waits up to [timeout] for any registered entity to become ready, then
  /// dispatches every ready one. Returns `true` if at least one entity was
  /// serviced.
  ///
  /// [timeout] `Duration.zero` → non-blocking (check-and-return); a negative
  /// duration → block indefinitely; positive → block up to that long.
  bool spinOnce({Duration timeout = Duration.zero}) {
    // Snapshot the current entity set once (nodes/entities may change between
    // spins); indices must stay stable across add + dispatch below.
    final subs = _allSubs;
    final clients = _allClients;
    final services = _allServices;
    if (subs.isEmpty && clients.isEmpty && services.isEmpty) return false;

    final waitSet = malloc<rcl_wait_set_t>()
      ..ref = rcldartbindings.rcl_get_zero_initialized_wait_set();

    try {
      final rcInit = rcldartbindings.rcl_wait_set_init(
        waitSet,
        subs.length, // subscriptions
        0, // guard conditions
        0, // timers
        clients.length, // clients
        services.length, // services
        0, // events
        context.nativeContext,
        rcldartbindings.rcutils_get_default_allocator(),
      );
      if (rcInit != RCL_RET_OK) {
        throw Exception('rcl_wait_set_init failed with code: $rcInit');
      }

      // Register every entity; rcl fills the ready arrays in add order.
      for (final s in subs) {
        rcldartbindings.rcl_wait_set_add_subscription(
            waitSet, s.nativeSubscriber, nullptr);
      }
      for (final c in clients) {
        rcldartbindings.rcl_wait_set_add_client(
            waitSet, c.nativeClient, nullptr);
      }
      for (final s in services) {
        rcldartbindings.rcl_wait_set_add_service(
            waitSet, s.nativeService, nullptr);
      }

      final rc = rcldartbindings.rcl_wait(waitSet, _toNanos(timeout));
      if (rc == RCL_RET_TIMEOUT) {
        return false; // nothing ready within the timeout
      }
      if (rc != RCL_RET_OK) {
        throw Exception('rcl_wait failed with code: $rc');
      }

      return _dispatchReady(waitSet, subs, clients, services);
    } finally {
      rcldartbindings.rcl_wait_set_fini(waitSet);
      malloc.free(waitSet);
    }
  }

  /// Dispatches the entities that `rcl_wait` marked ready. A slot is ready
  /// when its pointer in the wait_set array is non-null (rcl nulls out the
  /// entities that are not ready, keeping the add-order indices).
  bool _dispatchReady(Pointer<rcl_wait_set_t> waitSet, List<Subscriber> subs,
      List<Client> clients, List<Service> services) {
    var serviced = false;
    final ws = waitSet.ref;

    final subsArr = ws.subscriptions;
    for (var i = 0; i < subs.length; i++) {
      if (subsArr[i] != nullptr) {
        subs[i].take(); // invokes the subscriber callback
        serviced = true;
      }
    }

    final clientsArr = ws.clients;
    for (var i = 0; i < clients.length; i++) {
      if (clientsArr[i] != nullptr) {
        clients[i].processReady();
        serviced = true;
      }
    }

    final servicesArr = ws.services;
    for (var i = 0; i < services.length; i++) {
      if (servicesArr[i] != nullptr) {
        services[i].spinOnce();
        serviced = true;
      }
    }

    return serviced;
  }

  /// Continuously services entities by polling [spinOnce] non-blocking on the
  /// event loop. Safe to call on the main/UI isolate. Call [stop] to end.
  void spin({Duration period = const Duration(milliseconds: 10)}) {
    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(period, (_) {
      try {
        // Drain everything that is ready this tick.
        while (spinOnce(timeout: Duration.zero)) {}
      } catch (e) {
        print('Executor spin error: $e');
      }
    });
  }

  void stop() {
    _spinTimer?.cancel();
    _spinTimer = null;
  }

  void dispose() {
    stop();
    _nodes.clear();
    _subscriptions.clear();
    _services.clear();
    _clients.clear();
  }

  /// rcl timeouts are int64 nanoseconds. `Duration.zero` maps to 0
  /// (non-blocking); a negative duration blocks indefinitely.
  int _toNanos(Duration d) => d.inMicroseconds * 1000;
}
