#!/usr/bin/env bash
# Builds libmpv for one target from the pinned sources in tool/mpv-deps.tsv.
# Its own dependencies (libass, libplacebo, freetype, harfbuzz, fribidi) are
# linked statically; FFmpeg is package-ffmpeg's shared build, so the app has
# one FFmpeg for media processing and playback.
#
#   tool/build_mpv.sh <target>
#   targets: macos-arm64 macos-x86_64 ios-arm64 ios-sim-arm64 ios-sim-x86_64
#            tvos-arm64 tvos-sim-arm64
#            android-arm64-v8a android-armeabi-v7a android-x86_64 (ANDROID_NDK_HOME)
#            linux-x86_64 linux-arm64 (on a matching Linux host)
#            windows-x86_64 (MSYS2 with MinGW-w64 gcc, meson, ninja, pkgconf)
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

fingerprint="$( { echo "$target"; cat "$0" "$root/tool/mpv-deps.tsv"; cat "$ffmpeg/BUILD_FINGERPRINT" 2>/dev/null || true; } |
  { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi; } | cut -d ' ' -f 1)"
# Windows: libmpv staged inside libs/media_kit_libs_windows_video (its CMake
# looks there; see below).
stage_windows() {
  local staged="$root/libs/media_kit_libs_windows_video/windows/libmpv"
  rm -rf "$staged" && cp -R "$prefix/media_kit" "$staged"
}
if [ -f "$prefix/BUILD_FINGERPRINT" ] && [ "$(cat "$prefix/BUILD_FINGERPRINT")" = "$fingerprint" ]; then
  echo "libmpv $target is current"
  [[ "$target" != windows-* ]] || stage_windows
  exit 0
fi

# FFmpeg first: libmpv links exactly the build the app embeds.
case "$target" in
  macos-*) bash "$ffmpeg_package/tool/ensure_ffmpeg_apple.sh" macos ;;
  ios-*) bash "$ffmpeg_package/tool/ensure_ffmpeg_apple.sh" ios ;;
  tvos-*) bash "$ffmpeg_package/tool/ensure_ffmpeg_apple.sh" tvos ;;
  windows-*)
    if [ ! -f "$ffmpeg/BUILDINFO" ] ||
      [ "$(cat "$ffmpeg/BUILD_FINGERPRINT" 2>/dev/null)" != "$(bash "$ffmpeg_package/tool/build_fingerprint.sh" "$target")" ]; then
      bash "$ffmpeg_package/tool/build_ffmpeg.sh" "$target"
    fi ;;
  android-*|linux-*)
    if [ ! -f "$ffmpeg/lib/libavformat.so" ] ||
      [ "$(cat "$ffmpeg/BUILD_FINGERPRINT" 2>/dev/null)" != "$(bash "$ffmpeg_package/tool/build_fingerprint.sh" "$target")" ]; then
      bash "$ffmpeg_package/tool/build_ffmpeg.sh" "$target"
    fi ;;
  *) echo "unsupported target $target" >&2; exit 1 ;;
esac

