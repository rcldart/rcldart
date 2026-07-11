#!/usr/bin/env bash
# build_ros2_android.sh — cross-compile a MINIMAL ROS 2 (rcl + rmw_cyclonedds +
# rosidl + core deps) for Android and stage the .so closure into the plugin's
# jniLibs so it ships inside the APK. Applies the zenoh_ffi insight (drive the
# cross-compiler from the NDK toolchain), but for ROS's colcon workspace instead
# of a single cargo lib — so it is a real TWO-PASS build:
#
#   Pass 1 (host)  : the rosidl Python generators + type-support come from the
#                    host ROS at /opt/ros/$ROS_DISTRO (arch-independent codegen).
#   Pass 2 (target): colcon cross-builds the C/C++ runtime libs with the NDK
#                    CMake toolchain, finding the host generators on AMENT path.
#
# HONEST: cross-compiling ROS 2 for Android is hard — several vendor packages
# (Fast-DDS, cyclonedds, foonathan) need per-package fixes. This drives the build
# as far as it can and stages whatever built; read the log and iterate.
#
# Usage:
#   ANDROID_NDK=~/Android/Sdk/ndk/<ver> ABI=x86_64 API=24 tool/build_ros2_android.sh
# NOTE: no `set -u` — ROS setup.bash references unbound vars and would abort.
set -o pipefail

ANDROID_NDK="${ANDROID_NDK:?set ANDROID_NDK (e.g. ~/Android/Sdk/ndk/28.2.13676358)}"
ABI="${ABI:-arm64-v8a}"
API="${API:-24}"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WS="${WS:-$HOME/ros2_android_ws}"
JNILIBS="$HERE/android/src/main/jniLibs/$ABI"
TOOLCHAIN="$ANDROID_NDK/build/cmake/android.toolchain.cmake"
[ -f "$TOOLCHAIN" ] || { echo "NDK toolchain not found: $TOOLCHAIN"; exit 1; }

# Host-OS aware: this build runs on Linux OR macOS (the NDK is cross-platform).
case "$(uname -s)" in
  Linux)  HOST_TAG=linux-x86_64 ;;
  Darwin) HOST_TAG="$([ -d "$ANDROID_NDK/toolchains/llvm/prebuilt/darwin-arm64" ] && echo darwin-arm64 || echo darwin-x86_64)" ;;
  *) HOST_TAG=linux-x86_64 ;;
esac
NDK_BIN="$ANDROID_NDK/toolchains/llvm/prebuilt/$HOST_TAG"
# Python dev paths via sysconfig — portable across Linux (/usr) and macOS
# (Homebrew / conda / RoboStack). libpython is .so on Linux, .dylib on macOS.
PY_EXE="$(command -v python3)"
PY_INC="$("$PY_EXE" -c 'import sysconfig;print(sysconfig.get_path("include"))' 2>/dev/null)"
PY_LIB="$("$PY_EXE" -c 'import sysconfig,os;print(os.path.join(sysconfig.get_config_var("LIBDIR") or "",sysconfig.get_config_var("LDLIBRARY") or ""))' 2>/dev/null)"
PY_NUMPY="$("$PY_EXE" -c 'import numpy;print(numpy.get_include())' 2>/dev/null)"

# Host ROS supplies the (arch-independent) rosidl generators + ament_cmake for
# codegen. But its Python message generator (rosidl_generator_py) would try to
# compile a Python C extension for Android — which has no rclpy and fails. So we
# source a FILTERED view of the host ROS with the py generator removed, so target
# message packages only run the C generators (incl. introspection, for ros_cdr).
# On macOS the ROS install isn't at /opt/ros — source your ROS (RoboStack conda
# env / source build) and set HOSTROS to its prefix, or export it directly.
# Auto-provision the host ROS (codegen generators) when none is installed — the
# zenoh_ffi-style "no pre-installed dependency" path. Downloads a self-contained
# micromamba and creates a RoboStack (conda-forge) env, so it works IDENTICALLY
# on Linux and macOS with NO system ROS at all. Opt out with AUTO_HOSTROS=0
# (then point HOSTROS at your own ROS prefix).
maybe_bootstrap_hostros() {
  [ -d "$HOSTROS" ] && return 0
  [ "${AUTO_HOSTROS:-1}" = "0" ] && { echo "warning: $HOSTROS not found and AUTO_HOSTROS=0"; return 0; }
  echo "== host ROS not found at $HOSTROS — auto-provisioning via RoboStack =="
  local MM_ROOT="$WS/.micromamba" MM
  MM="$MM_ROOT/bin/micromamba"
  if [ ! -x "$MM" ]; then
    mkdir -p "$MM_ROOT"
    local url
    case "$(uname -s)-$(uname -m)" in
      Linux-x86_64)  url="https://micro.mamba.pm/api/micromamba/linux-64/latest" ;;
      Linux-aarch64) url="https://micro.mamba.pm/api/micromamba/linux-aarch64/latest" ;;
      Darwin-arm64)  url="https://micro.mamba.pm/api/micromamba/osx-arm64/latest" ;;
      Darwin-x86_64) url="https://micro.mamba.pm/api/micromamba/osx-64/latest" ;;
      *) echo "  unsupported host for auto-bootstrap — set HOSTROS manually"; return 1 ;;
    esac
    echo "  downloading micromamba…"
    curl -Ls "$url" | tar -xj -C "$MM_ROOT" bin/micromamba || return 1
  fi
  local envdir="$WS/hostros_env"
  if [ ! -e "$envdir/.stamp" ]; then
    echo "  creating RoboStack env (ros-$ROS_DISTRO-ros-base + generators)…"
    "$MM" create -y -p "$envdir" -c conda-forge -c "robostack-$ROS_DISTRO" \
      "ros-$ROS_DISTRO-ros-base" "ros-$ROS_DISTRO-rosidl-default-generators" \
      || { echo "  RoboStack env creation failed"; return 1; }
    touch "$envdir/.stamp"
  fi
  HOSTROS="$envdir"
  echo "  using auto-provisioned HOSTROS=$HOSTROS"
}

