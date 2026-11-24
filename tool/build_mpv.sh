#!/usr/bin/env bash
# Builds libmpv for one target from the pinned sources in tool/mpv-deps.tsv.
# Its own dependencies (libass, libplacebo, freetype, harfbuzz, fribidi) are
# linked statically; FFmpeg is package-ffmpeg's shared build, so the app has
# one FFmpeg for media processing and playback.
#
#   tool/build_mpv.sh <target>        targets: macos-arm64 macos-x86_64
#
# Env:    OPX_FFMPEG_PACKAGE  package-ffmpeg checkout (default ../ffmpeg-package)
# Output: third_party/mpv/<target>/lib/libmpv.2.dylib (git-ignored), whose
#         FFmpeg references are @rpath/lib<name>.<major>.dylib;
#         tool/make_mpv_frameworks.sh maps them to the FFmpeg frameworks.
set -euo pipefail
target="${1:?usage: build_mpv.sh <target>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
ffmpeg_package="$(cd "${OPX_FFMPEG_PACKAGE:-$root/../ffmpeg-package}" && pwd)"
work="$root/third_party"
deps="$work/mpv-deps/$target"
prefix="$work/mpv/$target"
ffmpeg="$ffmpeg_package/third_party/ffmpeg/$target"
for tool in meson ninja pkg-config python3; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done

fingerprint="$( { echo "$target"; cat "$0" "$root/tool/mpv-deps.tsv"; cat "$ffmpeg/BUILD_FINGERPRINT" 2>/dev/null; } |
  { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi; } | cut -d ' ' -f 1)"
if [ -f "$prefix/BUILD_FINGERPRINT" ] && [ "$(cat "$prefix/BUILD_FINGERPRINT")" = "$fingerprint" ]; then
  echo "libmpv $target is current"
  exit 0
fi

# FFmpeg first: libmpv links exactly the build the app embeds.
case "$target" in
  macos-*) bash "$ffmpeg_package/tool/ensure_ffmpeg_apple.sh" macos ;;
  *) echo "unsupported target $target" >&2; exit 1 ;;
esac

jobs="${OPX_BUILD_JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc)}"
case "$target" in
  macos-*)
    arch="${target##*-}"
    sdk=macosx; min=12.0
    sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"
    cc="$(xcrun --sdk "$sdk" -f clang)"; cxx="$(xcrun --sdk "$sdk" -f clang++)"
    ar="$(xcrun --sdk "$sdk" -f ar)"; strip_tool="$(xcrun --sdk "$sdk" -f strip)"
    flags="-arch $arch -isysroot $sysroot -mmacosx-version-min=$min"
    system=darwin; cpu="$arch"
    # Cocoa parts of mpv are Swift; compile them for the target architecture.
    swift_flags="-target $arch-apple-macos$min -sdk $sysroot"
    if [ "$arch" = arm64 ]; then family=aarch64; else family=x86_64; fi
    ;;
esac
mkdir -p "$work/downloads" "$deps/lib/pkgconfig"
cross="$deps/cross.txt"
quote() { local out='' w; for w in $1; do out="$out'$w', "; done; printf '[%s]' "${out%, }"; }
{
  echo "[binaries]"
  echo "c = '$cc'"; echo "cpp = '$cxx'"; echo "objc = '$cc'"; echo "objcpp = '$cxx'"
  echo "ar = '$ar'"; echo "strip = '$strip_tool'"; echo "pkg-config = 'pkg-config'"
  echo "[built-in options]"
  for lang in c cpp objc objcpp; do
    echo "${lang}_args = $(quote "$flags")"; echo "${lang}_link_args = $(quote "$flags")"
  done
  echo "[host_machine]"
  echo "system = '$system'"; echo "cpu_family = '$family'"; echo "cpu = '$cpu'"; echo "endian = 'little'"
} > "$cross"
# Only the pinned dependencies and package-ffmpeg are visible, never the host's.
export PKG_CONFIG_LIBDIR="$deps/lib/pkgconfig:$ffmpeg/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
unset CC CXX CFLAGS CXXFLAGS LDFLAGS CPPFLAGS OBJC OBJCFLAGS

