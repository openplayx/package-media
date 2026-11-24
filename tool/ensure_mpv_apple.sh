#!/usr/bin/env bash
# Builds libmpv (and, through package-ffmpeg, FFmpeg) for an Apple platform
# when missing or stale, then wraps it as Mpv.xcframework. Called at
# `pod install` by libs/media_kit_libs_<platform>_video. The first build takes
# several minutes.
#   tool/ensure_mpv_apple.sh macos
set -euo pipefail
platform="${1:?usage: ensure_mpv_apple.sh macos}"
root="$(cd "$(dirname "$0")/.." && pwd)"
case "$platform" in
  macos) targets=(macos-arm64 macos-x86_64) ;;
  *) echo "unsupported platform $platform" >&2; exit 1 ;;
esac
for target in "${targets[@]}"; do
  # A clean environment: Xcode/CocoaPods variables would leak into the builds.
  env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin" HOME="$HOME" \
    DEVELOPER_DIR="${DEVELOPER_DIR:-}" OPX_FFMPEG_PACKAGE="${OPX_FFMPEG_PACKAGE:-}" \
    bash "$root/tool/build_mpv.sh" "$target"
done
bash "$root/tool/make_mpv_frameworks.sh" "$platform"
