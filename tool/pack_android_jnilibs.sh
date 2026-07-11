#!/usr/bin/env bash
# pack_android_jnilibs.sh — turn a cross-compiled ROS 2 install tree into an
# Android-loadable jniLibs folder.
#
# Android APKs have two hard constraints on native libraries:
#   1. Only files literally named lib*.so are packaged AND extracted at install.
#      Versioned names (libddsc.so.0) and symlinks are dropped.
#   2. There is no LD_LIBRARY_PATH; libs must resolve each other by SONAME from
#      the flat nativeLibraryDir.
# So we copy every real .so, RENAME it to an unversioned lib*.so, and rewrite
# each library's DT_SONAME and DT_NEEDED entries to the unversioned names with
# patchelf. After this, the flat folder is self-consistent for Android's linker.
#
# Usage: tool/pack_android_jnilibs.sh <install_dir> <abi>
#   <install_dir>  a colcon --merge-install tree (has lib/*.so[.N])
#   <abi>          arm64-v8a | x86_64
set -euo pipefail

command -v patchelf >/dev/null || { echo "patchelf required (apt install patchelf)"; exit 1; }
INSTALL="${1:?usage: pack_android_jnilibs.sh <install_dir> <abi>}"
ABI="${2:?usage: pack_android_jnilibs.sh <install_dir> <abi>}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HERE/android/src/main/jniLibs/$ABI"
mkdir -p "$OUT"

# unversion "libddsc.so.0.10.2" -> "libddsc.so"
unversion() { echo "$1" | sed -E 's/\.so(\.[0-9]+)+$/.so/'; }

echo "== copy + unversion real .so files into $OUT =="
declare -A RENAME     # old soname -> new soname
# Gather every real (non-symlink) shared object from the install lib dirs.
mapfile -t LIBS < <(find "$INSTALL" -type f \( -name '*.so' -o -name '*.so.*' \) )
for src in "${LIBS[@]}"; do
  base="$(basename "$src")"
  newbase="$(unversion "$base")"
  cp -f "$src" "$OUT/$newbase"
  # record the ELF SONAME -> new name mapping for the NEEDED rewrite pass
  soname="$(patchelf --print-soname "$OUT/$newbase" 2>/dev/null || echo "$base")"
  RENAME["$soname"]="$newbase"
  RENAME["$base"]="$newbase"
done

echo "== rewrite SONAME + NEEDED to unversioned names =="
for f in "$OUT"/*.so; do
  patchelf --set-soname "$(basename "$f")" "$f" 2>/dev/null || true
  # For each dependency, if we have an unversioned copy, repoint NEEDED to it.
  for need in $(patchelf --print-needed "$f" 2>/dev/null || true); do
    new="${RENAME[$need]:-$(unversion "$need")}"
    if [ "$need" != "$new" ] && [ -f "$OUT/$new" ]; then
      patchelf --replace-needed "$need" "$new" "$f" 2>/dev/null || true
    fi
  done
  # Android has no rpath/runpath; drop it so the linker uses nativeLibraryDir.
  patchelf --remove-rpath "$f" 2>/dev/null || true
done

echo "== also copy the ament index (share/) next to the app for AMENT_PREFIX_PATH =="
# The app copies this to its files dir at first launch; kept here for reference.
SHARE_OUT="$HERE/android/src/main/assets/ros_ament"
if [ -d "$INSTALL/share" ]; then
  mkdir -p "$SHARE_OUT"
  rsync -a --delete "$INSTALL/share/" "$SHARE_OUT/share/" 2>/dev/null \
    || cp -rf "$INSTALL/share" "$SHARE_OUT/"
fi

echo "== summary =="
echo "  libs:  $(ls -1 "$OUT"/*.so | wc -l) in $OUT"
echo "  ament: $SHARE_OUT/share"
echo "Verify a key lib resolves cleanly (no versioned NEEDED left):"
echo "  patchelf --print-needed $OUT/librcl.so"
