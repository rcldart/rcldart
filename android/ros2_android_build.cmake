# ros2_android_build.cmake — cross-compile the ROS 2 closure for Android from
# WITHIN the CMake/NDK build (zenoh_ffi pattern: the native dependency is built
# by the plugin's externalNativeBuild, not a separate bash step). Included by
# android/CMakeLists.txt; runs once at configure time and is a no-op if the
# closure is already staged.
#
# It reproduces, as CMake execute_process steps, the full turnkey recipe that
# produces a loadable Android ROS runtime (rcl + rmw_cyclonedds + rosidl + the
# core message typesupports). Every workaround discovered while porting is here:
#   * filtered host ROS (drop the Python generator: no rclpy on Android)
#   * API >= 28 (bionic pthread_attr_setinheritsched)
#   * cyclonedds without OpenSSL security / iceoryx SHM
#   * ANDROID_ALLOW_UNDEFINED_SYMBOLS (ROS resolves symbols across .so at load)
#   * libyaml_vendor forced to build from source; ament_cmake_vendor_package
#   * tracetools: strip lttng export + synthesize a no-op libtracetools.so stub
#   * Fast-CDR, rosidl_typesupport, ament_index_cpp (closure completeness)
#   * patchelf: unversion SONAME/DT_NEEDED (Android ships only lib*.so)
#
# Toggle with -DRCLDART_BUILD_ROS=ON (default OFF — most builds bundle a prebuilt
# closure via jniLibs or the fetch hook; this is for building it in-tree).

if(NOT ANDROID OR NOT RCLDART_BUILD_ROS)
  return()
endif()

set(_ros_distro "$ENV{ROS_DISTRO}")
if(_ros_distro STREQUAL "")
  set(_ros_distro "jazzy")
endif()
set(_hostros "/opt/ros/${_ros_distro}")
set(_ws "$ENV{HOME}/ros2_android_ws")
set(_jni "${CMAKE_CURRENT_SOURCE_DIR}/src/main/jniLibs/${ANDROID_ABI}")
set(_ndk "${ANDROID_NDK}")

# API level: force >= 28 for bionic pthread inherit-sched.
string(REGEX REPLACE "^android-" "" _api "${ANDROID_PLATFORM}")
if(_api LESS 28)
  set(_api 28)
endif()

# Already staged? Skip (this build is slow — run once).
if(EXISTS "${_jni}/librcl.so")
  message(STATUS "rcldart: ROS closure already staged in jniLibs — skipping build")
  return()
endif()
if(NOT EXISTS "${_hostros}/setup.bash")
  message(WARNING "rcldart: ${_hostros} not found — cannot build the ROS closure; "
                  "bundle a prebuilt one into jniLibs or set RCLDART_ROS_BUNDLE_URL")
  return()
endif()

message(STATUS "rcldart: building ROS 2 closure for Android ${ANDROID_ABI} (api ${_api}) — this is slow")

