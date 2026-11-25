# openplayx_media (package-media)

English | [简体中文](README.zh-CN.md)

Playback for [OpenPlayX](https://github.com/openplayx/openplayx): the libVLC and
libmpv engines behind one `PlayerBackend` interface, and (next) the router that
picks an engine per format.

```
OpenPlayX app ─ openplayx_media ─┬─ LibVlcBackend  → package-libvlc → libVLC (VLCKit, own FFmpeg)
                                  └─ MpvBackend     → media_kit (Dart API, video widget)
                                                      → libmpv built here → package-ffmpeg's FFmpeg 9.1
```

**One FFmpeg.** libmpv is built from pinned sources by this repository and
links package-ffmpeg's shared FFmpeg, the same copy that the app's media
processing (opx_media) uses. media_kit's prebuilt native libraries are
replaced by `libs/media_kit_libs_<platform>_video`.

| Platform | libmpv build | media_kit native package | Format tests |
|---|---|---|---|
| macOS (arm64, x86_64) | `tool/ensure_mpv_apple.sh macos` | `libs/media_kit_libs_macos_video` | integration_test |
| iOS (device, simulator) | `tool/ensure_mpv_apple.sh ios` | `libs/media_kit_libs_ios_video` | integration_test (simulator) |
| tvOS (device, simulator) | `tool/ensure_mpv_apple.sh tvos` | `libs/media_kit_libs_tvos_video` + `forks/` | `example/lib/tvos_smoke.dart` via flutter-tvos |
| Android (arm64-v8a, armeabi-v7a, x86_64) | `tool/ensure_mpv_android.sh` (Gradle) | `libs/media_kit_libs_android_video` | integration_test, samples over HTTP |
| Linux (x86_64, arm64) | `tool/build_mpv.sh linux-<arch>` (CMake) | `libs/media_kit_libs_linux` | integration_test under Xvfb (`tool/linux/run.sh`) |
| Windows | not yet | – | – |

media_kit and media_kit_video are forked in `forks/` (MIT, see
`forks/*/OPENPLAYX.md`): Apple TV support (Dart checks and a `tvos/` video
plugin ported from iOS); media_kit_video drops wakelock_plus, which has no
Apple TV implementation, so the app keeps the screen on during playback.

## Layout

| Path | What |
|---|---|
| `lib/` | `MpvBackend` (media_kit) implementing `PlayerBackend`; re-exports the contract and `LibVlcBackend` |
| `tool/mpv-deps.tsv` | Pinned sources: mpv 0.42.0, libplacebo 7.387.0, libass 0.17.5, freetype, harfbuzz, fribidi, glad, jinja2, markupsafe, fast_float, Vulkan-Headers |
| `tool/build_mpv.sh <target>` | Builds the dependencies statically and libmpv as a shared library against package-ffmpeg |
| `tool/make_mpv_frameworks.sh`, `tool/ensure_mpv_apple.sh` | Universal `Mpv.xcframework` whose FFmpeg references point at package-ffmpeg's frameworks |
| `tool/patches/` | Source patches applied to mpv |
| `libs/media_kit_libs_macos_video` | Replacement for media_kit's macOS native library package; builds libmpv at `pod install` |
| `example/` | Host app for the playback tests |
| `tool/test_formats.sh` | File format playback tests for one engine |

## Requirements

Sibling checkouts `../ffmpeg-package` (package-ffmpeg) and `../package-libvlc`;
meson, ninja, pkg-config, cmake, python3; Xcode (Apple), `ANDROID_NDK_HOME`
(Android); Linux builds run on a matching Linux host or in `tool/linux/run.sh`
(Docker, Ubuntu 24.04 with the desktop libraries libmpv links: Fontconfig,
EGL, PulseAudio, ALSA). tvOS uses the pinned flutter-tvos toolchain in
`../.toolchains/flutter-tvos` (`FLUTTER_TVOS_BIN`). The first build compiles
FFmpeg and libmpv (minutes per architecture); later builds are cached by
fingerprint.

## File format playback tests

Not run by default. Samples and the checks are those of package-libvlc
(`formats/manifest.json`); the engine is selectable:

```sh
tool/test_formats.sh --engine mpv              # or --engine vlc; macOS by default
tool/test_formats.sh --engine mpv --only 'truehd,ast,mp3*'
tool/test_formats.sh --engine mpv --pack --only 'pack-*'   # material pack samples
tool/test_formats.sh --engine mpv --device <iOS simulator | emulator-5554 | Apple TV simulator>
tool/linux/run.sh -- xvfb-run -a bash package-media/tool/test_formats.sh --engine mpv --device linux
```

`--pack` adds the local files of the format material pack in
[openplayx-test](https://github.com/openplayx/openplayx-test) `formats/`
(ALL-370) as samples named `pack-<issue>-<ext>`, tagged with their Linear
issues; expectations come from ffprobe and its 440 Hz tone. Its moving test
pattern has no reference frame, so these samples get no snapshot comparison.

Android devices get the samples over HTTP from the host (`tool/serve_samples.py`,
with Range support) and print their results; Apple TV runs a smoke test
(start, size, seek to the end, audio level and frequency; no snapshot
comparison).

mpv plays to a null audio output; the decoded audio is measured with FFmpeg's
`astats` filter (low-pass, statistics over 50 codec frames): level and
frequency against the 1 kHz tone. Report: `build/formats/<engine>-<time>/report.md`.

Latest results with mpv (74 generated samples): macOS 73, iOS simulator 73,
Apple TV simulator 73, Android emulator 72, Linux arm64 72 (Linux amd64: the
key samples pass). Failures: ASX (not supported by mpv) and the `.mmf` level
issue (ALL-373). libVLC on macOS: 66.
Material pack (67 samples, macOS): mpv 61, libVLC 48. mpv fails ASX, DSF and
WavPack seeking, MOD (no libopenmpt in package-ffmpeg), and reports the
side-by-side 3D file at a corrected size; the RA fixture itself is broken.
Many libVLC failures are 3-second audio files ending right after the seek,
which pass at 6 seconds (under investigation).
mpv plays what libVLC cannot: TrueHD, AST, FLAC in Ogg, pls/m3u/cue
playlists, raw MPEG-2 video with timing. Neither plays ASX playlists.

### Known issues

- In one process, after an AC3 file, Yamaha ADPCM (`.mmf`) decodes about
  23 dB quieter. Under investigation.
- A few videos drop some pictures after many players in one process (much
  less than libVLC's ALL-371).

## License

This repository's code is MIT ([LICENSE](LICENSE)). Built and distributed
with FFmpeg (x264/x265), the combination is GPL-2.0-or-later. mpv, libplacebo,
libass and the other dependencies keep their own licenses.