jobs="${OPX_BUILD_JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc)}"
swift_flags=''
apple_link=''
# Font provider for libass: Core Text on Apple platforms (default).
libass_options=(-Dfontconfig=disabled -Ddirectwrite=disabled)
case "$target" in
  macos-*|ios-*|tvos-*)
    arch="${target##*-}"
    case "$target" in
      macos-*) sdk=macosx; min=12.0; deployment="-mmacosx-version-min=$min" ;;
      ios-sim-*) sdk=iphonesimulator; min=15.0; deployment="-mios-simulator-version-min=$min" ;;
      ios-*) sdk=iphoneos; min=15.0; deployment="-miphoneos-version-min=$min" ;;
      tvos-sim-*) sdk=appletvsimulator; min=15.0; deployment="-target $arch-apple-tvos$min-simulator" ;;
      tvos-*) sdk=appletvos; min=15.0; deployment="-target $arch-apple-tvos$min" ;;
    esac
    sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"
    cc="$(xcrun --sdk "$sdk" -f clang)"; cxx="$(xcrun --sdk "$sdk" -f clang++)"
    ar="$(xcrun --sdk "$sdk" -f ar)"; strip_tool="$(xcrun --sdk "$sdk" -f strip)"
    flags="-arch $arch -isysroot $sysroot $deployment"
    system=darwin; cpu="$arch"
    if [ "$arch" = arm64 ]; then family=aarch64; else family=x86_64; fi
    # Room for make_mpv_frameworks.sh to rewrite the install names.
    apple_link="-Wl,-headerpad_max_install_names $flags"
    case "$target" in
      macos-*)
        # Cocoa parts of mpv are Swift; compile them for the target architecture.
        swift_flags="-target $arch-apple-macos$min -sdk $sysroot"
        platform_options=(-Dvideotoolbox-gl=enabled -Dcoreaudio=enabled) ;;
      *)
        # OpenGL ES with VideoToolbox interop, AudioUnit output; no Cocoa/Swift.
        platform_options=(-Dios-gl=enabled -Daudiounit=enabled -Dcocoa=disabled
          -Dswift-build=disabled -Dcoreaudio=disabled -Davfoundation=disabled
          -Dvideotoolbox-gl=disabled) ;;
    esac
    ;;
  android-*)
    abi="${target#android-}"
    ndk="${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME}"
    tc="$ndk/toolchains/llvm/prebuilt/$(uname -s | tr A-Z a-z)-x86_64/bin"
    case "$abi" in
      arm64-v8a) triple=aarch64-linux-android; family=aarch64; cpu=aarch64 ;;
      armeabi-v7a) triple=armv7a-linux-androideabi; family=arm; cpu=armv7 ;;
      x86_64) triple=x86_64-linux-android; family=x86_64; cpu=x86_64 ;;
      *) echo "unknown ABI $abi" >&2; exit 1 ;;
    esac
    cc="$tc/${triple}24-clang"; cxx="$tc/${triple}24-clang++"
    ar="$tc/llvm-ar"; strip_tool="$tc/llvm-strip"
    # 16 KB pages (Android 15+); C++ dependencies use the static runtime.
    flags="-fPIC"
    link_flags="-Wl,-z,max-page-size=16384 -static-libstdc++"
    system=android
    # No system font provider on Android: fonts come from mpv's font options.
    libass_options+=(-Drequire-system-font-provider=false)
    # EGL/GLES output for media_kit's Surface, AAudio/OpenSL ES/AudioTrack.
    platform_options=(-Degl-android=enabled -Dandroid-media-ndk=enabled -Daaudio=enabled
      -Dopensles=enabled -Daudiotrack=enabled -Diconv=disabled)
    ;;
  windows-x86_64)
    # Native MinGW-w64 tools see Windows paths only: every path meson, gcc or
    # pkgconf gets is converted, and pkgconf derives prefixes from the .pc
    # location (package-ffmpeg's .pc files carry MSYS paths).
    win() { cygpath -m "$1"; }
    cc="$(win "$(command -v gcc)")"; cxx="$(win "$(command -v g++)")"
    ar="$(win "$(command -v ar)")"; strip_tool="$(win "$(command -v strip)")"
    pkgconf_bin="$(win "$(command -v pkgconf)")"
    flags=""
    # One DLL without libgcc/libstdc++/winpthread DLLs (as package-ffmpeg's).
    # Not a global -static: it would take MSYS2's static FFmpeg archives for
    # -lavcodec instead of package-ffmpeg's DLL import libraries. Static
    # copies of the runtime libraries (winpthread also as libpthread) sit in
    # the first -L directory, found before MinGW's DLL import libraries.
    runtime="$work/mpv-build/$target/runtime"
    mkdir -p "$runtime"
    for lib in winpthread stdc++; do cp "$(gcc -print-file-name=lib$lib.a)" "$runtime/"; done
    cp "$runtime/libwinpthread.a" "$runtime/libpthread.a"
    link_flags="-L$(win "$runtime") -static-libgcc -static-libstdc++"
    system=windows; cpu=x86_64; family=x86_64
    libass_options=(-Dfontconfig=disabled -Ddirectwrite=enabled)
    # Render API over the app's OpenGL (ANGLE in media_kit_video); WASAPI.
    # MSYS2's packages (pulled in by its ffmpeg for the sample tools) must not
    # be autodetected (meson also looks through CMake): shaderc, disc and
    # SDL/OpenAL/JACK support are not used by the render API.
    platform_options=(-Dgl-win32=enabled -Dwasapi=enabled -Dd3d11=disabled
      -Dd3d-hwaccel=enabled -Diconv=disabled -Dwin32-smtc=disabled
      -Dshaderc=disabled -Dspirv-cross=disabled -Dlibbluray=disabled -Ddvdnav=disabled
      -Dcdda=disabled -Dopenal=disabled -Djack=disabled -Dsdl2-audio=disabled
      -Dsdl2-video=disabled -Dsdl2-gamepad=disabled -Dsixel=disabled -Dcaca=disabled
      -Djpeg=disabled)
    ;;
  linux-*)
    case "$target/$(uname -m)" in linux-arm64/aarch64|linux-x86_64/x86_64) ;; *) echo "build $target on a matching Linux host" >&2; exit 1 ;; esac
    cc=gcc; cxx=g++; ar=ar; strip_tool=strip
    flags="-fPIC"
    # Next to FFmpeg in the app's lib/; C++ dependencies keep libstdc++ static.
    link_flags="-Wl,-rpath,\$ORIGIN -static-libstdc++"
    system=linux; cpu="$(uname -m)"; family="$cpu"
    # System Fontconfig for libass; render API over EGL; PulseAudio/ALSA.
    libass_options=(-Dfontconfig=enabled -Ddirectwrite=disabled)
    platform_options=(-Degl=enabled -Dpulse=enabled -Dalsa=enabled -Dx11=disabled
      -Dwayland=disabled -Ddrm=disabled -Dgbm=disabled -Dvaapi=disabled -Dvdpau=disabled)
    ;;
