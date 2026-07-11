# Where the native build outputs go, per platform

rcldart is a Flutter **FFI** plugin: there is no Java/Swift API surface, only
Dart calling C through `dart:ffi`. So on every platform the one job is *"get the
ROS 2 native libraries to a place the dynamic loader will find them, then
`DynamicLibrary.open` them from Dart."* What differs is **where that place is**
and **how the libraries get there**. This maps the whole flow — synthesised from
the reference projects `zenoh_ffi` (multi-platform FFI packaging) and
`ROS2-On-iOS` (cross-compiling ROS 2 for Apple), plus rcldart's own Android work.

## The one function that ties it together

Everything funnels through `dynamiclibraryloader(name)` in
`rcldart_utils/lib/src/dynamic_library_loader.dart`:

| Platform | What it opens | Why |
|----------|---------------|-----|
| Linux    | `lib<name>.so` | system/bundled `.so` on `LD_LIBRARY_PATH` / rpath |
| Android  | `lib<name>.so` (→ `nativeLibraryDir` fallback) | extracted from APK `jniLibs` |
| macOS    | `lib<name>.dylib` → `<name>.framework/<name>` → process | dylibs embedded in `.app/Contents/Frameworks` |
| iOS      | `lib<name>.dylib` → `<name>.framework/<name>` → process | dylibs embedded & signed in `.app/Frameworks` |
| Windows  | `<name>.dll` | DLL next to the executable |

The Apple branch tries the ROS dylib first, then the single-framework layout a
normal plugin uses, then `DynamicLibrary.process()` for the case where a lib was
**statically** linked into the executable (the model `zenoh_ffi` uses on iOS).

## Flow per platform

### Linux (desktop, dev host)
```
/opt/ros/jazzy/lib/librcl.so ─┐  (or a bundled closure via tool/bundle_ros_libs.sh)
                              └─► LD_LIBRARY_PATH / rpath ─► DynamicLibrary.open('librcl.so')
build output: build/linux/x64/{debug,release}/bundle/  (+ lib/ for bundled .so)
```
Source a ROS env, or bundle the `.so` closure. This is the only platform where a
real ROS install can be used directly.

### Android (APK, no ROS on device)
```
tool/build_ros2_android.sh (NDK + colcon, SHARED libs)
   └─► tool/pack_android_jnilibs.sh   # unversion lib*.so + patchelf SONAME/NEEDED
        └─► android/src/main/jniLibs/<abi>/*.so     ← you drop the closure here
             └─► [gradle] merged into app APK
                  └─► installed → app nativeLibraryDir  (on linker path)
                       └─► DynamicLibrary.open('librcl.so')
build output: <app>/build/app/outputs/flutter-apk/app-*.apk
```
Rules: APK ships only `lib*.so` (no versioned names, no symlinks, no
`LD_LIBRARY_PATH`) — the packer fixes that. See `docs/android_support.md`.

### iOS (IPA, no ROS on device)
```
tool/build_ros2_apple.sh PLATFORM=iOS            (colcon + ROS2-On-iOS/cmake/iOS.cmake, SHARED libs)
tool/build_ros2_apple.sh PLATFORM=iOS_Simulator
   └─► ios/ros/device/lib/*.dylib   +   ios/ros/sim/lib/*.dylib   ← staged here
        └─► [ios/rcldart.podspec  s.vendored_libraries] embed + CODE-SIGN
             └─► App.app/Frameworks/*.dylib   (@rpath)
                  └─► DynamicLibrary.open('librcl.dylib')
   ament index: ios/ros/device/share ─► resource bundle ─► AMENT_PREFIX_PATH at startup
build output: <app>/build/ios/iphoneos/Runner.app  →  .ipa
```
Device and simulator are BOTH arm64 but not lipo-compatible, so they live in
separate trees selected by `LIBRARY_SEARCH_PATHS[sdk=iphoneos*|iphonesimulator*]`
— exactly the split `zenoh_ffi`'s podspec uses for `device_libs/` vs `sim_libs/`.
Critical (from ROS2-On-iOS): build ROS 2 as **shared** libs — its rmw /
typesupport discovery is dlopen-based, so `BUILD_SHARED_LIBS=NO` breaks it.

### macOS (.app, bundled or system ROS)
```
tool/build_ros2_apple.sh PLATFORM=macOS   (colcon + macOS_M1.cmake, SHARED libs)
   └─► macos/ros/lib/*.dylib   ← staged here
        └─► [macos/rcldart.podspec  s.vendored_libraries] embed
             └─► App.app/Contents/Frameworks/*.dylib  (@rpath)
                  └─► DynamicLibrary.open('librcl.dylib')
build output: <app>/build/macos/Build/Products/{Debug,Release}/<app>.app
```
On a dev Mac you can instead source a system/RoboStack ROS and skip vendoring.

### Windows (.exe)
```
ROS 2 <name>.dll next to Runner.exe (or on PATH) ─► DynamicLibrary.open('<name>.dll')
build output: <app>/build/windows/x64/runner/{Debug,Release}/
```
Not yet exercised for the ROS closure; same pattern as Linux with `.dll`.

## The FFI-plugin packaging trick (shared C across platforms)

Like `zenoh_ffi`, the platform folders don't duplicate the C source. Each
`ios/Classes/rcldart.c` / `macos/Classes/rcldart.c` is a thin **forwarder** that
`#include`s `../src/rcldart.c`, because CocoaPods podspecs can't reference paths
above the podspec dir. Linux/Android/Windows point their CMake straight at
`src/CMakeLists.txt`. One C implementation, five build systems.

## Who produces the libraries

| Platform | Toolchain | Produces | Bundled by |
|----------|-----------|----------|-----------|
| Linux    | host colcon / system ROS | `.so` | rpath / `tool/bundle_ros_libs.sh` |
| Android  | NDK + colcon | `.so` | `android/build.gradle` jniLibs |
| iOS      | Xcode + colcon + `iOS.cmake` | `.dylib` | `ios/rcldart.podspec` vendored_libraries |
| macOS    | Xcode + colcon + `macOS_M1.cmake` | `.dylib` | `macos/rcldart.podspec` vendored_libraries |
| Windows  | MSVC + colcon | `.dll` | copy next to exe |

The Dart message packages (`rcldart_ws/dart/*`) are platform-independent pure
Dart+FFI — they need no per-platform build; they only require that each type's
`*__rosidl_typesupport_c` / `*__rosidl_generator_c` library exists in the
platform's bundled closure.
