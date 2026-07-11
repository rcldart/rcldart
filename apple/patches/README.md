# Apple cross-build patches

These are applied automatically by `tool/build_ros2_apple.sh` (as version-robust
`sed` edits, not rigid `.patch` files, so they survive minor Fast-DDS bumps).

## iOS: Fast-DDS getifaddrs / if_arp

`Fast-DDS/src/cpp/utils/IPFinder.cpp` includes `<net/if_arp.h>`, which exists in
the macOS SDK but NOT the iOS SDK. The build script rewrites it to
`<net/ethernet.h>` for iOS targets (ref:
https://stackoverflow.com/questions/10395041/getting-arp-table-on-iphone-ipad).

## rcl_logging: force noop

`rcl_logging_spdlog` pulls in spdlog. The build script drops it with an
`AMENT_IGNORE` file and selects `-DRCL_LOGGING_IMPLEMENTATION=rcl_logging_noop`.
