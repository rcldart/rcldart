# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(rcldart_library VERSION 0.0.1 LANGUAGES C)

add_library(rcldart SHARED
  "rcldart.c"
)

set_target_properties(rcldart PROPERTIES
  PUBLIC_HEADER rcldart.h
  OUTPUT_NAME "rcldart"
)

target_compile_definitions(rcldart PUBLIC DART_SHARED_LIB)


