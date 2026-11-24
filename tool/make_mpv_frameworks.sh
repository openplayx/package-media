#!/usr/bin/env bash
# Wraps libmpv of one Apple platform as Mpv.xcframework inside the package that
# replaces media_kit's native libraries (libs/media_kit_libs_<platform>_video).
# Its FFmpeg references point at package-ffmpeg's frameworks, which the app
# embeds once for media processing and playback.
#
#   tool/make_mpv_frameworks.sh macos
set -euo pipefail
platform="${1:?usage: make_mpv_frameworks.sh macos}"
root="$(cd "$(dirname "$0")/.." && pwd)"
case "$platform" in
  macos) targets=(macos-arm64 macos-x86_64); min=12.0 ;;
  *) echo "unsupported platform $platform" >&2; exit 1 ;;
esac
pkg="$root/libs/media_kit_libs_${platform}_video/$platform"
out="$pkg/Frameworks"
stamp="$out/.fingerprint"
fingerprint="$(for t in "${targets[@]}"; do cat "$root/third_party/mpv/$t/BUILD_FINGERPRINT"; done; cat "$0")"
if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$fingerprint" ]; then
  echo "Mpv $platform framework is current"
  exit 0
fi
work="$root/third_party/mpv/frameworks/$platform"
rm -rf "$work" "$out"
mkdir -p "$work" "$out"
fw="$work/Mpv.framework"
mkdir -p "$fw/Versions/A/Resources"
binary="$fw/Versions/A/Mpv"
lipo -create $(for t in "${targets[@]}"; do echo "$root/third_party/mpv/$t/lib/libmpv.2.dylib"; done) -output "$binary"
changes=(-id @rpath/Mpv.framework/Versions/A/Mpv)
for ref in $(otool -L "$binary" | awk '{print $1}' | grep -E '^@rpath/lib(av|sw)[a-z]+\.[0-9]+\.dylib$' | sort -u); do
  lib="${ref#@rpath/lib}"; lib="${lib%%.*}"
  case "$lib" in sw*) n="Sw${lib#sw}" ;; *) n="Av${lib#av}" ;; esac
  changes+=(-change "$ref" "@rpath/$n.framework/Versions/A/$n")
done
install_name_tool "${changes[@]}" "$binary"
version="$(sed -n 's/^mpv=v\{0,1\}//p' "$root/third_party/mpv/${targets[0]}/BUILDINFO")"
cat > "$fw/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Mpv</string>
<key>CFBundleIdentifier</key><string>org.openplayx.mpv</string>
<key>CFBundleName</key><string>Mpv</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$version</string>
<key>LSMinimumSystemVersion</key><string>$min</string>
</dict></plist>
PLIST
ln -s A "$fw/Versions/Current"
ln -s Versions/Current/Mpv "$fw/Mpv"
ln -s Versions/Current/Resources "$fw/Resources"
codesign --force --sign - "$binary" >/dev/null 2>&1
xcodebuild -create-xcframework -framework "$fw" -output "$out/Mpv.xcframework" >/dev/null
# media_kit_video links -framework Mpv from Frameworks/.symlinks/mpv/<platform>.
slice="$(cd "$out/Mpv.xcframework" && ls -d "$platform"-*/ | head -1)"
mkdir -p "$out/.symlinks/mpv"
ln -s "../../Mpv.xcframework/${slice%/}" "$out/.symlinks/mpv/$platform"
printf '%s\n' "$fingerprint" > "$stamp"
echo "Mpv.xcframework for $platform in $out"
