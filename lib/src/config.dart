// src/config.dart
//
// Runtime ROS 2 / DDS configuration for a self-contained rcldart app (one that
// bundles the ROS libraries and is NOT started from a sourced ROS environment).
//
// rcl/rmw read their configuration from environment variables at init time, so
// these must be set BEFORE `RclDart().init()`. Since a bundled app has no shell
// to `export` them, [RosConfig.apply] sets them in-process via libc `setenv`.
//
//   RosConfig(
//     domainId: 5,                       // which DDS domain
//     staticPeers: ['192.168.1.42'],     // discover this remote ROS 2 host
//     rmwImplementation: 'rmw_cyclonedds_cpp',
//   ).apply();
//   RclDart().init();
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// How far automatic discovery reaches (ROS 2 Jazzy: ROS_AUTOMATIC_DISCOVERY_RANGE).
enum DiscoveryRange {
  off('OFF'),
  localhost('LOCALHOST'),
  subnet('SUBNET'),
  systemDefault('SYSTEM_DEFAULT');

  final String value;
  const DiscoveryRange(this.value);
}

// libc setenv(name, value, overwrite) via the already-loaded process symbols.
final DynamicLibrary _proc = DynamicLibrary.process();
final int Function(Pointer<Utf8>, Pointer<Utf8>, int) _setenv = _proc
    .lookupFunction<Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32),
        int Function(Pointer<Utf8>, Pointer<Utf8>, int)>('setenv');

void _setEnv(String key, String value) {
  final k = key.toNativeUtf8();
  final v = value.toNativeUtf8();
  try {
    _setenv(k, v, 1); // overwrite = 1
  } finally {
    malloc.free(k);
    malloc.free(v);
  }
}

/// Sets a single environment variable in-process (libc `setenv`). Exposed for
/// platform bootstrap code (e.g. Android) that must set ROS/DDS env vars before
/// `RclDart().init()` without building a whole [RosConfig].
void rclSetEnv(String key, String value) => _setEnv(key, value);

class RosConfig {
  /// DDS domain (ROS_DOMAIN_ID). Nodes only see peers on the same domain.
  final int? domainId;

  /// rmw implementation to load (RMW_IMPLEMENTATION), e.g. `rmw_cyclonedds_cpp`.
  final String? rmwImplementation;

  /// Explicit peer hosts to discover — the IP/hostname of the ROS 2 system(s)
  /// to talk to (ROS_STATIC_PEERS). Use for discovery across subnets / VPNs, or
  /// to pin exactly which machine you communicate with.
  final List<String> staticPeers;

  /// Automatic discovery range (ROS_AUTOMATIC_DISCOVERY_RANGE). Defaults to
  /// SUBNET when [staticPeers] is set, LOCALHOST when [localhostOnly] is true.
  final DiscoveryRange? discoveryRange;

  /// Restrict all traffic to loopback (convenience for
  /// discoveryRange == LOCALHOST).
  final bool localhostOnly;

  /// For bundled deployments: the app's bundle root (holds share/ament_index)
  /// and its lib dir — sets AMENT_PREFIX_PATH so typesupport discovery works
  /// with no ROS installed.
  final String? amentPrefixPath;

  /// Advanced: a raw CycloneDDS XML config (CYCLONEDDS_URI), e.g. to pin a
  /// network interface or set peers directly.
  final String? cyclonedaUri;

  /// rmw_zenoh: endpoints of the Zenoh router(s) to connect to as a CLIENT,
  /// e.g. `['tcp/192.168.1.50:7447']`. When set, [apply] selects
  /// `rmw_zenoh_cpp` (unless [rmwImplementation] overrides), writes a Zenoh
  /// session config, and points `ZENOH_SESSION_CONFIG_URI` at it. This is the
  /// NAT-friendly path for mobile: the device opens ONE connection to a router
  /// (run `ros2 run rmw_zenoh_cpp rmw_zenohd` on the robot/host) and sees every
  /// ROS 2 topic through it — no DDS multicast/peer routing needed.
  final List<String> zenohConnect;

  const RosConfig({
    this.domainId,
    this.rmwImplementation,
    this.staticPeers = const [],
    this.discoveryRange,
    this.localhostOnly = false,
    this.amentPrefixPath,
    this.cyclonedaUri,
    this.zenohConnect = const [],
  });

  /// Applies the configuration to the process environment. Call BEFORE
  /// `RclDart().init()`.
  void apply() {
    if (domainId != null) _setEnv('ROS_DOMAIN_ID', '$domainId');

    // Zenoh router mode: select rmw_zenoh_cpp + write a client session config.
    if (zenohConnect.isNotEmpty) {
      _setEnv('RMW_IMPLEMENTATION', rmwImplementation ?? 'rmw_zenoh_cpp');
      final endpoints = zenohConnect.map((e) => '"$e"').join(', ');
      // rmw_zenoh reads a JSON5 session config from ZENOH_SESSION_CONFIG_URI.
      final cfg = '{\n'
          '  mode: "client",\n'
          '  connect: { endpoints: [$endpoints] },\n'
          '  scouting: { multicast: { enabled: false } },\n'
          '}\n';
      try {
        final f = File(
            '${Directory.systemTemp.path}/rcldart_zenoh_session.json5');
        f.writeAsStringSync(cfg);
        _setEnv('ZENOH_SESSION_CONFIG_URI', f.path);
      } catch (_) {/* best effort — env may still be set externally */}
    } else if (rmwImplementation != null) {
      _setEnv('RMW_IMPLEMENTATION', rmwImplementation!);
    }
    if (amentPrefixPath != null) {
      _setEnv('AMENT_PREFIX_PATH', amentPrefixPath!);
    }

    var range = discoveryRange;
    if (range == null && localhostOnly) range = DiscoveryRange.localhost;
    if (range == null && staticPeers.isNotEmpty) range = DiscoveryRange.subnet;
    if (range != null) {
      _setEnv('ROS_AUTOMATIC_DISCOVERY_RANGE', range.value);
    }

    if (staticPeers.isNotEmpty) {
      // Jazzy reads a ';'-separated list of peer addresses.
      _setEnv('ROS_STATIC_PEERS', staticPeers.join(';'));
    }
    if (cyclonedaUri != null) {
      _setEnv('CYCLONEDDS_URI', cyclonedaUri!);
    }
  }
}
