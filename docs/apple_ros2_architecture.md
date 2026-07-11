# ROS 2 on iOS & macOS — end-to-end architecture (rcldart)

Run a rcldart Flutter app on **iOS / macOS with no ROS installed** — the ROS 2
runtime is cross-compiled once and embedded in the app bundle; `rcl` `dlopen()`s
it at runtime, exactly like on every other platform. Packaging follows
**zenoh_ffi** (a shipping multi-platform Dart FFI plugin); the cross-compile
follows **ROS2-On-iOS**. See `apple_ros2_architecture_spec.md` for the spec this
realizes, and `build_output_paths.md` for the cross-platform artifact map.

## The whole pipeline

```
 Mac + Xcode + CMake≥3.23 + Python3.11
   │  colcon --merge-install  +  cmake/apple/<target>.cmake   (SHARED libs!)
   │  flags: BUILD_TESTING=NO  THIRDPARTY=FORCE  rcl_logging_noop
   ▼
 tool/build_ros2_apple.sh  ── stages ──►  ios/ros/{device,sim}/lib/*.dylib
                                          macos/ros/lib/*.dylib   (+ share/ ament)
   │  pod install  (ios/rcldart.podspec · macos/rcldart.podspec)
   │    s.vendored_libraries  → embed + CODE-SIGN into  App.app/Frameworks/*.dylib
   │    s.resource_bundles    → ship ament index as  rcldart_ros.bundle/share
   ▼
 Runtime (device):
   Swift host  ──MethodChannel('rcldart/apple')──►  Dart
     amentPrefixPath = rcldart_ros.bundle/…/share
   AppleRosBootstrap.prepare(amentPrefixPath, rmw:'rmw_fastrtps_cpp')
   RclDart().init()
     dynamiclibraryloader('rcl') → DynamicLibrary.open('librcl.dylib')  @rpath
       → rcl_* + generic ros_cdr decode  (same code as Linux/Android)
```

## Why these choices

| Decision | Why |
|----------|-----|
| **SHARED dylibs** (not static `.a`) | ROS 2 rmw + rosidl typesupport are discovered by `dlopen`; static linking (what zenoh_ffi can do as one self-contained lib) breaks that. iOS permits embedded, code-signed dylibs in `Frameworks/`. |
| **Jazzy** everywhere | rcldart's ffigen bindings + generated Dart message packages are Jazzy. ROS2-On-iOS is Humble — we reuse its *recipe*, not its repos (cross-distro = ABI break). |
| **rmw_fastrtps** default on Apple | ROS2-On-iOS validates Fast-DDS on iOS (with the `if_arp` patch). CycloneDDS (our Android/Linux default) is the alternative but needs Android-style interface care on iOS. `AppleRosBootstrap` sets whichever you bundled. |
| **rcl_logging_noop** | drops the spdlog dependency. |
| **device / sim separate dirs** | both are arm64 yet not lipo-compatible — the podspec selects via `LIBRARY_SEARCH_PATHS[sdk=iphoneos*|iphonesimulator*]` (the zenoh_ffi pattern). |

## Files (all self-contained in rcldart)

| Path | Role |
|------|------|
| `cmake/apple/{iOS,iOS_Simulator_M1,iOS_Simulator,macOS_M1,macOS}.cmake` | per-target toolchains (`-target …-apple-ios`, sysroot from `xcodebuild`) |
| `apple/ros2.jazzy.repos` | minimal Jazzy source set (rcl + rmw_fastrtps + rosidl + common_interfaces) |
| `apple/patches/README.md` | the iOS Fast-DDS `if_arp.h→ethernet.h` + spdlog-ignore notes (applied by the driver as `sed`) |
| `tool/build_ros2_apple.sh` | driver: fetch → patch → (host-gen → target) build → stage dylibs+ament |
| `ios/rcldart.podspec`, `macos/rcldart.podspec` | `vendored_libraries` + `resource_bundles` + rpath, embed & sign |
| `rcldart_utils/.../dynamic_library_loader.dart` | Apple branch: `lib<name>.dylib` → framework → `process()` |
| `lib/src/android_bootstrap.dart` → `AppleRosBootstrap` | sets rmw + AMENT_PREFIX_PATH + peers before init |
| flutglove `ios/` + `macos/` Swift hosts | `MethodChannel('rcldart/apple')` returns the ament bundle path |

## Build & run

**Choose the RMW** with `RMW=fastrtps` (default, iOS-proven) or `RMW=cyclonedds`
(the same DDS rcldart uses on Linux/Android/no-ROS — one stack everywhere). Set
`_appleRmw` in `flutglove/lib/main.dart` to match what you bundled.

```bash
# 1. cross-compile (on a Mac). macOS first — it also produces the host
#    rosidl generators the iOS pass reuses. RMW=fastrtps (default) or cyclonedds.
PLATFORM=macOS_M1 RMW=cyclonedds tool/build_ros2_apple.sh
PLATFORM=iOS RMW=cyclonedds HOST_INSTALL=~/ros2_apple_ws/install_macOS_M1 tool/build_ros2_apple.sh
PLATFORM=iOS_Simulator_M1 RMW=cyclonedds HOST_INSTALL=~/ros2_apple_ws/install_macOS_M1 tool/build_ros2_apple.sh

# 2. build the app
cd rcldart_ws/apps/flutglove
flutter build macos          # or: flutter run -d macos
flutter build ios            # device; sim: flutter run -d <simulator>
```

Set discovery in `flutglove/lib/main.dart` (`_domainId`, `_peers`) — on Wi-Fi,
peers are the most reliable way for nodes to find each other.

## The two-pass cross-compile (why iOS needs HOST_INSTALL)

`rosidl` runs Python code generators that must execute on the **host** while
emitting code for the **target**. So:
1. `PLATFORM=macOS_M1` builds natively — its `install/` has host-runnable
   generators.
2. `PLATFORM=iOS … HOST_INSTALL=<that install>` cross-builds, putting the host
   install on `AMENT_PREFIX_PATH` so the generators run while the libraries
   compile for arm64-apple-ios. (See the official ROS 2 cross-compilation guide.)

## Honest limits

- Requires a **Mac + Xcode**; cannot be compiled or run on the Linux dev host.
  This repo ships the infrastructure + scripts, not prebuilt Apple binaries.
- The Jazzy iOS path may need small per-package patches beyond `if_arp`
  (the driver applies patches as readable `sed` steps — adapt as needed).
- Verified on the Linux host: the Dart side compiles (Apple branch guarded), the
  loader/bootstrap analyze clean, flutglove still builds for Linux. The Apple
  native build itself is only runnable on macOS.
- App Store: embedded signed dylibs are permitted for development/enterprise;
  App Store review of a bundled ROS 2 is untested.
