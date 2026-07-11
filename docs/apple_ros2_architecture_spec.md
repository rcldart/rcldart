# SPEC / PROMPT — ROS 2 on iOS & macOS for rcldart (zenoh_ffi-style)

> This is the self-authored specification I (the agent) wrote before building
> the Apple architecture, per the request "önce bir prompt oluştur, detaylandır,
> sonra geliştir". It defines the goal, the reference patterns, the decisions,
> and the concrete deliverables. The implementation that follows realizes it.

## Goal (the prompt)

> Build the complete, editable architecture that lets a rcldart Flutter app run
> on **iOS and macOS with NO ROS installed on the device** — the ROS 2 runtime
> is cross-compiled once and embedded in the app bundle, and `rcl` `dlopen()`s
> it at runtime. Model the packaging on **zenoh_ffi** (a shipping multi-platform
> Dart FFI plugin) and the cross-compile on **ROS2-On-iOS** (which builds ROS 2
> for iOS/macOS). Make it self-contained inside rcldart (own toolchains, repos,
> build driver, podspecs, loader, bootstrap, native host, docs) and coherent
> with the rest of rcldart (Jazzy, same generated Dart message packages).

## Reference patterns (understand, then apply)

**zenoh_ffi** (FFI-plugin packaging):
- `Classes/*.c` per platform is a thin **forwarder** that `#include`s `../src/*`
  (podspecs can't reference paths above their dir). One C impl, many builds.
- Per-platform loader: iOS `DynamicLibrary.process()` (static) / macOS framework
  or `-l` / Android+Linux `lib*.so` / Windows `*.dll`.
- Podspec `prepare_command` builds the native lib at `pod install` time; device
  and simulator go to **separate dirs** (both arm64, not lipo-able) selected by
  `OTHER_LDFLAGS[sdk=iphoneos*|iphonesimulator*]`.

**ROS2-On-iOS** (cross-compile):
- `colcon build --merge-install --cmake-force-configure` with a per-platform
  **CMake toolchain file** (`-target arm64-apple-ios`, sysroot from `xcodebuild`).
- Flags that make ROS 2 build for Apple: `BUILD_TESTING=NO`, `THIRDPARTY=FORCE`
  (Fast-DDS vendors its deps), `COMPILE_TOOLS=NO`, `BUILD_MEMORY_TOOLS=OFF`,
  `RCL_LOGGING_IMPLEMENTATION=rcl_logging_noop` (drop spdlog).
- **Do NOT** set `BUILD_SHARED_LIBS=NO` — ROS 2 rmw/typesupport discovery is
  `dlopen`-based, so libs MUST be shared (`.dylib`). iOS allows embedded,
  code-signed dylibs in `Frameworks/`.
- iOS quirk: Fast-DDS `IPFinder.cpp` uses `<net/if_arp.h>` (macOS-only); patch to
  `<net/ethernet.h>` for the iOS SDK.
- `AMENT_IGNORE` on `rcl_logging_spdlog`.

## Key decisions

1. **Distro = Jazzy** (match the rest of rcldart; the generated Dart packages and
   ffigen bindings are Jazzy). ROS2-On-iOS is Humble — we reuse its *recipe*, not
   its Humble repos. Cross-distro would break ABI.
2. **rmw**: default to the proven Apple stack. iOS is validated with Fast-DDS
   (light-tech fork's `if_arp` patch); macOS works with either. Keep it a build
   variable; `AppleRosBootstrap` sets `RMW_IMPLEMENTATION` to match what was
   bundled. (CycloneDDS — our Android/Linux default — is the alternative; on iOS
   it needs the same interface-discovery care as Android.)
3. **Shared dylibs, embedded + code-signed** in the app bundle Frameworks/,
   resolved by `@rpath`. `DynamicLibrary.open('librcl.dylib')`.
4. **ament index** shipped as a podspec `resource_bundle`; the native host hands
   its path to Dart over a `MethodChannel('rcldart/apple')`, `AppleRosBootstrap`
   sets `AMENT_PREFIX_PATH`.
5. **Self-contained**: rcldart ships its own `cmake/apple/*.cmake`, `apple/ros2.repos`,
   `tool/build_ros2_apple.sh`, podspecs — no dependency on the sibling reference
   checkouts at runtime/build.

## Deliverables (what "develop it" produces)

| # | Artifact | Purpose |
|---|----------|---------|
| 1 | `cmake/apple/{iOS,iOS_Simulator_M1,iOS_Simulator,macOS_M1,macOS,macCatalyst_M1}.cmake` | per-target CMake toolchains |
| 2 | `apple/ros2.jazzy.repos` | minimal Jazzy source set for the Apple cross-build |
| 3 | `apple/patches/fastdds_ios_ifaddrs.patch` (+ apply step) | the iOS `if_arp.h→ethernet.h` fix |
| 4 | `tool/build_ros2_apple.sh` (rewritten) | full driver: host-gen pass → target build → stage dylibs+ament |
| 5 | `ios/rcldart.podspec`, `macos/rcldart.podspec` | vendor + embed + sign the dylibs, ship ament bundle, set rpath |
| 6 | loader Apple branch (already) | `lib<name>.dylib` → framework → process |
| 7 | `AppleRosBootstrap.prepare()` (already) | rmw + ament + peers before `RclDart().init()` |
| 8 | flutglove `macos/` + `ios/` platforms + Swift host + `main()` Apple branch | native host provides ament path; app boots ROS on Apple |
| 9 | `docs/apple_ros2_architecture.md` | end-to-end architecture + build/run guide + honest limits |

## Runtime flow (target)

```
Xcode + colcon + cmake/apple/<target>.cmake  (SHARED libs, rcl_logging_noop)
  → ios/ros/{device,sim}/lib/*.dylib  +  macos/ros/lib/*.dylib   (+ share/ ament)
    → podspec vendored_libraries → embed + code-sign → App.app/Frameworks/*.dylib
      → Dart: AppleRosBootstrap.prepare(amentPrefixPath) → RclDart().init()
        → dynamiclibraryloader('rcl') → DynamicLibrary.open('librcl.dylib') @rpath
          → rcl_* + generic ros_cdr decode (same as every other platform)
```

## Honesty / limits

- Building requires a **Mac + Xcode + CMake 3.23 + Python 3.11**; it cannot be
  compiled or run on the Linux dev host — this repo ships the infrastructure and
  scripts, not prebuilt Apple binaries.
- The Apple cross-compile is the heaviest platform; the Jazzy iOS path may need
  small per-package patches beyond the `if_arp` one — the driver is written to be
  read and adapted, not run blind.
