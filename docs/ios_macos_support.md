# Running rcldart on iOS & macOS (no ROS on the device)

Same idea as Android: the ROS 2 runtime is **cross-compiled once** and **bundled
inside the app**, and rcl `dlopen()`s it at runtime. The mechanics differ because
Apple uses `.dylib` embedded in the app bundle's `Frameworks/` (code-signed on
iOS) instead of `jniLibs`. The recipe here is distilled from the reference
project **ROS2-On-iOS** (which builds ROS 2 for iOS/macOS) and the packaging
pattern from **zenoh_ffi**. For the full cross-platform artifact map see
[`build_output_paths.md`](build_output_paths.md).

## The one non-obvious fact

**Build ROS 2 as SHARED libraries — do NOT pass `BUILD_SHARED_LIBS=NO`.** ROS 2
discovers its rmw implementation and message typesupport by `dlopen()`ing plugin
libraries by name. Statically linking (the approach `zenoh_ffi` can use because
it is one self-contained lib) breaks that discovery. iOS permits loading
embedded, code-signed dylibs from the app's `Frameworks/`, so shared libraries
are both required and allowed.

## What's wired in this repo

| Piece | Location | Does |
|-------|----------|------|
| Loader | `rcldart_utils/.../dynamic_library_loader.dart` | opens `lib<name>.dylib` (→ framework → process) |
| iOS podspec | `ios/rcldart.podspec` | embeds `ios/ros/{device,sim}/lib/*.dylib`, ships ament index, sets rpath |
| macOS podspec | `macos/rcldart.podspec` | embeds `macos/ros/lib/*.dylib`, ships ament index |
| Cross-compile | `tool/build_ros2_apple.sh` | colcon + Apple toolchains → staged dylibs |
| Toolchains | `ROS2-On-iOS/cmake/*.cmake` | iOS / iOS_Simulator / macOS CMake toolchains |
| Bootstrap | `AppleRosBootstrap.prepare` (`lib/src/android_bootstrap.dart`) | sets AMENT_PREFIX_PATH + rmw before init |

You still need a **Mac with Xcode** to produce the dylibs and build the app —
that step can't be committed or run on Linux.

## Steps

### 1. Cross-compile ROS 2 (on a Mac, once per platform)

```bash
# device + simulator for iOS, and/or macOS
PLATFORM=iOS            tool/build_ros2_apple.sh
PLATFORM=iOS_Simulator  tool/build_ros2_apple.sh
PLATFORM=macOS          tool/build_ros2_apple.sh
```

Each run stages `*.dylib` + the ament `share/` into the folder the matching
podspec bundles:

```
ios/ros/device/lib/*.dylib     ios/ros/device/share/    (real iPhone/iPad)
ios/ros/sim/lib/*.dylib        (Simulator)
macos/ros/lib/*.dylib          macos/ros/share/
```

Cross-compiling ROS 2 for Apple is involved (needs CMake 3.23, Python 3.11, and
a two-pass host-generators-then-target build). Read `tool/build_ros2_apple.sh`
and the ROS2-On-iOS README; start from its prebuilt release if you want to skip
a day of building.

### 2. Configure discovery + ament in the app

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isIOS || Platform.isMacOS) {
    // Resolve the embedded ament index bundle path on the platform side
    // (e.g. Bundle.main.path(forResource:"rcldart_ros", ofType:"bundle"))
    // and pass it over a MethodChannel, like the Android host does.
    final ament = await _channel.invokeMethod<String>('amentPrefixPath');
    AppleRosBootstrap.prepare(amentPrefixPath: ament!, domainId: 0);
  }
  RclDart().init();
  // ...
}
```

Unlike Android, Apple needs no getifaddrs shim and no multicast lock for local
Wi-Fi discovery, so `AppleRosBootstrap` only sets the ament path + rmw (+ peers
if you talk across subnets).

### 3. Build

```bash
flutter build ios      # or: flutter build macos / flutter run
```

CocoaPods embeds and code-signs the vendored dylibs into the app's `Frameworks/`
during the build; at runtime `DynamicLibrary.open('librcl.dylib')` resolves them
via `@rpath`.

## Gotchas

- **Device vs simulator dylibs are separate** (both arm64, not lipo-able). The
  podspec picks the right tree with `LIBRARY_SEARCH_PATHS[sdk=…]`. For a
  simulator build, vendor `ros/sim/lib` (see the note in `ios/rcldart.podspec`).
- **Code signing**: every embedded dylib is re-signed with the app's identity by
  Xcode's "Embed Frameworks" phase — no action needed beyond a valid signing
  team, but a missing team will fail the embed, not the compile.
- **Deployment target**: iOS 14 / macOS 11 minimum (rcpputils / Fast-DDS).
- **App Store**: embedded dylibs are allowed, but each must be signed and carry
  no restricted symbols; this repo targets development/enterprise distribution —
  App Store review of a bundled ROS 2 is untested.

## Honest limitations

- Needs a Mac + Xcode to produce the dylibs and the app; this repo ships the
  infrastructure and scripts, not prebuilt ROS 2 Apple binaries.
- The Apple cross-compile is the heaviest of all platforms; lean on the
  ROS2-On-iOS prebuilt releases and its toolchains rather than starting cold.
- macOS on a dev machine can instead use a system/RoboStack ROS install and skip
  vendoring entirely — drop the `vendored_libraries` line and source the env.