esac
mkdir -p "$work/downloads" "$deps/lib/pkgconfig"
cross="$deps/cross.txt"
quote() { local out='' w; for w in $1; do out="$out'$w', "; done; printf '[%s]' "${out%, }"; }
{
  echo "[binaries]"
  echo "c = '$cc'"; echo "cpp = '$cxx'"; echo "objc = '$cc'"; echo "objcpp = '$cxx'"
  echo "ar = '$ar'"; echo "strip = '$strip_tool'"
  if [ "$system" = windows ]; then
    echo "pkg-config = ['$pkgconf_bin', '--define-prefix']"
  else
    echo "pkg-config = 'pkg-config'"
  fi
  # x86 assembly (libass, dav1d-style code) needs nasm named in the cross file.
  if command -v nasm >/dev/null; then
    nasm_bin="$(command -v nasm)"; [ "$system" = windows ] && nasm_bin="$(cygpath -m "$nasm_bin")"
    echo "nasm = '$nasm_bin'"
  fi
  echo "[built-in options]"
  for lang in c cpp objc objcpp; do
    echo "${lang}_args = $(quote "$flags")"; echo "${lang}_link_args = $(quote "$flags ${link_flags:-}")"
  done
  echo "[host_machine]"
  echo "system = '$system'"; echo "cpu_family = '$family'"; echo "cpu = '$cpu'"; echo "endian = 'little'"
} > "$cross"
# Our dependencies exist only as static libraries. On Linux, desktop system
# libraries (Fontconfig, ...) must link dynamically: their static archives are
# not position-independent, so meson must not prefer them.
prefer_static=--prefer-static
[ "$system" = linux ] && prefer_static=''
# Only the pinned dependencies and package-ffmpeg are visible, never the host's.
# Paths for native tools: Windows form on Windows, unchanged elsewhere.
tp() { if [ "$system" = windows ]; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
if [ "$system" = windows ]; then
  # With --prefer-static, meson resolves -lavformat to a static archive in any
  # library directory and took MSYS2's static FFmpeg (C:/msys64/mingw64/lib)
  # over package-ffmpeg's DLL import libraries. Copies of the import libraries
  # named lib*.a, in package-ffmpeg's lib directory (searched first), win.
  for implib in "$ffmpeg"/lib/lib*.dll.a; do
    [ -e "$implib" ] || { echo "no FFmpeg import libraries in $ffmpeg/lib" >&2; exit 1; }
    cp "$implib" "${implib%.dll.a}.a"
  done
fi
# The FFmpeg prefix may come from a CI cache built in another checkout, and
# FFmpeg writes absolute libdir/includedir into its pkg-config files: point
# them at this location (otherwise the headers "are not found").
for pc in "$ffmpeg"/lib/pkgconfig/*.pc; do
  [ -e "$pc" ] || continue
  sed -i.orig -e "s#^prefix=.*#prefix=$(tp "$ffmpeg")#" -e "s#^libdir=.*#libdir=$(tp "$ffmpeg/lib")#" \
    -e "s#^includedir=.*#includedir=$(tp "$ffmpeg/include")#" "$pc" && rm -f "$pc.orig"
done
export PKG_CONFIG_LIBDIR="$deps/lib/pkgconfig:$ffmpeg/lib/pkgconfig"
[ "$system" = windows ] && PKG_CONFIG_LIBDIR="$(tp "$deps/lib/pkgconfig");$(tp "$ffmpeg/lib/pkgconfig")"
if [ "$system" = linux ]; then
  # Desktop system libraries (Fontconfig, EGL, PulseAudio, ALSA) are linked
  # dynamically from the distribution.
  PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$(pkg-config --variable pc_path pkg-config)"
fi
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
  if ! { meson setup "$(tp "$build")" "$(tp "$source")" --cross-file "$(tp "$cross")" --prefix="$(tp "$deps")" --libdir=lib \
      --buildtype=release --default-library=static ${prefer_static} -Db_staticpic=true "$@" &&
    meson compile -C "$(tp "$build")" -j "$jobs" && meson install -C "$(tp "$build")"; } > "$build.log" 2>&1; then
    tail -40 "$build.log" >&2; exit 1
  fi
}
# libass has assembly for x86 and 64-bit ARM only (armeabi-v7a fails with
# "Assembly was requested, but cannot be built").
asm=enabled
case "$family" in x86_64|aarch64) ;; *) asm=disabled ;; esac
[ "$family" = x86_64 ] && ! command -v nasm >/dev/null && asm=disabled

meson_build freetype "$(fetch freetype)" -Dharfbuzz=disabled -Dpng=disabled -Dbzip2=disabled \
  -Dbrotli=disabled -Dzlib=internal -Dtests=disabled
meson_build fribidi "$(fetch fribidi)" -Ddocs=false -Dbin=false -Dtests=false
meson_build harfbuzz "$(fetch harfbuzz)" -Dfreetype=enabled -Dglib=disabled -Dgobject=disabled \
  -Dcairo=disabled -Dicu=disabled -Dchafa=disabled -Dtests=disabled -Ddocs=disabled \
  -Dutilities=disabled -Dintrospection=disabled
meson_build libass "$(fetch libass)" "${libass_options[@]}" \
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

if [ "$system" = windows ]; then
  # Dependencies ask for -lgcc_s (x265, also in FFmpeg's Libs.private); with --prefer-static meson
  # resolves it to MinGW's libgcc_s.a, the import library of
  # libgcc_s_seh-1.dll (not shipped). libgcc is linked statically anyway.
  for pc in "$deps"/lib/pkgconfig/*.pc "$ffmpeg"/lib/pkgconfig/*.pc; do
    if grep -q -- '-lgcc_s' "$pc"; then
      echo "dropping -lgcc_s from $(basename "$pc")"
      sed -i 's/[[:space:]]*-lgcc_s\b//g' "$pc"
    fi
  done
fi
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
if ! { meson setup "$(tp "$mpv_build")" "$(tp "$mpv_src")" --cross-file "$(tp "$cross")" --prefix="$(tp "$prefix")" --libdir=lib \
    --buildtype=release --default-library=shared ${prefer_static} \
    -Dlibmpv=true -Dcplayer=false -Dtests=false -Dfuzzers=false \
    -Dmanpage-build=disabled -Dhtml-build=disabled -Dpdf-build=disabled \
    -Dlua=disabled -Djavascript=disabled -Dlibarchive=disabled -Duchardet=disabled \
    -Drubberband=disabled -Dzimg=disabled -Dlcms2=disabled -Dvapoursynth=disabled \
    -Dlibcurl=disabled -Dlibavdevice=disabled -Dvulkan=disabled \
    ${swift_flags:+-Dswift-flags="$swift_flags"} \
    -Dgl=enabled "${platform_options[@]}" \
    ${apple_link:+-Dc_link_args="$apple_link"} &&
  meson compile -C "$(tp "$mpv_build")" -j "$jobs" && meson install -C "$(tp "$mpv_build")"; } > "$mpv_build.log" 2>&1; then
  tail -40 "$mpv_build.log" >&2; exit 1
fi
if [[ "$target" = windows-* ]]; then
  # The layout media_kit_video expects (libs/media_kit_libs_windows_video
  # copies it to <build>/libmpv): flat headers, import library, DLL.
  rm -rf "$prefix/media_kit" && mkdir -p "$prefix/media_kit/include"
  cp "$prefix"/include/mpv/*.h "$prefix/media_kit/include/"
  cp "$prefix/lib/libmpv.dll.a" "$prefix/bin/libmpv-2.dll" "$prefix/media_kit/"
  # libmpv-2.dll may import only Windows' own DLLs and package-ffmpeg's: a DLL
  # from MSYS2 (zlib1, libiconv, libwinpthread, ...) is not shipped with the
  # app, and loading libmpv then fails as "cannot find libmpv-2.dll".
  imports="$(objdump -p "$prefix/bin/libmpv-2.dll" | sed -n 's/^[[:space:]]*DLL Name: //p' | sort -u)"
  echo "libmpv-2.dll imports: $(echo $imports)"
  foreign="$(printf '%s\n' "$imports" | grep -viE '^(av(codec|filter|format|util)|sw(resample|scale))-[0-9]+\.dll$' |
    grep -viE '^(kernel32|user32|gdi32|advapi32|shell32|ole32|oleaut32|ws2_32|bcrypt|crypt32|secur32|ntdll|shlwapi|imm32|winmm|avrt|dwmapi|uxtheme|version|pathcch|shcore|uuid|dxgi|d3d9|d3d11|dxva2|mfplat|propsys|dwrite|usp10|opengl32|comctl32|comdlg32|setupapi|powrprof|userenv|msvcrt|ucrtbase)\.dll$' |
    grep -viE '^api-ms-win-.*\.dll$' || true)"
  if [ -n "$foreign" ]; then
    echo "libmpv-2.dll imports DLLs the app does not ship: $(echo $foreign)" >&2
    exit 1
  fi
  stage_windows
fi
if [[ "$target" = linux-* ]]; then
  # Users link the shared libmpv only: its static dependencies are inside, so
  # the private requirements (not installed anywhere) must not be checked.
  # Linking against it needs package-ffmpeg's libraries (its NEEDED entries).
  sed -i -e '/^Requires.private:/d' -e '/^Libs.private:/d' \
    -e "s#^Libs: \(.*\)#Libs: \1 -Wl,-rpath-link,$ffmpeg/lib#" "$prefix/lib/pkgconfig/mpv.pc"
  # Executables linking a library that needs libmpv resolve FFmpeg through
  # libmpv's RUNPATH ($ORIGIN): FFmpeg next to it, as in the app bundle.
  ln -sf "$ffmpeg"/lib/lib*.so.[0-9]* "$prefix/lib/"
  # A real file named by soname for the app bundle (lib/, next to FFmpeg).
  mkdir -p "$prefix/bundle"
  cp -L "$prefix/lib/libmpv.so.2" "$prefix/bundle/libmpv.so.2"
fi
if [[ "$target" = android-* ]]; then
  # media_kit loads libmpv.so and its JNI helper from the APK.
  # mpv names the library libmpv.so on Android (no versioned soname).
  cp -L "$prefix/lib/libmpv.so" "$prefix/lib/libmpv.so.packaged"
  "$cc" -shared -fPIC -O2 -fvisibility=hidden -Wl,-z,max-page-size=16384 \
    "$root/tool/android/mediakitandroidhelper.c" -landroid -llog \
    -o "$prefix/lib/libmediakitandroidhelper.so"
fi
version="$(awk '$1 == "mpv" {n = split($3, part, "/"); print part[n]}' "$root/tool/mpv-deps.tsv")"
{
  echo "mpv=$version"
  echo "target=$target"
  echo "ffmpeg=$(sed -n 's/^version=//p' "$ffmpeg/BUILDINFO")"
  echo "ffmpeg_prefix=$ffmpeg"
  echo "features=$(grep -m1 'List of enabled features' "$mpv_build.log" | sed 's/.*features: //')"
} > "$prefix/BUILDINFO"
printf '%s\n' "$fingerprint" > "$prefix/BUILD_FINGERPRINT"
echo "libmpv installed to $prefix"
