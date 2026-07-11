// src/android_bootstrap.dart
//
// One-call setup for running rcldart on Android with NO ROS installed on the
// device — everything is bundled in the APK (see android/ + docs/android_support.md).
//
// Android differs from desktop in three ways this handles:
//   1. Network discovery: bionic's getifaddrs() does not surface a usable
//      interface in the app sandbox, so DDS finds no peers. We (a) load the
//      getifaddrs shim and (b) pin the interface/peers via CycloneDDS config.
//   2. Library resolution: the bundled ROS closure lives in the app's
//      nativeLibraryDir; we point the loader fallback there.
//   3. ament index: there is no /opt/ros — the app copies the bundled `share/`
//      tree to its files dir and we set AMENT_PREFIX_PATH to it.
//
// Usage (call ONCE, before RclDart().init()):
//
//   AndroidRosBootstrap.prepare(
//     nativeLibDir: nativeLibDir,      // from the platform side (see docs)
//     amentPrefixPath: amentDir,       // where you copied bundled share/
//     domainId: 0,
//     peers: ['192.168.1.50'],         // the robot / agent to talk to
//   );
//   RclDart().init();
import 'dart:ffi';
import 'dart:io';

import 'package:rcldart_utils/rcldart_utils.dart';

import 'config.dart';

class AndroidRosBootstrap {
  /// Prepares a bundled ROS 2 runtime on Android. No-op on other platforms.
  ///
  /// [nativeLibDir] — the app's `applicationInfo.nativeLibraryDir` (where
  ///   Android extracted the bundled `.so`). Optional but recommended: it lets
  ///   the loader fall back to an absolute path for any lib rcl `dlopen()`s.
  /// [amentPrefixPath] — a directory you populated (usually under the app's
  ///   files dir) with the bundled ROS `share/` ament index, so typesupport
  ///   discovery works with no ROS installed.
  /// [peers] — explicit peer hosts (the robot/agent IPs). On Android multicast
  ///   discovery is usually blocked, so unicast peers are how nodes find each
  ///   other. Written into a CycloneDDS unicast config unless [cyclonedaUri] is
  ///   given.
  /// [domainId] — ROS_DOMAIN_ID.
  /// [cyclonedaUri] — advanced: a full CycloneDDS XML config; overrides the
  ///   auto-generated one.
  /// [zenohConnect] — if non-empty, use the rmw_zenoh bridge instead of DDS:
  /// connect as a client to these Zenoh router endpoints (e.g.
  /// `['tcp/192.168.1.50:7447']`). This is the NAT-friendly path — see the class
  /// docs on [RosConfig.zenohConnect].
  static void prepare({
    String? nativeLibDir,
    String? amentPrefixPath,
    List<String> peers = const [],
    int domainId = 0,
    String? cyclonedaUri,
    List<String> zenohConnect = const [],
  }) {
    if (!Platform.isAndroid) return;

    // 1. Load the getifaddrs shim so DDS discovery can pick an interface.
    //    (Best-effort from Dart; for guaranteed symbol interposition also load
    //    it from the app side via System.loadLibrary("rcldart_ifaddrs") — see
    //    docs/android_support.md.)
    try {
      DynamicLibrary.open('librcldart_ifaddrs.so');
    } catch (_) {
      // Not fatal — the app may have already loaded it, or pinned the interface
      // via cyclonedaUri instead.
    }

    // 2. Point the loader fallback at the extracted native libs.
    if (nativeLibDir != null) rcldartAndroidLibDir = nativeLibDir;

    // 3a. Zenoh bridge mode — one client connection to a router; no DDS config.
    if (zenohConnect.isNotEmpty) {
      RosConfig(
        domainId: domainId,
        amentPrefixPath: amentPrefixPath,
        zenohConnect: zenohConnect,
      ).apply();
      return;
    }

    // 3b. CycloneDDS + unicast peers + ament index.
    final uri = cyclonedaUri ?? _defaultCycloneUri(peers);
    RosConfig(
      domainId: domainId,
      rmwImplementation: 'rmw_cyclonedds_cpp',
      amentPrefixPath: amentPrefixPath,
      cyclonedaUri: uri,
    ).apply();

    // Belt-and-suspenders: some stacks read ROS_STATIC_PEERS directly.
    if (peers.isNotEmpty) rclSetEnv('ROS_STATIC_PEERS', peers.join(';'));
  }

  /// A CycloneDDS config that actually discovers on Android. The naive
  /// "AllowMulticast=false + no peers" does NO discovery at all — the node
  /// can't even see its own topics. Instead:
  ///   * always unicast-discover `localhost` — makes the node find itself and
  ///     any co-located node WITHOUT relying on multicast (sandbox-safe), so
  ///     topics appear even on an isolated emulator;
  ///   * add each explicit [peers] address (the robot / agent / dev host — use
  ///     10.0.2.2 to reach the host from an emulator);
  ///   * `AllowMulticast=spdp` still lets discovery multicast work on real
  ///     Wi-Fi (with the MulticastLock the host activity holds) while keeping
  ///     data traffic unicast, which is the reliable path on mobile.
  static String _defaultCycloneUri(List<String> peers) {
    final peerXml = (['localhost', ...peers])
        .map((p) => '<Peer address="$p"/>')
        .join();
    return '<CycloneDDS><Domain>'
        '<General>'
        '<Interfaces><NetworkInterface autodetermine="true" multicast="true"/></Interfaces>'
        '<AllowMulticast>spdp</AllowMulticast>'
        '<EnableMulticastLoopback>true</EnableMulticastLoopback>'
        '</General>'
        '<Discovery>'
        '<ParticipantIndex>auto</ParticipantIndex>'
        '<MaxAutoParticipantIndex>32</MaxAutoParticipantIndex>'
        '<Peers>$peerXml</Peers>'
        '</Discovery>'
        '</Domain></CycloneDDS>';
  }
}

/// Setup for running rcldart on iOS/macOS with the ROS 2 dylibs bundled in the
/// app (no ROS installed). Simpler than Android: Apple has no getifaddrs quirk
/// and no jniLibs indirection — the embedded dylibs resolve by @rpath. The only
/// thing rcl needs is AMENT_PREFIX_PATH pointing at the embedded ament index
/// (the podspec ships it as a `rcldart_ros` resource bundle; the app resolves
/// that bundle path on the platform side and passes it here).
class AppleRosBootstrap {
  /// No-op unless on iOS/macOS. Call BEFORE `RclDart().init()`.
  static void prepare({
    required String amentPrefixPath,
    int domainId = 0,
    String rmwImplementation = 'rmw_cyclonedds_cpp',
    List<String> peers = const [],
    String? cyclonedaUri,
  }) {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    RosConfig(
      domainId: domainId,
      rmwImplementation: rmwImplementation,
      amentPrefixPath: amentPrefixPath,
      staticPeers: peers,
      cyclonedaUri: cyclonedaUri,
    ).apply();
  }
}
