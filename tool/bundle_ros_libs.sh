#!/usr/bin/env bash
# bundle_ros_libs.sh — stage the closure of ROS 2 / DDS / rosidl shared
# libraries that rcldart dlopen()s at runtime, so the app can run on a Linux (or,
# later, Android) device WITHOUT ROS installed.
#
# rcldart does not link rcl/rmw at build time; it loads them by name via
# `dynamiclibraryloader` (DynamicLibrary.open('lib<name>.so')). This script
# resolves the transitive .so closure of those "root" libraries (plus each
# interface package's typesupport/generator_c libs) and copies them into a
# staging directory that the Flutter Linux build then bundles into
# <bundle>/lib/.
#
# Usage:
#   tool/bundle_ros_libs.sh <staging_dir> [extra_package ...]
#
# Env:
#   ROS_LIB_DIR   directory holding the ROS 2 .so files (default: $AMENT... or
#                 /opt/ros/$ROS_DISTRO/lib)
#
# The rmw implementation (librmw_fastrtps_c.so) and interface-package typesupport
# libs are dlopen()d at runtime and are NOT DT_NEEDED of librcl.so, so they are
# seeded explicitly below.
set -euo pipefail

STAGING="${1:?usage: bundle_ros_libs.sh <staging_dir> [extra_package ...]}"
shift || true
EXTRA_PACKAGES=("$@")

ROS_LIB_DIR="${ROS_LIB_DIR:-/opt/ros/${ROS_DISTRO:-jazzy}/lib}"
if [ ! -d "$ROS_LIB_DIR" ]; then
  echo "ERROR: ROS_LIB_DIR '$ROS_LIB_DIR' not found; set ROS_LIB_DIR or source ROS." >&2
  exit 1
fi

mkdir -p "$STAGING"

# Some distros put the DDS core (libddsc for CycloneDDS) in an arch subdir.
LIB_DIRS=("$ROS_LIB_DIR" "$ROS_LIB_DIR/x86_64-linux-gnu")
LDPATH="$(IFS=:; echo "${LIB_DIRS[*]}")"

# Target RMW to bundle. CycloneDDS is the default: it runs standalone in a
# no-ROS env, whereas bare FastDDS crashes in Jazzy's get_type_description
# service. Override with RMW=rmw_fastrtps_cpp.
RMW="${RMW:-rmw_cyclonedds_cpp}"

# Root libraries loaded by name at runtime (see lib/src/*.dart + msgs).
ROOTS=(
  librcl.so
  librmw.so
  librmw_implementation.so
  librosidl_runtime_c.so
  librosidl_typesupport_c.so
  librosidl_typesupport_cpp.so
  librosidl_typesupport_introspection_c.so   # CycloneDDS uses introspection TS
  librosidl_typesupport_introspection_cpp.so
  librcl_logging_spdlog.so                    # rcl_node_init sets up logging
  librcl_logging_interface.so
  librcl_yaml_param_parser.so
)
if [ "$RMW" = "rmw_cyclonedds_cpp" ]; then
  ROOTS+=(librmw_cyclonedds_cpp.so libddsc.so libddsc.so.0 libcycloneddsidl.so)
else
  ROOTS+=(librmw_fastrtps_c.so librmw_fastrtps_cpp.so librmw_fastrtps_shared_cpp.so
          librosidl_typesupport_fastrtps_c.so librosidl_typesupport_fastrtps_cpp.so)
fi

# Packages rcl_node_init itself needs (rosout Log, get_type_description service
# on Jazzy+, parameters) plus any user interface packages. Each ships its
# generic + rmw-specific + introspection typesupport and generator_c.
# rmw_dds_common is used internally by rmw_cyclonedds for the participant graph
# (via introspection_cpp typesupport); action_msgs/unique_identifier_msgs cover
# actions.
PACKAGES=(std_msgs rcl_interfaces type_description_interfaces service_msgs
          builtin_interfaces rmw_dds_common action_msgs
          unique_identifier_msgs "${EXTRA_PACKAGES[@]}")
