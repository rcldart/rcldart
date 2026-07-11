#!/usr/bin/env bash
# package_ros_bundle.sh — tar the cross-compiled ROS 2 closures into release
# artifacts that the build-time fetch hooks (android/build.gradle,
# ios/macos podspec prepare_command) download.
#
# Pipeline:
#   build_ros2_android.sh / build_ros2_apple.sh   → stage closures locally
#   package_ros_bundle.sh                          → *.tar.gz artifacts (here)
#   upload artifacts to a GitHub release           → get URLs
#   set RCLDART_ROS_BUNDLE_URL[_IOS|_MACOS]         → builds auto-fetch
#
# The tar layouts match exactly what each fetch hook extracts:
#   android : contents = <abi>/*.so           (extracted into jniLibs/)
#   ios     : contents = device/… sim/…       (extracted into ios/ros/)
#   macos   : contents = lib/… share/…        (extracted into macos/ros/)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$HERE/dist}"
mkdir -p "$OUT"

pack() { # <name> -C <dir> <items...>
  local name="$1"; shift
  if tar czf "$OUT/$name" "$@" 2>/dev/null; then
    echo "  ✓ $OUT/$name  ($(du -h "$OUT/$name" | cut -f1))"
  else
    echo "  – skipped $name (nothing staged)"
    rm -f "$OUT/$name"
  fi
}

echo "== Android =="
for abi in arm64-v8a x86_64; do
  d="$HERE/android/src/main/jniLibs/$abi"
  [ -n "$(ls "$d"/*.so 2>/dev/null)" ] && pack "ros-android-$abi.tar.gz" -C "$HERE/android/src/main/jniLibs" "$abi"
done

echo "== iOS =="
[ -d "$HERE/ios/ros/device/lib" ] && [ -n "$(ls "$HERE/ios/ros/device/lib"/*.dylib 2>/dev/null)" ] \
  && pack "ros-ios.tar.gz" -C "$HERE/ios/ros" .

echo "== macOS =="
[ -n "$(ls "$HERE/macos/ros/lib"/*.dylib 2>/dev/null)" ] \
  && pack "ros-macos.tar.gz" -C "$HERE/macos/ros" .

echo "== done → $OUT =="
ls -1 "$OUT" 2>/dev/null | sed 's/^/  /' || true
cat <<'NOTE'

Next: upload these to a GitHub release, then point the build hooks at them:
  Android : flutter build apk -PrcldartRosBundleUrl=https://…/ros-android-arm64-v8a.tar.gz
            (or export RCLDART_ROS_BUNDLE_URL=…)
  iOS     : export RCLDART_ROS_BUNDLE_URL_IOS=https://…/ros-ios.tar.gz   ; flutter build ios
  macOS   : export RCLDART_ROS_BUNDLE_URL_MACOS=https://…/ros-macos.tar.gz ; flutter build macos
NOTE
