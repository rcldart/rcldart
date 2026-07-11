# Running rcldart on Android (no ROS on the device)

rcldart apps can run on a stock Android phone with **no ROS installed** — the
ROS 2 runtime is cross-compiled once and **bundled inside the APK** as native
libraries (`jniLibs`). At runtime rcl `dlopen()`s them exactly like it does the
system libraries on desktop. This is the same model the ros2-java Android
examples use, adapted for rcldart's Dart-FFI design.

```
┌ APK ─────────────────────────────────────────────┐
│  lib/arm64-v8a/                                    │
│    librcl.so  librmw.so  librmw_cyclonedds_cpp.so  │  ← bundled ROS 2 closure
│    libddsc.so  librosidl_runtime_c.so  ...         │     (cross-compiled)
│    librcldart_ifaddrs.so                           │  ← getifaddrs shim
│  assets/ros_ament/share/...                        │  ← ament index
│  Dart: package:rcldart (FFI)                       │
└────────────────────────────────────────────────────┘
        │ DynamicLibrary.open('librcl.so')  → nativeLibraryDir (auto on path)
```

## What's already wired in this repo

| Piece | Location | Does |
|-------|----------|------|
| Plugin Android module | `android/build.gradle` | bundles `jniLibs/<abi>/*.so`, builds the shim, no-strip/legacy-packaging |
| getifaddrs shim | `android/src/main/cpp/rcldart_ifaddrs.c` + `android/CMakeLists.txt` | working `getifaddrs()` for DDS discovery |
| Loader fallback | `rcldart_utils/.../dynamic_library_loader.dart` | resolves `lib*.so` from `nativeLibraryDir` |
| Bootstrap | `lib/src/android_bootstrap.dart` (`AndroidRosBootstrap`) | loads shim, sets CycloneDDS unicast + ament env |
| Cross-compile recipe | `tool/build_ros2_android.sh` | NDK + colcon → the closure |
| Packer | `tool/pack_android_jnilibs.sh` | unversion names + fix SONAMEs → `jniLibs` |
| Example host | `rcldart_ws/apps/flutglove/android/` | multicast lock, early shim load, `nativeLibDir`/ament over a MethodChannel |

You still have to **produce the cross-compiled `.so`** (needs an Android NDK)
and drop them in — that step is machine-specific and can't be committed.

## The two Android-specific gotchas (handled for you)

1. **APKs only ship `lib*.so`** — no versioned names (`libddsc.so.0`), no
   symlinks, and there's no `LD_LIBRARY_PATH`. `pack_android_jnilibs.sh` renames
   every library to an unversioned `lib*.so` and rewrites each `DT_SONAME` /
   `DT_NEEDED` with `patchelf` so the flat `nativeLibraryDir` is self-consistent.

2. **Discovery** — Android drops multicast unless you hold a `MulticastLock`
   (done in `MainActivity`), and bionic's `getifaddrs()` doesn't surface a
   usable interface in the sandbox (fixed by the shim, loaded early via
   `System.loadLibrary`). `AndroidRosBootstrap` additionally writes a CycloneDDS
   config that pins unicast `peers`, which is the most reliable path on mobile.

## Step-by-step

### 1. Cross-compile the ROS 2 closure (once, on a Linux host with the NDK)

```bash
export ANDROID_NDK=/path/to/android-ndk-r26
API=24 ABI=arm64-v8a tool/build_ros2_android.sh
```

Cross-compiling ROS 2 is a two-pass build (host generators, then target) — read
the comments in the script; it links to the official cross-compilation guide.
The script ends by calling the packer, which fills
`android/src/main/jniLibs/arm64-v8a/` and `android/src/main/assets/ros_ament/`.

If you already have a cross-built `install/` tree, skip straight to:

```bash
tool/pack_android_jnilibs.sh /path/to/install arm64-v8a
```

### 2. Generate your message packages as usual

The Dart message packages (`rcldart_ws/dart/*`) are pure Dart + FFI and are
platform-independent — no Android-specific step. Just make sure every message
type you use has its `*__rosidl_typesupport_c.so` / `*__rosidl_generator_c.so`
in the bundled closure (the packer copies whatever is in the `install` tree).

### 3. Configure discovery in the app

In `flutglove/lib/main.dart`:

```dart
const int _domainId = 0;
const List<String> _peers = ['192.168.1.50']; // your robot / DDS agent
```

### 4. Build & run

```bash
cd rcldart_ws/apps/flutglove
flutter build apk           # or: flutter run  (device connected)
```

## Verifying

- `patchelf --print-needed android/src/main/jniLibs/arm64-v8a/librcl.so`
  should list only unversioned `lib*.so` that exist in the same folder.
- On device, `adb logcat | grep -i rcldart` shows the shim log line and rcl
  init. If discovery finds no peers, double-check the multicast lock, the shim
  load, and that `_peers` points at a reachable host on the same `ROS_DOMAIN_ID`.

## Honest limitations

- **You need the NDK** to produce the closure; this repo ships the
  infrastructure and scripts, not prebuilt ROS 2 Android binaries.
- Cross-compiling the full `sensor_msgs`/`nav_msgs` typesupport set is the
  bulk of the effort; start from the trimmed `ros2.repos` in the build script
  and add packages as your app needs them.
- The getifaddrs shim uses `System.loadLibrary` for symbol interposition; this
  is reliable in practice but, for stubborn DDS builds, pinning the interface
  explicitly via `cyclonedaUri`/`peers` is the belt-and-suspenders fallback.
- Alternative deployment (not this doc): run full ROS 2 in a Termux/proot
  Ubuntu on the phone — see `ros2_android/` — no cross-compile, but heavier and
  not a self-contained APK.
