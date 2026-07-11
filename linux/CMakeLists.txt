# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "rcldart")
project(${PROJECT_NAME} LANGUAGES CXX)

# Invoke the build for native code shared with the other target platforms.
# This can be changed to accommodate different builds.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

# Stage the ROS 2 / DDS / rosidl runtime .so closure so the app runs on Linux
# devices WITHOUT ROS installed. rcldart dlopen()s these by name at runtime, so
# they must be bundled into <app>/lib next to librcldart.so.
#
# Set RCLDART_BUNDLE_ROS_LIBS=OFF to skip (e.g. dev machines with ROS sourced).
# Extra interface packages: pass RCLDART_EXTRA_PACKAGES="pkg_a;pkg_b".
# OFF by default: on a dev machine with ROS sourced, bundling a partial/DDS-
# mismatched closure loads libraries twice (bundle + /opt/ros) and crashes.
# Turn ON for release/no-ROS packaging once the closure is complete & correct.
option(RCLDART_BUNDLE_ROS_LIBS "Bundle the ROS 2 runtime .so closure" OFF)
set(_ros_bundled_libs "")
if(RCLDART_BUNDLE_ROS_LIBS)
  set(_ros_stage "${CMAKE_CURRENT_BINARY_DIR}/ros_libs")
  string(REPLACE ";" " " _extra_pkgs "${RCLDART_EXTRA_PACKAGES}")
  execute_process(
    COMMAND bash "${CMAKE_CURRENT_SOURCE_DIR}/../tool/bundle_ros_libs.sh"
            "${_ros_stage}" ${RCLDART_EXTRA_PACKAGES}
    RESULT_VARIABLE _bundle_res
    OUTPUT_VARIABLE _bundle_out)
  if(NOT _bundle_res EQUAL 0)
    message(WARNING "bundle_ros_libs.sh failed (${_bundle_res}); the app may "
      "require ROS on the target. Output:\n${_bundle_out}")
  else()
    message(STATUS "rcldart: ${_bundle_out}")
  endif()
  file(GLOB _ros_bundled_libs "${_ros_stage}/*.so*")
endif()

# List of absolute paths to libraries that should be bundled with the plugin.
set(rcldart_bundled_libraries
  # Defined in ../src/CMakeLists.txt.
  $<TARGET_FILE:rcldart>
  # ROS 2 / DDS runtime closure staged above (empty if disabled/unavailable).
  ${_ros_bundled_libs}
  PARENT_SCOPE
)
