#!/usr/bin/env bash
# Builds libmpv (and, through package-ffmpeg, FFmpeg) for Android ABIs when
# missing or stale, and stages libmpv.so with media_kit's JNI helper into
# third_party/mpv/jniLibs/<abi>, which libs/media_kit_libs_android_video
# packages. Called by that package's Gradle build for the ABIs being built.
#   tool/ensure_mpv_android.sh [abi...]   (default: arm64-v8a armeabi-v7a x86_64)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
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
