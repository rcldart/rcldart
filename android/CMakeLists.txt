# Android-only native shim for rcldart.
#
# Builds librcldart_ifaddrs.so — a getifaddrs()/freeifaddrs() implementation
# that parses `ip addr` / `ifconfig` output. CycloneDDS / FastDDS discovery
# calls getifaddrs() to pick a network interface; Android's bionic version does
# not report usable AF_INET interfaces in an app sandbox, so DDS finds no peers.
# The app loads this library FIRST with RTLD_GLOBAL (see AndroidRosBootstrap)
# so the DDS layer resolves our getifaddrs instead of bionic's.
cmake_minimum_required(VERSION 3.10)
project(rcldart_android C)

add_library(rcldart_ifaddrs SHARED src/main/cpp/rcldart_ifaddrs.c)
set_target_properties(rcldart_ifaddrs PROPERTIES OUTPUT_NAME "rcldart_ifaddrs")
target_link_libraries(rcldart_ifaddrs log)

# Cross-compile + stage the ROS 2 closure from within this CMake build
# (zenoh_ffi pattern), instead of a separate bash step. Opt in with
# -DRCLDART_BUILD_ROS=ON; no-op if the closure is already in jniLibs.
include("${CMAKE_CURRENT_SOURCE_DIR}/ros2_android_build.cmake")
