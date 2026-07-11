#!/usr/bin/env bash
# build_ros2_apple.sh — cross-compile ROS 2 (Jazzy) for Apple and stage the
# SHARED .dylib closure where the rcldart podspecs embed it into the app bundle.
#
# Self-contained: uses rcldart's own toolchains (cmake/apple/) and source set
# (apple/ros2.jazzy.repos). Recipe distilled from ROS2-On-iOS (see
# docs/apple_ros2_architecture_spec.md). MUST run on macOS with Xcode, CMake
# >= 3.23, Python 3.11, vcs, colcon.
#
# KEY RULES (do not "fix"):
#   * SHARED libs — never BUILD_SHARED_LIBS=NO (rmw/typesupport use dlopen).
#   * rcl_logging_noop (drop spdlog); THIRDPARTY=FORCE (Fast-DDS vendors deps).
#   * Cross-compiling rosidl is TWO passes: build the generators for the HOST
#     first, then build for the TARGET reusing them (--merge-install shares the
#     install tree). Pass HOST_INSTALL=/path to a host build to enable pass 2.
#
# Usage:
#   PLATFORM=macOS_M1        tool/build_ros2_apple.sh   # Apple-silicon desktop
#   PLATFORM=iOS             tool/build_ros2_apple.sh   # device (arm64)
#   PLATFORM=iOS_Simulator_M1 tool/build_ros2_apple.sh  # simulator (arm64)
set -euo pipefail

PLATFORM="${PLATFORM:-macOS_M1}"
RMW="${RMW:-fastrtps}"   # fastrtps (default, iOS-proven) | cyclonedds (cross-platform)
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WS="${WS:-$HOME/ros2_apple_ws}"
TOOLCHAIN="$HERE/cmake/apple/${PLATFORM}.cmake"
CORE_REPOS="$HERE/apple/ros2.jazzy.repos"
case "$RMW" in
  fastrtps)   RMW_REPOS="$HERE/apple/rmw_fastrtps.repos";   RMW_IMPL=rmw_fastrtps_cpp ;;
  cyclonedds) RMW_REPOS="$HERE/apple/rmw_cyclonedds.repos"; RMW_IMPL=rmw_cyclonedds_cpp ;;
  *) echo "unknown RMW=$RMW (fastrtps|cyclonedds)"; exit 1 ;;
esac

case "$PLATFORM" in
  iOS|iOS_Simulator|iOS_Simulator_M1) IS_IOS=1; DEST="$HERE/ios/ros/$([ "$PLATFORM" = iOS ] && echo device || echo sim)" ;;
  macOS|macOS_M1)                     IS_IOS=0; DEST="$HERE/macos/ros" ;;
  *) echo "unknown PLATFORM=$PLATFORM"; exit 1 ;;
esac
[ -f "$TOOLCHAIN" ] || { echo "missing toolchain $TOOLCHAIN"; exit 1; }
command -v xcodebuild >/dev/null || { echo "Xcode required (macOS only)"; exit 1; }

echo "== 1. fetch Jazzy sources (core + $RMW rmw) =="
mkdir -p "$WS/src"
[ -d "$WS/src/ros2/rcl" ] || vcs import "$WS/src" < "$CORE_REPOS"
[ -d "$WS/src/ros2/rmw_$RMW" ] || [ -d "$WS/src/eclipse-cyclonedds" ] || vcs import "$WS/src" < "$RMW_REPOS"

echo "== 2. patches: drop spdlog + (Fast-DDS on iOS) if_arp =="
find "$WS/src" -type d -name rcl_logging_spdlog -exec touch {}/AMENT_IGNORE \;
if [ "$IS_IOS" = 1 ] && [ "$RMW" = fastrtps ]; then
  IPF="$(find "$WS/src" -path '*Fast-DDS*/src/cpp/utils/IPFinder.cpp' | head -1)"
  [ -n "$IPF" ] && sed -i.bak 's,<net/if_arp.h>,<net/ethernet.h>,g' "$IPF" && echo "  patched $IPF"
fi

COMMON_ARGS=(--merge-install --cmake-force-configure --cmake-args
  -DBUILD_TESTING=NO -DTHIRDPARTY=FORCE -DCOMPILE_TOOLS=NO
  -DBUILD_MEMORY_TOOLS=OFF -DRCL_LOGGING_IMPLEMENTATION=rcl_logging_noop
  -DCMAKE_BUILD_TYPE=Release)
# CycloneDDS: disable iceoryx shared-memory (not needed on mobile).
[ "$RMW" = cyclonedds ] && COMMON_ARGS+=(-DENABLE_SHM=OFF -DBUILD_IDLC=OFF)

if [ "$IS_IOS" = 1 ]; then
  # Pass 2 needs host-built rosidl generators; require HOST_INSTALL.
  : "${HOST_INSTALL:?iOS build needs HOST_INSTALL=/path/to/host/install (run a host macOS build first)}"
  echo "== 3. cross-build for $PLATFORM (reusing host generators) =="
  cd "$WS"
  AMENT_PREFIX_PATH="$HOST_INSTALL" \
  colcon build --install-base "$WS/install_$PLATFORM" \
    "${COMMON_ARGS[@]}" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN"
  INSTALL="$WS/install_$PLATFORM"
else
  echo "== 3. native macOS build =="
  cd "$WS"
  colcon build --install-base "$WS/install_$PLATFORM" \
    "${COMMON_ARGS[@]}" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN"
  INSTALL="$WS/install_$PLATFORM"
  echo "   (host generators for iOS pass 2 are here: $INSTALL)"
fi

echo "== 4. stage dylibs + ament index into $DEST =="
mkdir -p "$DEST/lib" "$DEST/share"
find "$INSTALL/lib" -maxdepth 1 -name '*.dylib' -exec cp -f {} "$DEST/lib/" \;
rsync -a "$INSTALL/share/" "$DEST/share/" 2>/dev/null || cp -rf "$INSTALL/share/." "$DEST/share/"

echo "== done ($PLATFORM, rmw=$RMW) =="
echo "  dylibs staged: $(ls -1 "$DEST/lib"/*.dylib 2>/dev/null | wc -l) → $DEST/lib"
echo "  ament index:   $DEST/share"
echo "  In the app, pass rmwImplementation: '$RMW_IMPL' to AppleRosBootstrap.prepare."
echo "Next: cd your app; pod install; flutter build ${IS_IOS:+ios}${IS_IOS:-macos}."
[ "$IS_IOS" = 0 ] && echo "For iOS, re-run with PLATFORM=iOS RMW=$RMW HOST_INSTALL=$INSTALL"
