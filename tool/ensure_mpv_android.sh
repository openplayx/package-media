#!/usr/bin/env bash
# Builds libmpv (and, through package-ffmpeg, FFmpeg) for Android ABIs when
# missing or stale, and stages libmpv.so with media_kit's JNI helper into
# third_party/mpv/jniLibs/<abi>, which libs/media_kit_libs_android_video
# packages. Called by that package's Gradle build for the ABIs being built.
#   tool/ensure_mpv_android.sh [abi...]   (default: arm64-v8a armeabi-v7a x86_64)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
# One run at a time: the ABIs share build trees and jniLibs.
# Parallel callers (test processes running pod install or Gradle side by
# side) wait here; the next one then finds the build up to date. A lock left
# by a dead process is taken over.
lock="$root/third_party/.lock-android"
mkdir -p "$root/third_party"
until mkdir "$lock" 2>/dev/null; do
  holder="$(cat "$lock/pid" 2>/dev/null || true)"
  if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$lock"; continue; fi
  sleep 2
done
echo $$ > "$lock/pid"
trap 'rm -rf "$lock"' EXIT
abis=("$@")
[ ${#abis[@]} -gt 0 ] || abis=(arm64-v8a armeabi-v7a x86_64)
: "${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME}"
for abi in "${abis[@]}"; do
  env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH}" HOME="$HOME" \
    ANDROID_NDK_HOME="$ANDROID_NDK_HOME" OPX_FFMPEG_PACKAGE="${OPX_FFMPEG_PACKAGE:-}" \
    bash "$root/tool/build_mpv.sh" "android-$abi"
  jni="$root/third_party/mpv/jniLibs/$abi"
  mkdir -p "$jni"
  cp "$root/third_party/mpv/android-$abi/lib/libmpv.so.packaged" "$jni/libmpv.so"
  cp "$root/third_party/mpv/android-$abi/lib/libmediakitandroidhelper.so" "$jni/"
done