HOSTROS="${HOSTROS:-/opt/ros/$ROS_DISTRO}"
maybe_bootstrap_hostros
if [ -d "$HOSTROS" ]; then
  # shellcheck disable=SC1090
  [ -f "$HOSTROS/setup.bash" ] && source "$HOSTROS/setup.bash"
  FILT="$WS/hostros_nopy"
  if [ ! -e "$FILT/.stamp" ] || [ "$HOSTROS/setup.bash" -nt "$FILT/.stamp" ]; then
    rm -rf "$FILT"; mkdir -p "$FILT"
    cp -as "$HOSTROS/." "$FILT/" 2>/dev/null
    # THE key one: rosidl_generate_interfaces reads the `rosidl_generator_packages`
    # ament resource and invokes every generator listed. Drop py from that list so
    # message packages never emit/compile the Python C extension.
    rm -f  "$FILT"/share/ament_index/resource_index/rosidl_generator_packages/rosidl_generator_py
    rm -rf "$FILT/share/rosidl_generator_py" \
           "$FILT"/share/rosidl_generator_py_* \
           "$FILT"/share/ament_index/resource_index/packages/rosidl_generator_py 2>/dev/null
    # It lives inside $WS for convenience — stop colcon scanning it as sources
    # (would be duplicate package names alongside src/).
    # tracetools exports lttng-ust as link libs (host has it, Android doesn't).
    # Strip just the lttng entries from its export cmake, keeping the rest (dl).
    for f in "$FILT"/share/tracetools/cmake/ament_cmake_export_libraries-extras.cmake \
             "$FILT"/share/tracetools/cmake/tracetools_exportExport.cmake; do
      [ -f "$f" ] && sed -i 's/lttng-ust;lttng-ust-common;//g' "$f"
    done
    touch "$FILT/COLCON_IGNORE" "$FILT/.stamp"
  fi
  # Discover packages/generators from the filtered tree (no py); colcon prepends
  # the workspace's own installs as it builds.
  export AMENT_PREFIX_PATH="$FILT"
  export CMAKE_PREFIX_PATH="$FILT${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
else
  echo "warning: $HOSTROS not found — codegen may fail"
fi

echo "== 1. fetch a minimal ROS 2 source set =="
mkdir -p "$WS/src"
if [ ! -f "$WS/ros2.repos" ]; then
  cat > "$WS/ros2.repos" <<'REPOS'