for pkg in "${PACKAGES[@]}"; do
  ROOTS+=("lib${pkg}__rosidl_typesupport_c.so"
          "lib${pkg}__rosidl_typesupport_cpp.so"
          "lib${pkg}__rosidl_typesupport_introspection_c.so"
          "lib${pkg}__rosidl_typesupport_introspection_cpp.so"
          "lib${pkg}__rosidl_generator_c.so")
  [ "$RMW" != "rmw_cyclonedds_cpp" ] &&
    ROOTS+=("lib${pkg}__rosidl_typesupport_fastrtps_c.so"
            "lib${pkg}__rosidl_typesupport_fastrtps_cpp.so")
done

# Compute the transitive closure with ldd, seeded by the roots.
declare -A SEEN=()
queue=()
for r in "${ROOTS[@]}"; do
  for d in "${LIB_DIRS[@]}"; do
    [ -e "$d/$r" ] && { queue+=("$d/$r"); break; }
  done
done

while [ ${#queue[@]} -gt 0 ]; do
  lib="${queue[0]}"; queue=("${queue[@]:1}")
  real="$(readlink -f "$lib")"
  [ -n "${SEEN[$real]:-}" ] && continue
  SEEN[$real]=1
  # Enqueue ROS/DDS dependencies. ldd is run with the ROS lib dirs (incl. the
  # arch subdir that holds libddsc) on the library path so DT_NEEDED entries
  # (libtracetools, libddsc, …) resolve even when ROS is not sourced —
  # otherwise the closure is incomplete.
  while read -r dep; do
    case "$dep" in
      "$ROS_LIB_DIR"/*|*fastrtps*|*fastcdr*|*ddsc*|*cyclonedds*|*/opt/ros/*)
        [ -e "$dep" ] && queue+=("$dep") ;;
    esac
  done < <(LD_LIBRARY_PATH="$LDPATH" ldd "$real" 2>/dev/null \
             | awk '{print $3}' | grep -E '\.so')
done

count=0
for real in "${!SEEN[@]}"; do
  base="$(basename "$real")"
  cp -u "$real" "$STAGING/$base" && count=$((count+1))
  # Recreate the SONAME symlink (e.g. libfastrtps.so.2.14 -> ...2.14.6) so the
  # dynamic linker's DT_NEEDED lookups resolve — cp of the resolved file alone
  # leaves only the fully-versioned name.
  soname="$(objdump -p "$real" 2>/dev/null | awk '/SONAME/{print $2}')"
  if [ -n "$soname" ] && [ "$soname" != "$base" ]; then
    ln -sf "$base" "$STAGING/$soname"
  fi
done

# Stage the ament resource index too. rosidl_typesupport_c discovers the
# rmw-specific typesupport implementation through this index; without it,
# rcl_node_init fails with "Type support not from this implementation".
# Point AMENT_PREFIX_PATH at the *parent* of $STAGING at runtime.
AI_SRC="$(dirname "$ROS_LIB_DIR")/share/ament_index/resource_index"
AI_DST="$(dirname "$STAGING")/share/ament_index/resource_index"
if [ -d "$AI_SRC" ]; then
  mkdir -p "$AI_DST"
  for ridx in rosidl_typesupport_c rosidl_typesupport_cpp rmw_typesupport \
              rmw_implementation packages rosidl_interfaces; do
    [ -d "$AI_SRC/$ridx" ] && cp -r "$AI_SRC/$ridx" "$AI_DST/" 2>/dev/null
  done
fi

echo "Staged $count shared libraries into $STAGING"
echo "Roots requested: ${#ROOTS[@]} | packages: ${PACKAGES[*]}"
echo "NOTE: for a no-ROS run also set RMW_IMPLEMENTATION=rmw_fastrtps_cpp and"
echo "      AMENT_PREFIX_PATH=$(dirname "$STAGING") (see docs/no_ros_status.md)."
