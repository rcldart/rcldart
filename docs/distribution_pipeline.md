# Distribution pipeline — automatic install + bundle fetch

rcldart is a Dart FFI package plus a per-platform native ROS 2 runtime. This
describes the **fully automatic pipeline** so that, in an app, `flutter pub get`
+ `flutter build` pulls both the Dart code and the native ROS closure with no
manual steps — modelled on how `zenoh_ffi` fetches its native lib at build time.

## Two halves

1. **Dart install (pub.dev)** — `flutter pub add rcldart` pulls the Dart package.
   See [PUBLISHING.md](../PUBLISHING.md) for making rcldart publishable
   (`ros_cdr` is vendored in; `rcldart_utils` is the one sibling that must be
   published too).
2. **Native ROS closure (build-time fetch)** — the platform build downloads a
   prebuilt closure from a URL you control and drops it where the packagers
   expect it. No huge binaries in git or on pub.dev.

## The native fetch, per platform

| Platform | Hook | URL variable | Extracts to |
|----------|------|-------------|-------------|
| Android  | `android/build.gradle` task `fetchRosBundle` (runs before `preBuild`) | `-PrcldartRosBundleUrl=` / `RCLDART_ROS_BUNDLE_URL` | `android/src/main/jniLibs/<abi>/` |
| iOS      | `ios/rcldart.podspec` `prepare_command` (at `pod install`) | `RCLDART_ROS_BUNDLE_URL_IOS` | `ios/ros/` |
| macOS    | `macos/rcldart.podspec` `prepare_command` | `RCLDART_ROS_BUNDLE_URL_MACOS` | `macos/ros/` |
| Linux    | system ROS (sourced) or `tool/bundle_ros_libs.sh` | — | app bundle `lib/` |

Each hook is **no-op-safe**: if the closure is already present, or no URL is set,
it logs and the build proceeds (the app just has no ROS runtime until the closure
is provided).

## Producing the artifacts (one time, per platform)

```bash
# 1. cross-compile the closure locally (needs the platform toolchain)
tool/build_ros2_android.sh                      # → android/src/main/jniLibs/<abi>
PLATFORM=macOS_M1 tool/build_ros2_apple.sh      # → macos/ros
PLATFORM=iOS HOST_INSTALL=… tool/build_ros2_apple.sh  # → ios/ros/device (+ sim)

# 2. package into release artifacts
tool/package_ros_bundle.sh                       # → dist/ros-android-arm64-v8a.tar.gz,
                                                 #   dist/ros-ios.tar.gz, dist/ros-macos.tar.gz

# 3. upload dist/* to a GitHub release, copy the asset URLs
```

## Consuming automatically (every build thereafter)

```bash
# Android
flutter build apk -PrcldartRosBundleUrl=https://github.com/…/ros-android-arm64-v8a.tar.gz
# iOS
export RCLDART_ROS_BUNDLE_URL_IOS=https://github.com/…/ros-ios.tar.gz
flutter build ios
# macOS
export RCLDART_ROS_BUNDLE_URL_MACOS=https://github.com/…/ros-macos.tar.gz
flutter build macos
```

Put the property/env in the app's `android/gradle.properties`, CI env, or an
`.envrc` so it's set once and every build auto-fetches.

## End-to-end (what a downstream app author does)

```bash
flutter create my_ros_app && cd my_ros_app
flutter pub add rcldart                          # Dart code (pub.dev)
# set the bundle URL(s) once (gradle.properties / env)
flutter run                                       # native closure auto-fetched + bundled
```

```dart
import 'package:rcldart/rcldart.dart';            // rcl + generic ros_cdr decode, one import
```

## Honest status

- The **fetch hooks + packaging script are in place** and no-op-safe. The
  **prebuilt artifacts don't exist yet** — they require running the cross-compile
  scripts on the right toolchains (NDK / Xcode) and hosting the tarballs. Until
  then, set the URL to your own release or bundle the closure manually.
- `rcldart_utils` still needs publishing to pub.dev for a clean `pub add rcldart`
  (see PUBLISHING.md); `ros_cdr` is already vendored in, `std_msgs` was removed
  as unused.