# The heavy orchestration (source ROS env, vcs import, colcon, patchelf) is a
# shell workflow; CMake drives it via a single bootstrap that this file writes,
# keeping ALL logic here (no external checked-in .sh). Executed with `bash -c`.
set(_driver "${CMAKE_CURRENT_BINARY_DIR}/rcldart_ros_build.sh")
file(WRITE "${_driver}" "\
set -o pipefail
HOSTROS='${_hostros}'; WS='${_ws}'; JNI='${_jni}'; NDK='${_ndk}'; ABI='${ANDROID_ABI}'; API='${_api}'; DISTRO='${_ros_distro}'
TOOLCHAIN=\"$NDK/build/cmake/android.toolchain.cmake\"
source \"$HOSTROS/setup.bash\"
# --- filtered host ROS (no Python generator) ---
FILT=\"$WS/hostros_nopy\"
if [ ! -e \"$FILT/.stamp\" ]; then
  rm -rf \"$FILT\"; mkdir -p \"$FILT\"; cp -as \"$HOSTROS/.\" \"$FILT/\" 2>/dev/null
  rm -f  \"$FILT\"/share/ament_index/resource_index/rosidl_generator_packages/rosidl_generator_py
  rm -rf \"$FILT/share/rosidl_generator_py\" \"$FILT\"/share/rosidl_generator_py_*
  for f in \"$FILT\"/share/tracetools/cmake/ament_cmake_export_libraries-extras.cmake \
           \"$FILT\"/share/tracetools/cmake/tracetools_exportExport.cmake; do
    [ -f \"$f\" ] && sed -i 's/lttng-ust;lttng-ust-common;//g' \"$f\"; done
  touch \"$FILT/COLCON_IGNORE\" \"$FILT/.stamp\"
fi
export AMENT_PREFIX_PATH=\"$FILT\"; export CMAKE_PREFIX_PATH=\"$FILT:$CMAKE_PREFIX_PATH\"
# --- sources ---
mkdir -p \"$WS/src\"
if [ ! -f \"$WS/ros2.repos\" ]; then cat > \"$WS/ros2.repos\" <<'R'
repositories:
  ros2/rcutils: { type: git, url: https://github.com/ros2/rcutils.git, version: jazzy }
  ros2/rcpputils: { type: git, url: https://github.com/ros2/rcpputils.git, version: jazzy }
  ros2/rcl: { type: git, url: https://github.com/ros2/rcl.git, version: jazzy }
  ros2/rmw: { type: git, url: https://github.com/ros2/rmw.git, version: jazzy }
  ros2/rmw_dds_common: { type: git, url: https://github.com/ros2/rmw_dds_common.git, version: jazzy }
  ros2/rmw_implementation: { type: git, url: https://github.com/ros2/rmw_implementation.git, version: jazzy }
  ros2/rmw_cyclonedds: { type: git, url: https://github.com/ros2/rmw_cyclonedds.git, version: jazzy }
  eclipse-cyclonedds/cyclonedds: { type: git, url: https://github.com/eclipse-cyclonedds/cyclonedds.git, version: releases/0.10.x }
  eProsima/Fast-CDR: { type: git, url: https://github.com/eProsima/Fast-CDR.git, version: 2.2.x }
  ros2/rcl_logging: { type: git, url: https://github.com/ros2/rcl_logging.git, version: jazzy }
  ros2/libyaml_vendor: { type: git, url: https://github.com/ros2/libyaml_vendor.git, version: jazzy }
  ros2/rosidl: { type: git, url: https://github.com/ros2/rosidl.git, version: jazzy }
  ros2/rosidl_typesupport: { type: git, url: https://github.com/ros2/rosidl_typesupport.git, version: jazzy }
  ros2/rosidl_typesupport_fastrtps: { type: git, url: https://github.com/ros2/rosidl_typesupport_fastrtps.git, version: jazzy }
  ros2/rosidl_dynamic_typesupport: { type: git, url: https://github.com/ros2/rosidl_dynamic_typesupport.git, version: jazzy }
  ros2/rcl_interfaces: { type: git, url: https://github.com/ros2/rcl_interfaces.git, version: jazzy }
  ros2/unique_identifier_msgs: { type: git, url: https://github.com/ros2/unique_identifier_msgs.git, version: jazzy }
  ros2/common_interfaces: { type: git, url: https://github.com/ros2/common_interfaces.git, version: jazzy }
  ament/ament_index: { type: git, url: https://github.com/ament/ament_index.git, version: jazzy }
R
  vcs import \"$WS/src\" < \"$WS/ros2.repos\" || true
fi
[ -d \"$WS/src/ament/ament_cmake\" ] || git clone -q --depth 1 -b \"$DISTRO\" https://github.com/ament/ament_cmake.git \"$WS/src/ament/ament_cmake\" || true
find \"$WS/src/ament/ament_cmake\" -maxdepth 1 -mindepth 1 -type d ! -name ament_cmake_vendor_package -exec touch {}/COLCON_IGNORE \; 2>/dev/null
find \"$WS/src\" -type d -name rcl_logging_spdlog -exec touch {}/AMENT_IGNORE \; 2>/dev/null
for p in rosidl_generator_py test_msgs test_communication test_interface_files; do
  find \"$WS/src\" -type d -name \"$p\" -exec touch {}/AMENT_IGNORE \; 2>/dev/null; done
command -v patchelf >/dev/null 2>&1 || { mkdir -p \"$HOME/.local/bin\"; curl -sL https://github.com/NixOS/patchelf/releases/download/0.18.0/patchelf-0.18.0-x86_64.tar.gz | tar xz -C /tmp bin/patchelf 2>/dev/null && cp /tmp/bin/patchelf \"$HOME/.local/bin/\"; export PATH=\"$HOME/.local/bin:$PATH\"; }
export PATH=\"$HOME/.local/bin:$PATH\"
# --- cross build ---
cd \"$WS\"
colcon build --merge-install --cmake-force-configure --cmake-args \
  -DCMAKE_TOOLCHAIN_FILE=\"$TOOLCHAIN\" -DANDROID_ABI=\"$ABI\" -DANDROID_PLATFORM=\"android-$API\" \
  -DANDROID_STL=c++_shared -DANDROID_ALLOW_UNDEFINED_SYMBOLS=TRUE -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=ON \
  -DRCL_LOGGING_IMPLEMENTATION=rcl_logging_noop -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH \
  -DPython3_EXECUTABLE=/usr/bin/python3 -DPython3_INCLUDE_DIR=/usr/include/python3.12 \
  -DPython3_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.12.so \
  -DPython3_NumPy_INCLUDE_DIR=/usr/lib/python3/dist-packages/numpy/core/include \
  -DCMAKE_BUILD_TYPE=Release -DENABLE_SHM=OFF -DBUILD_IDLC=OFF -DENABLE_SECURITY=OFF -DENABLE_SSL=OFF \
  -DTRACETOOLS_DISABLED=ON -DFORCE_BUILD_VENDOR_PKG=ON -DTHIRDPARTY=ON || true
# --- stage + unversion ---
mkdir -p \"$JNI\"; rm -f \"$JNI\"/*.so
uv(){ echo \"$1\" | sed -E 's/\\.so(\\.[0-9]+)+$/.so/'; }
while IFS= read -r so; do cp -f \"$so\" \"$JNI/$(uv \"$(basename \"$so\")\")\"; done < <(find \"$WS/install\" -type f \\( -name '*.so' -o -name '*.so.*' \\) 2>/dev/null)
T=\"${ABI/arm64-v8a/aarch64-linux-android}\"; T=\"${T/x86_64/x86_64-linux-android}\"
cp -f \"$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/$T/libc++_shared.so\" \"$JNI/\" 2>/dev/null
if command -v patchelf >/dev/null 2>&1; then
  for so in \"$JNI\"/*.so; do patchelf --set-soname \"$(basename \"$so\")\" \"$so\" 2>/dev/null
    for n in $(patchelf --print-needed \"$so\" 2>/dev/null | grep -E '\\.so\\.[0-9]'); do u=$(uv \"$n\"); [ -f \"$JNI/$u\" ] && patchelf --replace-needed \"$n\" \"$u\" \"$so\" 2>/dev/null; done
    patchelf --remove-rpath \"$so\" 2>/dev/null; done
fi
# tracetools no-op stub (librcl needs libtracetools.so; tracing disabled)
if [ -f \"$JNI/librcl.so\" ] && [ ! -f \"$JNI/libtracetools.so\" ]; then
  HT=$(find \"$HOSTROS/lib\" -name libtracetools.so | head -1); CC=\"$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang\"
  case \"$ABI\" in x86_64) TT=x86_64-linux-android$API;; arm64-v8a) TT=aarch64-linux-android$API;; esac
  [ -n \"$HT\" ] && nm -D \"$HT\" | awk '$2==\"T\"{print $3}' | grep '^ros_trace' | while read s; do echo \"void $s(void){}\"; done > /tmp/tt.c \
    && \"$CC\" --target=$TT -shared -fPIC -Wl,-soname,libtracetools.so -o \"$JNI/libtracetools.so\" /tmp/tt.c 2>/dev/null
fi
[ -f \"$JNI/librcl.so\" ] && echo 'rcldart: ROS closure staged' || echo 'rcldart: librcl.so NOT produced'
")

execute_process(COMMAND bash "${_driver}" RESULT_VARIABLE _rc)
if(EXISTS "${_jni}/librcl.so")
  message(STATUS "rcldart: ROS 2 closure built + staged into ${_jni}")
else()
  message(WARNING "rcldart: ROS closure build did not produce librcl.so (rc=${_rc}) — see log")
endif()