fetch() { # name → extracted source directory
  local name="$1" checksum url archive dir
  read -r _ checksum url < <(awk -v n="$name" '$1 == n' "$root/tool/mpv-deps.tsv")
  archive="$work/downloads/$checksum.tar"
  if [ ! -f "$archive" ]; then
    curl -fL --retry 3 "$url" -o "$archive.part"
    mv "$archive.part" "$archive"
  fi
  local actual; actual="$(shasum -a 256 "$archive" 2>/dev/null || sha256sum "$archive")"
  [ "${actual%% *}" = "$checksum" ] || { echo "$name checksum mismatch" >&2; exit 1; }
  dir="$work/mpv-src/$target/$name"
  rm -rf "$dir" && mkdir -p "$dir"
  tar xf "$archive" -C "$dir" --strip-components=1
  printf '%s' "$dir"
}
meson_build() { # name source [meson options...]
  local name="$1" source="$2"; shift 2
  local build="$work/mpv-build/$target/$name"
  rm -rf "$build"
  echo "Building $name for $target (log: $build.log)"
  mkdir -p "$(dirname "$build")"
  if ! { meson setup "$build" "$source" --cross-file "$cross" --prefix="$deps" --libdir=lib \
      --buildtype=release --default-library=static --prefer-static -Db_staticpic=true "$@" &&
    meson compile -C "$build" -j "$jobs" && meson install -C "$build"; } > "$build.log" 2>&1; then
    tail -40 "$build.log" >&2; exit 1
  fi
}
asm=enabled
[ "$family" = x86_64 ] && ! command -v nasm >/dev/null && asm=disabled

meson_build freetype "$(fetch freetype)" -Dharfbuzz=disabled -Dpng=disabled -Dbzip2=disabled \
  -Dbrotli=disabled -Dzlib=internal -Dtests=disabled
meson_build fribidi "$(fetch fribidi)" -Ddocs=false -Dbin=false -Dtests=false
meson_build harfbuzz "$(fetch harfbuzz)" -Dfreetype=enabled -Dglib=disabled -Dgobject=disabled \
  -Dcairo=disabled -Dicu=disabled -Dchafa=disabled -Dtests=disabled -Ddocs=disabled \
  -Dutilities=disabled -Dintrospection=disabled
meson_build libass "$(fetch libass)" -Dfontconfig=disabled -Ddirectwrite=disabled \
  -Dlibunibreak=disabled -Dasm="$asm" -Dtest=disabled -Dprofile=disabled

placebo="$(fetch libplacebo)"
# The release archive lacks libplacebo's git submodules; Vulkan headers are
# needed by its stubs even with Vulkan disabled.
for sub in glad jinja markupsafe fast_float vulkan-headers; do
  dir="$sub"; [ "$sub" = vulkan-headers ] && dir=Vulkan-Headers
  rm -rf "$placebo/3rdparty/$dir"
  mv "$(fetch "$sub")" "$placebo/3rdparty/$dir"
done
meson_build libplacebo "$placebo" -Dvulkan=disabled -Dopengl=enabled -Dd3d11=disabled \
  -Dglslang=disabled -Dshaderc=disabled -Dlcms=disabled -Ddovi=enabled -Dlibdovi=disabled \
  -Dxxhash=disabled -Dunwind=disabled -Ddemos=false -Dtests=false -Dbench=false -Dfuzz=false

# libmpv itself: shared, embedding its static dependencies. Features for the
# render API embedding (OpenGL, VideoToolbox interop, Core Audio); Cocoa
# (with its Swift parts) is required on macOS.
mpv_build="$work/mpv-build/$target/mpv"
rm -rf "$mpv_build" "$prefix"
echo "Building mpv for $target (log: $mpv_build.log)"
mpv_src="$(fetch mpv)"
for patch in "$root"/tool/patches/mpv-*.patch; do
  patch -d "$mpv_src" -p1 --quiet < "$patch"
done
if ! { meson setup "$mpv_build" "$mpv_src" --cross-file "$cross" --prefix="$prefix" --libdir=lib \
    --buildtype=release --default-library=shared --prefer-static \
    -Dlibmpv=true -Dcplayer=false -Dtests=false -Dfuzzers=false \
    -Dmanpage-build=disabled -Dhtml-build=disabled -Dpdf-build=disabled \
    -Dlua=disabled -Djavascript=disabled -Dlibarchive=disabled -Duchardet=disabled \
    -Drubberband=disabled -Dzimg=disabled -Dlcms2=disabled -Dvapoursynth=disabled \
    -Dlibcurl=disabled -Dlibavdevice=disabled -Dvulkan=disabled \
    ${swift_flags:+-Dswift-flags="$swift_flags"} \
    -Dgl=enabled -Dvideotoolbox-gl=enabled -Dcoreaudio=enabled \
    -Dc_link_args="-Wl,-headerpad_max_install_names" &&
  meson compile -C "$mpv_build" -j "$jobs" && meson install -C "$mpv_build"; } > "$mpv_build.log" 2>&1; then
  tail -40 "$mpv_build.log" >&2; exit 1
fi
version="$(awk '$1 == "mpv" {n = split($3, part, "/"); print part[n]}' "$root/tool/mpv-deps.tsv")"
{
  echo "mpv=$version"
  echo "target=$target"
  echo "ffmpeg=$(sed -n 's/^version=//p' "$ffmpeg/BUILDINFO")"
  echo "features=$(grep -m1 'List of enabled features' "$mpv_build.log" | sed 's/.*features: //')"
} > "$prefix/BUILDINFO"
printf '%s\n' "$fingerprint" > "$prefix/BUILD_FINGERPRINT"
echo "libmpv installed to $prefix"
