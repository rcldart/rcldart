# Running rcldart apps WITHOUT ROS installed

**Short answer: yes — bundling the ROS 2 shared libraries into the app bundle
works.** rcldart never links rcl/rmw; it `dlopen`s them by name at runtime, so
if the `.so` files are next to the app (on `LD_LIBRARY_PATH` / `$ORIGIN/lib`)
they load with no ROS install.

## What it takes (verified empirically on a clean `env -i` shell)

1. **The full `.so` closure**, not a subset. Staging only a handful of libs
   makes `rcl_node_init` fail with:
   ```
   Type support not from this implementation. Got:
   ```
   That error means the rosidl typesupport dispatch couldn't find the
   rmw-specific typesupport. Fix: bundle, for every interface package used
   (incl. the ones `rcl_node_init` itself needs — `rcl_interfaces`,
   `type_description_interfaces`, `service_msgs`, `builtin_interfaces`):
   `lib<pkg>__rosidl_typesupport_c.so`, `..._fastrtps_c.so`,
   `..._introspection_c.so`, `..._generator_c.so`.
   With the complete set the typesupport error is gone and `rcl_node_init`
   succeeds.

2. **The rmw implementation + its DDS core.** Pick ONE and bundle its whole
   closure:
   - FastDDS: `librmw_fastrtps_cpp.so` + `libfastcdr`, `libfastdds`/`libfastrtps`.
   - CycloneDDS: `librmw_cyclonedds_cpp.so` + **`libddsc.so.0`** (missing this is
     the `dlopen error: libddsc.so.0` failure).
   Set `RMW_IMPLEMENTATION` to the one you bundled.

3. **The ament resource index.** rosidl typesupport discovery reads
   `share/ament_index/resource_index/{rosidl_typesupport_c,rmw_typesupport,
   packages,...}`. Bundle those directories and set `AMENT_PREFIX_PATH` to the
   bundle root.

## The recipe

`tool/bundle_ros_libs.sh <staging> [extra_pkg ...]` stages the closure (roots +
`ldd`) plus the ament index. `linux/CMakeLists.txt` runs it when
`-DRCLDART_BUNDLE_ROS_LIBS=ON`, copying everything into `<app>/lib`. At runtime:

```
LD_LIBRARY_PATH=<app>/lib
AMENT_PREFIX_PATH=<app>        # parent of lib, holds share/ament_index
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
```

## ✅ WORKS with CycloneDDS (verified end-to-end, no ROS installed)

A minimal **CycloneDDS** bundle runs fully standalone. Proven in a scrubbed
`env -i` shell (no ROS on the path): two separate rcldart processes did a
pub/sub round-trip — the subscriber **received 197 messages** — using only a
**76-lib / 7.3 MB** bundle.

Recipe (this is what `tool/bundle_ros_libs.sh` now produces by default):
- RMW = **rmw_cyclonedds_cpp** (FastDDS crashes in Jazzy's get_type_description
  service in a bare env; CycloneDDS does not).
- Bundle `librmw_cyclonedds_cpp.so` + **`libddsc.so.0`** (lives in the
  `lib/x86_64-linux-gnu/` arch subdir — easy to miss) + the introspection
  typesupport (`_c` and **`_cpp`**) for every package incl. `rmw_dds_common`,
  `action_msgs`, `unique_identifier_msgs` (used internally by node creation).
- Run ldd with the ROS lib dirs on `LD_LIBRARY_PATH` and recreate SONAME
  symlinks (both done by the script).
- At runtime set `LD_LIBRARY_PATH=<bundle>/lib`, `AMENT_PREFIX_PATH=<bundle>`,
  `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` (rpath already gives `$ORIGIN/lib`;
  the app can `setenv` these at the top of `main()`).

```bash
tool/bundle_ros_libs.sh <bundle>/lib sensor_msgs geometry_msgs   # RMW=cyclonedds default
# + copy /opt/ros/$ROS_DISTRO/share/ament_index into <bundle>/share/ament_index
```

## Status (verified via a scrubbed `env -i` shell — host has ROS installed)

- ✅ **The build bundles the `.so` automatically.** `flutter build linux` with
  `RCLDART_BUNDLE_ROS_LIBS=ON` copies the closure into `<app>/lib` (45+ libs:
  librcl, rmw_fastrtps, fastcdr, and each message package's typesupport). The
  `ldd` closure MUST run with `ROS_LIB_DIR` on `LD_LIBRARY_PATH` or it misses
  DT_NEEDED deps (e.g. `libtracetools.so`) — the script now does this.
- ✅ `rcl_init` + rmw/DDS load from the bundle in a clean, no-ROS env.
- ⛔ **Not yet turnkey:** with the *complete* lib set + ament index, `rcl_init`
  succeeds but **node creation crashes** in a bare FastDDS env with
  `eprosima::fastcdr::BadParamException: This member is not been selected` —
  from the `get_type_description` service every Jazzy node creates. This is the
  remaining blocker for a fully standalone FastDDS run; options being explored:
  bundle **CycloneDDS** instead (worked live against Nav2 — needs `libddsc.so.0`
  + its closure), disable the type-description service, or match the target
  stack's RMW.
- The app must also set `AMENT_PREFIX_PATH=<bundle_root>` +
  `RMW_IMPLEMENTATION` before `rcl_init` (via a launcher or an FFI `setenv` at
  the top of `main()`); rpath already gives `$ORIGIN/lib`.

**Bottom line:** copying the bundle to a no-ROS machine gets rcl + DDS loading
but not (yet) a working node — the `.so` packaging is automatic and done; the
final FastDDS node-init issue needs finishing on a real ROS-free host.
- Android: same idea, `.so` closure into `jniLibs/<abi>` + ament index as an
  asset; needs the ROS stack cross-compiled for arm64 (or the Termux/proot path
  in `ros2_android/`).
