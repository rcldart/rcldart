// src/rcldart.dart
//
// The single rcl entry point: the native bindings handle plus the [RclDart]
// context singleton. (Previously duplicated in lib/rcldart.dart — consolidated
// here so there is one source of truth.)
import 'dart:ffi';

import 'package:rcldart_utils/rcldart_utils.dart';

import 'config.dart';
import 'context.dart';
import 'initOptions.dart';
import 'logger.dart';
import 'node.dart';
import 'gen/rcldart_bindings_generated.dart';

/// Native rcl bindings, loaded from `librcl.so` (bundled or system).
final RcldartBindings rcldartbindings =
    RcldartBindings(dynamiclibraryloader("rcl"));

/// Process-wide rcl context + node factory (singleton, like `rclcpp::init`).
class RclDart {
  static final RclDart _instance = RclDart._internal();

  Context? _defaultContext;

  factory RclDart() => _instance;

  RclDart._internal() {
    initLogger();
  }

  /// Initializes rcl. Pass a [RosConfig] to select the DDS domain, rmw
  /// implementation, discovery peers (IP of the ROS 2 system to talk to), etc.
  /// — applied to the environment before rcl starts (essential for a
  /// bundled / no-ROS app).
  void init([RosConfig? config]) {
    if (_defaultContext != null) return;

    config?.apply();
    rclDartLogger.info("Start initialization of RCL bindings");

    final initOptions = InitOptions();
    _defaultContext = Context();
    final rc = rcldartbindings.rcl_init(0, nullptr,
        initOptions.nativeInitOptions, getDefaultContext().nativeContext);
    if (rc != RCL_RET_OK) {
      throw Exception("unable to init rcl (code $rc)");
    }
    rclDartLogger.info("Successfully initialized RCL bindings");
  }

  /// Tears down the current rcl context and re-initializes with [config].
  /// Use to apply a new DDS configuration at runtime (e.g. the user edited the
  /// peer IPs / domain). The caller MUST drop all nodes/subscriptions created on
  /// the old context first — they become invalid. Best-effort: shutdown/fini
  /// errors are ignored so a bad prior state can't wedge the app.
  void reinitialize([RosConfig? config]) {
    final ctx = _defaultContext;
    if (ctx != null) {
      try {
        rcldartbindings.rcl_shutdown(ctx.nativeContext);
        rcldartbindings.rcl_context_fini(ctx.nativeContext);
      } catch (_) {/* ignore — we're replacing it anyway */}
      _defaultContext = null;
    }
    init(config);
  }

  /// Cleanly tears down the rcl context (rcl_shutdown + rcl_context_fini) and
  /// clears it. Finalize ALL nodes (via `Node.dispose()`) BEFORE calling this,
  /// otherwise rcl logs "Not all nodes were finished before finishing the
  /// context" and DDS can abort during process teardown. Best-effort: errors
  /// are swallowed so shutdown can't wedge the app. No-op if not initialized.
  void shutdown() {
    final ctx = _defaultContext;
    if (ctx == null) return;
    try {
      rcldartbindings.rcl_shutdown(ctx.nativeContext);
      rcldartbindings.rcl_context_fini(ctx.nativeContext);
    } catch (_) {/* ignore — process is going away */}
    _defaultContext = null;
  }

  /// Creates a [Node] on the default context.
  Node createNode(String nodeName, String nameSpace) {
    final node = Node(nodeName, nameSpace, getDefaultContext());
    rclDartLogger.info("created node '$nameSpace/$nodeName'");
    return node;
  }

  Context getDefaultContext() {
    final ctx = _defaultContext;
    if (ctx == null) {
      throw Exception("initialize rcldart before doing something!");
    }
    return ctx;
  }
}
