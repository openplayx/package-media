#!/usr/bin/env bash
# Builds libmpv (and, through package-ffmpeg, FFmpeg) for an Apple platform
# when missing or stale, then wraps it as Mpv.xcframework. Called at
# `pod install` by libs/media_kit_libs_<platform>_video. The first build takes
# several minutes.
#   tool/ensure_mpv_apple.sh macos|ios|tvos
set -euo pipefail
platform="${1:?usage: ensure_mpv_apple.sh macos}"
root="$(cd "$(dirname "$0")/.." && pwd)"
# One run at a time: Mpv.xcframework is rebuilt in place.
# Parallel callers (test processes running pod install or Gradle side by
# side) wait here; the next one then finds the build up to date. A lock left
# by a dead process is taken over.
lock="$root/third_party/.lock-frameworks"
mkdir -p "$root/third_party"
until mkdir "$lock" 2>/dev/null; do
  holder="$(cat "$lock/pid" 2>/dev/null || true)"
  if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$lock"; continue; fi
  sleep 2
done
echo $$ > "$lock/pid"
trap 'rm -rf "$lock"' EXIT
case "$platform" in
  macos) targets=(macos-arm64 macos-x86_64) ;;
  ios) targets=(ios-arm64 ios-sim-arm64 ios-sim-x86_64) ;;
  tvos) targets=(tvos-arm64 tvos-sim-arm64) ;;
  *) echo "unsupported platform $platform" >&2; exit 1 ;;
esac
for target in "${targets[@]}"; do
  # A clean environment: Xcode/CocoaPods variables would leak into the builds.
  env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin" HOME="$HOME" \
    DEVELOPER_DIR="${DEVELOPER_DIR:-}" OPX_FFMPEG_PACKAGE="${OPX_FFMPEG_PACKAGE:-}" \
    bash "$root/tool/build_mpv.sh" "$target"
done
bash "$root/tool/make_mpv_frameworks.sh" "$platform"