repositories:
  ros2/rcutils:        { type: git, url: https://github.com/ros2/rcutils.git,        version: jazzy }
  ros2/rcpputils:      { type: git, url: https://github.com/ros2/rcpputils.git,      version: jazzy }
  ros2/rcl:            { type: git, url: https://github.com/ros2/rcl.git,            version: jazzy }
  ros2/rmw:            { type: git, url: https://github.com/ros2/rmw.git,            version: jazzy }
  ros2/rmw_dds_common: { type: git, url: https://github.com/ros2/rmw_dds_common.git, version: jazzy }
  ros2/rmw_implementation: { type: git, url: https://github.com/ros2/rmw_implementation.git, version: jazzy }
  ros2/rmw_cyclonedds: { type: git, url: https://github.com/ros2/rmw_cyclonedds.git, version: jazzy }
  eclipse-cyclonedds/cyclonedds: { type: git, url: https://github.com/eclipse-cyclonedds/cyclonedds.git, version: releases/0.10.x }
  eProsima/Fast-CDR: { type: git, url: https://github.com/eProsima/Fast-CDR.git, version: 2.2.x }
  ros2/rcl_logging:    { type: git, url: https://github.com/ros2/rcl_logging.git,    version: jazzy }
  ros2/libyaml_vendor: { type: git, url: https://github.com/ros2/libyaml_vendor.git, version: jazzy }
  ros2/rosidl:         { type: git, url: https://github.com/ros2/rosidl.git,         version: jazzy }
  ros2/rosidl_dynamic_typesupport: { type: git, url: https://github.com/ros2/rosidl_dynamic_typesupport.git, version: jazzy }
  ros2/rcl_interfaces: { type: git, url: https://github.com/ros2/rcl_interfaces.git, version: jazzy }
  ros2/unique_identifier_msgs: { type: git, url: https://github.com/ros2/unique_identifier_msgs.git, version: jazzy }
  ros2/common_interfaces: { type: git, url: https://github.com/ros2/common_interfaces.git, version: jazzy }
REPOS
  vcs import "$WS/src" < "$WS/ros2.repos" || true
fi

# Optional: the rmw_zenoh bridge (WITH_ZENOH=1) — adds rmw_zenoh_cpp + zenoh-c to
# the closure so the app can use RMW_IMPLEMENTATION=rmw_zenoh_cpp and connect to a
# Zenoh router (NAT-friendly mobile path). zenoh-c is built from source via cargo
# (the zenoh_ffi pattern), so this needs Rust + the Android target.
if [ "${WITH_ZENOH:-0}" = 1 ]; then
  if [ ! -d "$WS/src/ros2/rmw_zenoh" ]; then
    echo "repositories: {ros2/rmw_zenoh: {type: git, url: https://github.com/ros2/rmw_zenoh.git, version: $ROS_DISTRO}}" \
      | vcs import "$WS/src" 2>/dev/null || true
  fi
  command -v rustup >/dev/null 2>&1 && rustup target add "${TRIPLE}" 2>/dev/null || \
    echo "  NOTE: install Rust + 'rustup target add ${TRIPLE}' for zenoh-c"
fi

# Drop the spdlog logging backend (extra dep) — use noop.
find "$WS/src" -type d -name rcl_logging_spdlog -exec touch {}/AMENT_IGNORE \; 2>/dev/null
# Android has no rclpy — skip the Python message bindings (rosidl_generator_py),
# which are the only thing requiring Python3 Development for the TARGET. The C
# generators/typesupport (rosidl_generator_c, rosidl_typesupport_introspection_c
# — needed by ros_cdr) run with the host interpreter only.
for p in rosidl_generator_py rosidl_generator_tests rosidl_typesupport_introspection_tests \
         test_msgs test_communication test_interface_files; do
  find "$WS/src" -type d -name "$p" -exec touch {}/AMENT_IGNORE \; 2>/dev/null
done

# libyaml_vendor needs ament_cmake_vendor_package (not always in a slim host ROS).
# Clone the ament_cmake repo but keep ONLY that one package (the rest come from host).
if [ ! -d "$WS/src/ament/ament_cmake" ]; then
  git clone -q --depth 1 -b "$ROS_DISTRO" https://github.com/ament/ament_cmake.git \
      "$WS/src/ament/ament_cmake" 2>/dev/null || true
fi
if [ -d "$WS/src/ament/ament_cmake" ]; then
  find "$WS/src/ament/ament_cmake" -maxdepth 1 -mindepth 1 -type d \
       ! -name ament_cmake_vendor_package -exec touch {}/COLCON_IGNORE \; 2>/dev/null
fi

# patchelf unversions the .so closure for Android (step 3). It edits ELF files
# so it works on macOS too (brew) — get it if missing.
if ! command -v patchelf >/dev/null 2>&1; then
  echo "== fetching patchelf (needed to unversion the closure) =="
  if [ "$(uname -s)" = Darwin ]; then
    command -v brew >/dev/null 2>&1 && brew install patchelf >/dev/null 2>&1 \
      || echo "  install patchelf manually: brew install patchelf"
  else
    mkdir -p "$HOME/.local/bin"
    curl -sL https://github.com/NixOS/patchelf/releases/download/0.18.0/patchelf-0.18.0-x86_64.tar.gz \
      | tar xz -C /tmp bin/patchelf 2>/dev/null && cp /tmp/bin/patchelf "$HOME/.local/bin/patchelf"
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi

echo "== 2. cross-compile with colcon + NDK toolchain ($ABI, API $API) =="
cd "$WS"
colcon build \
  --merge-install \
  --cmake-force-configure \
  --event-handlers console_direct+ \
  --cmake-args \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM="android-$API" \
    -DANDROID_STL=c++_shared \
    -DANDROID_ALLOW_UNDEFINED_SYMBOLS=TRUE \
    -DBUILD_TESTING=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DRCL_LOGGING_IMPLEMENTATION=rcl_logging_noop \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH \
    -DPython3_EXECUTABLE="$PY_EXE" \
    -DPython3_INCLUDE_DIR="$PY_INC" \
    -DPython3_LIBRARY="$PY_LIB" \
    -DPython3_NumPy_INCLUDE_DIR="$PY_NUMPY" \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_SHM=OFF -DBUILD_IDLC=OFF \
    -DENABLE_SECURITY=OFF -DENABLE_SSL=OFF \
    -DTRACETOOLS_DISABLED=ON \
    -DFORCE_BUILD_VENDOR_PKG=ON \
    -DTHIRDPARTY=ON
RC=$?

echo "== 3. stage + unversion the .so closure into jniLibs =="
mkdir -p "$JNILIBS"
rm -f "$JNILIBS"/*.so
n=0
# Collect every real shared object (install/lib + vendor opt dirs), copied under
# an UNVERSIONED lib*.so name (Android ships no versioned names / symlinks).
unversion() { echo "$1" | sed -E 's/\.so(\.[0-9]+)+$/.so/'; }
while IFS= read -r so; do
  [ -e "$so" ] || continue
  cp -f "$so" "$JNILIBS/$(unversion "$(basename "$so")")" && n=$((n+1))
done < <(find "$WS/install" -type f \( -name '*.so' -o -name '*.so.*' \) 2>/dev/null)
# NDK c++_shared runtime (ANDROID_STL=c++_shared).
TRIPLE_LIB="${ABI/arm64-v8a/aarch64-linux-android}"; TRIPLE_LIB="${TRIPLE_LIB/x86_64/x86_64-linux-android}"
CXX_SO="$NDK_BIN/sysroot/usr/lib/$TRIPLE_LIB/libc++_shared.so"
[ -f "$CXX_SO" ] && cp -f "$CXX_SO" "$JNILIBS/" && n=$((n+1))

# patchelf pass: unversion SONAME, repoint versioned DT_NEEDED to the unversioned
# files present here, drop rpath — so Android's linker resolves the flat dir.
if command -v patchelf >/dev/null 2>&1; then
  for so in "$JNILIBS"/*.so; do
    patchelf --set-soname "$(basename "$so")" "$so" 2>/dev/null
    for need in $(patchelf --print-needed "$so" 2>/dev/null | grep -E '\.so\.[0-9]'); do
      unv="$(unversion "$need")"
      [ -f "$JNILIBS/$unv" ] && patchelf --replace-needed "$need" "$unv" "$so" 2>/dev/null
    done
    patchelf --remove-rpath "$so" 2>/dev/null
  done
  echo "  patchelf: unversioned $(ls "$JNILIBS"/*.so | wc -l) libs"
else
  echo "  WARNING: patchelf unavailable — versioned SONAMEs may fail to load on device"
fi

# librcl links libtracetools.so (ros_trace_* tracepoints). With tracing disabled
# we don't build the full tracetools package (it pulls more ament build deps);
# instead synthesize a no-op stub exporting every ros_trace_* symbol the host
# tracetools declares, so librcl's DT_NEEDED + symbol refs resolve on device.
if [ -f "$JNILIBS/librcl.so" ] && [ ! -f "$JNILIBS/libtracetools.so" ]; then
  HOST_TT="$(find "$HOSTROS/lib" -name libtracetools.so 2>/dev/null | head -1)"
  CLANG="$NDK_BIN/bin/clang"
  case "$ABI" in
    x86_64)    TT_TARGET="x86_64-linux-android$API" ;;
    arm64-v8a) TT_TARGET="aarch64-linux-android$API" ;;
    *)         TT_TARGET="" ;;
  esac
  if [ -n "$HOST_TT" ] && [ -x "$CLANG" ] && [ -n "$TT_TARGET" ]; then
    { echo "// auto-generated no-op tracetools stub (tracing disabled on Android)";
      nm -D "$HOST_TT" 2>/dev/null | awk '$2=="T"{print $3}' | grep '^ros_trace' \
        | while read -r s; do echo "void $s(void){}"; done; } > /tmp/rcldart_tt_stub.c
    "$CLANG" --target="$TT_TARGET" -shared -fPIC -Wl,-soname,libtracetools.so \
      -o "$JNILIBS/libtracetools.so" /tmp/rcldart_tt_stub.c 2>/dev/null \
      && echo "  synthesized libtracetools.so stub ($(grep -c '^void' /tmp/rcldart_tt_stub.c) symbols)"
  fi
fi

echo "staged $n libs → $JNILIBS"
if [ -f "$JNILIBS/librcl.so" ]; then
  echo "SUCCESS: librcl.so produced + closure staged (run tool/package_ros_bundle.sh to make a release artifact)"
else
  echo "librcl.so NOT produced (colcon rc=$RC) — inspect the log"
fi
exit $RC
