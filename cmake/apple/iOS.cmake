# iOS device (arm64). Cross-compile ROS 2 as SHARED libs — see the spec.
set(CMAKE_SYSTEM_NAME Darwin)
set(CMAKE_SYSTEM_VERSION 14)
set(CMAKE_SYSTEM_PROCESSOR arm64)
set(CMAKE_C_COMPILER_WORKS TRUE)
set(CMAKE_CXX_COMPILER_WORKS TRUE)
set(IOS TRUE)
execute_process(COMMAND xcodebuild -version -sdk iphoneos Path
  OUTPUT_VARIABLE CMAKE_OSX_SYSROOT ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
set(CMAKE_C_FLAGS   "-target arm64-apple-ios -mios-version-min=14.0")
set(CMAKE_CXX_FLAGS "-target arm64-apple-ios -mios-version-min=14.0")
set(CMAKE_CROSSCOMPILING TRUE)
