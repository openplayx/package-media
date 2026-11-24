#!/usr/bin/env bash
# Wraps libmpv of one Apple platform as Mpv.xcframework inside the package that
# replaces media_kit's native libraries (libs/media_kit_libs_<platform>_video).
# Its FFmpeg references point at package-ffmpeg's frameworks, which the app
# embeds once for media processing and playback.
#
#   tool/make_mpv_frameworks.sh macos|ios|tvos
set -euo pipefail
platform="${1:?usage: make_mpv_frameworks.sh macos}"
root="$(cd "$(dirname "$0")/.." && pwd)"
# slices: "name=target[+target...]"
case "$platform" in
  macos) slices=("macos=macos-arm64+macos-x86_64"); min=12.0; plist_min=LSMinimumSystemVersion ;;
  ios) slices=("device=ios-arm64" "simulator=ios-sim-arm64+ios-sim-x86_64"); min=15.0; plist_min=MinimumOSVersion ;;
  tvos) slices=("device=tvos-arm64" "simulator=tvos-sim-arm64"); min=15.0; plist_min=MinimumOSVersion ;;
  *) echo "unsupported platform $platform" >&2; exit 1 ;;
esac
targets=()
for slice in "${slices[@]}"; do IFS=+ read -r -a ts <<< "${slice#*=}"; targets+=("${ts[@]}"); done
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
[ "$platform" = macos ] && sub=Versions/A/ || sub=''
version="$(sed -n 's/^mpv=v\{0,1\}//p' "$root/third_party/mpv/${targets[0]}/BUILDINFO")"
args=()
for slice in "${slices[@]}"; do
  IFS=+ read -r -a ts <<< "${slice#*=}"
  fw="$work/${slice%%=*}/Mpv.framework"
  mkdir -p "$fw/${sub}Resources"
  [ -n "$sub" ] || rmdir "$fw/Resources"
  binary="$fw/${sub}Mpv"
  lipo -create $(for t in "${ts[@]}"; do echo "$root/third_party/mpv/$t/lib/libmpv.2.dylib"; done) -output "$binary"
  changes=(-id "@rpath/Mpv.framework/${sub}Mpv")
  for ref in $(otool -L "$binary" | awk '{print $1}' | grep -E '^@rpath/lib(av|sw)[a-z]+\.[0-9]+\.dylib$' | sort -u); do
    lib="${ref#@rpath/lib}"; lib="${lib%%.*}"
    case "$lib" in sw*) n="Sw${lib#sw}" ;; *) n="Av${lib#av}" ;; esac
    changes+=(-change "$ref" "@rpath/$n.framework/$sub$n")
  done
  install_name_tool "${changes[@]}" "$binary"
  cat > "$fw/${sub:+${sub}Resources/}Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Mpv</string>
<key>CFBundleIdentifier</key><string>org.openplayx.mpv</string>
<key>CFBundleName</key><string>Mpv</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$version</string>
<key>$plist_min</key><string>$min</string>
</dict></plist>
PLIST
  if [ -n "$sub" ]; then
    ln -s A "$fw/Versions/Current"
    ln -s Versions/Current/Mpv "$fw/Mpv"
    ln -s Versions/Current/Resources "$fw/Resources"
  fi
  codesign --force --sign - "$binary" >/dev/null 2>&1
  args+=(-framework "$fw")
done
xcodebuild -create-xcframework "${args[@]}" -output "$out/Mpv.xcframework" >/dev/null
# media_kit_video links -framework Mpv from Frameworks/.symlinks/mpv/<name>,
# named like media_kit's own package: ios-arm64 -> ios,
# ios-arm64_x86_64-simulator -> ios-simulator, macos-arm64_x86_64 -> macos.
mkdir -p "$out/.symlinks/mpv"
for dir in "$out/Mpv.xcframework"/*/; do
  slug="$(basename "$dir")"
  ln -s "../../Mpv.xcframework/$slug" "$out/.symlinks/mpv/$(echo "$slug" | cut -d - -f 1,3)"
done
printf '%s\n' "$fingerprint" > "$stamp"
echo "Mpv.xcframework for $platform in $out"
