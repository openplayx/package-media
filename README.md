# openplayx_media (package-media)

English | [简体中文](README.zh-CN.md)

Playback for [OpenPlayX](https://github.com/openplayx/openplayx): the libVLC and
libmpv engines behind one `PlayerBackend` interface, and the router that
picks an engine per media (`RoutedPlayerBackend`).

```
OpenPlayX app ─ openplayx_media ─ RoutedPlayerBackend (EngineRouter)
                                  ┌──────────────┘
                                  ├─ LibVlcBackend  → package-libvlc → libVLC (VLCKit, own FFmpeg)
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
| Windows (x86_64) | `tool/build_mpv.sh windows-x86_64` (MSYS2, MinGW-w64; CI before `flutter build`) | `libs/media_kit_libs_windows_video` (stub without a libmpv build) | integration_test (key samples on the Windows CI) |

media_kit and media_kit_video are forked in `forks/` (MIT, see
`forks/*/OPENPLAYX.md`): Apple TV support (Dart checks and a `tvos/` video
plugin ported from iOS), iOS 15+ AVKit Picture-in-Picture output, macOS
`MPV_RENDER_PARAM_ADVANCED_CONTROL` texture updates, and dropping
`wakelock_plus` (no Apple TV implementation; the app keeps the screen on
during playback).

## Engine routing

```dart
final player = RoutedPlayerBackend();      // EngineRouter defaults
await player.open(Uri.file('/media/a.mkv')); // libmpv
await player.open(Uri.file('/media/b.mpc')); // libVLC (Musepack SV7 seek)
player.engine;                              // MediaEngine.vlc
```

`EngineRouter` sends media to libmpv by default, including tracker modules
(`.mod`, `.xm`, `.it`, `.s3m`, ...: package-ffmpeg's libopenmpt), game console
music (`.nsf`, `.gym`, `.spc`, `.vgm`, ...: package-ffmpeg's libgme, which
`MpvBackend` names as the demuxer for these extensions), and desktop optical
disc playback (`libbluray`, `libdvdread`, `libdvdnav`). libVLC takes explicit
`byExtension` overrides (currently Musepack `.mpc`/`.mpp`/`.mp+`) and platforms
without a libmpv build (on Windows: when no `libmpv-2.dll` was bundled). When
the chosen engine fails before playback starts, `RoutedPlayerBackend` opens the
media once with the other engine (`fellBack`). The defaults, the extension
table and the available engines are constructor parameters. Unit tests:
`flutter test`.

## Layout

| Path | What |
|---|---|
| `lib/` | `RoutedPlayerBackend` and `EngineRouter`; `MpvBackend` (media_kit) implementing `PlayerBackend`; re-exports the contract and `LibVlcBackend` |
| `tool/mpv-deps.tsv` | Pinned sources: mpv (`09cf7a11`), libplacebo 7.387.0, libass 0.17.5, freetype, harfbuzz, fribidi, glad, jinja2, markupsafe, fast_float, Vulkan-Headers, libdvdread 7.1.1, libdvdnav 7.0.0, libbluray 1.5.0 |
| `tool/build_mpv.sh <target>` | Builds the dependencies statically and libmpv as a shared library against package-ffmpeg |
| `tool/make_mpv_frameworks.sh`, `tool/ensure_mpv_apple.sh` | Universal `Mpv.xcframework` whose FFmpeg references point at package-ffmpeg's frameworks |
| `tool/patches/` | Source patches applied to mpv |
| `libs/media_kit_libs_*` | Replacement native library packages for macOS, iOS, tvOS, Android, Linux, and Windows |
| `forks/` | Local forks of `media_kit` and `media_kit_video` (see `forks/*/OPENPLAYX.md`) |
| `formats/` | Sample manifest, unified cross-platform regression baseline (`material-tests.json`, `MATERIAL_TESTS*.md`), and test documentation |
| `example/` | Host app for the playback tests |
| `tool/test_materials.sh` | Unified cross-platform material regression gate (405 unique cases via `auto` router) |
| `tool/test_formats.sh` | File format playback tests for one engine (`auto`, `mpv`, or `vlc`) |

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

Not run by default. This repository owns the [sample manifest](formats/manifest.json),
the unified cross-platform regression gate (`tool/test_materials.sh`),
`tool/prepare_samples.py`, shared integration runner and report generator for
both engines. See [formats/README.md](formats/README.md) for full details and
baselines.

### Unified material regression gate

```sh
tool/test_materials.sh                                      # full macOS baseline (438 cases via auto router)
tool/test_materials.sh --list                               # list all cases without launching a player
tool/test_materials.sh --prepare-only                       # validate sample preparation only
tool/test_materials.sh --platform android --device emulator-5554
tool/test_materials.sh --platform ios --device <iPhone simulator ID>
tool/test_materials.sh --check build/material-tests/<dir>   # re-verify raw results against baseline
```

The gate runs all seven material suites (core formats/pack/external, public
corpus, HDR/Dolby Vision/disc, subtitles & playlists, historical fixes,
split/HD audio, ISO) through the `auto` router and compares against per-platform
versioned baselines:
- macOS: [405 cases](formats/MATERIAL_TESTS.md) (394 required pass, 11 allowed failure)
- Android arm64 emulator: [405 cases](formats/MATERIAL_TESTS.android.md) (395 required pass, 10 allowed failure)
- iOS arm64 simulator: [405 cases](formats/MATERIAL_TESTS.ios.md) (394 required pass, 11 allowed failure)

### Targeted format & suite runs

```sh
tool/test_formats.sh --engine auto --pack      # through the router, as the app plays
tool/test_formats.sh --engine mpv              # or --engine vlc; macOS by default
tool/test_formats.sh --engine mpv --only 'truehd,ast,mp3*'
tool/test_formats.sh --engine mpv --pack --only 'pack-*'   # material pack samples
tool/test_formats.sh --engine mpv --device <iOS simulator | emulator-5554 | Apple TV simulator>
tool/test_formats.sh --engine auto --device emulator-5554,emulator-5556   # two processes
tool/linux/run.sh -- xvfb-run -a bash package-media/tool/test_formats.sh --engine mpv --device linux
tool/test_public_corpus.sh --engine auto --source ffmpeg-fate,matroska-test-files
```

`OPX_REFERENCE_FFMPEG=/absolute/path/to/ffmpeg` selects the decoder used to
measure public corpus audio. Use a compatible version when the system FFmpeg
cannot decode a source (for example, FFmpeg 6.1 with AVI/Speex). This changes
reference measurement only; playback still uses the selected media engine.

`--pack` adds the local files of the format material pack in
the shared `../materials/playback/` directory
(ALL-370) as samples named `pack-<issue>-<ext>`, tagged with their Linear
issues; expectations come from ffprobe and its 440 Hz tone. Its moving test
pattern has no reference frame, so these samples get no snapshot comparison.

`OPX_PARALLEL` runs that many test processes (2 by default on a Mac Studio),
each with its own copy of the host app (`example-w<N>/`) and its own device:
macOS shares the host, simulators and emulators need one `--device` each
(e.g. two Android emulators: `emulator -avd <avd> -read-only -port 5556`).
The native libraries are built once before the processes start.

Android devices get the samples over HTTP from the host (`tool/serve_samples.py`
or `tool/material_transport.py`, with Range support) and print their results;
Apple TV runs a smoke test (start, size, seek to the end, audio level and
frequency; no snapshot comparison).

mpv plays to a null audio output; the decoded audio is measured with FFmpeg's
`astats` filter (low-pass, statistics over 50 codec frames): level and
frequency against the reference tone. Reports are written to
`build/material-tests/<platform>-<time>/report.md` (gate) or
`build/formats/<engine>-<time>/report.md` (single suite).

### Advanced playback regression

Generate the original HDR10+/BDMV/DVD and browser fixtures with
`python3 ../materials/playback/build_advanced.py --tsmuxer /path/to/tsMuxeR --download-dv`,
then run `bash tool/test_advanced.sh`. `--only 'advanced-bluray,advanced-dvd'`
selects disc tests. Reports and snapshots go to `build/formats/advanced-*`.
Dolby Vision colour checks use the matching official Jellyfin SDR pattern,
so successful decoding alone does not pass a visibly colour-shifted profile.

macOS/Linux builds statically include pinned libbluray 1.5.0 (with libudfread),
libdvdread 7.1.1 and libdvdnav 7.0.0 for unencrypted local main-title playback.
BD-J menus and decryption libraries are not bundled. Linux runtime and other
platforms need their own verification. Sources/checksums are in
`tool/mpv-deps.tsv`; license texts are in `LICENSES/`.

### Known issues

- In one process, after an AC3 file, Yamaha ADPCM (`.mmf`) decodes about
  23 dB quieter. Under investigation.
- A few videos drop some pictures after many players in one process (much
  less than libVLC's ALL-371).
- Public AC-4, MPEG-H 3D Audio, and IAMF samples require decoders/renderers not
  currently bundled; `ffmpeg-fate/Today.nuv` is a damaged fixture.

## Browser playback probe

`tool/web_playback_probe.mjs` checks native MP4, native HLS availability, and
MSE/fMP4 playback, decoded frames, and seeking in Chrome. It reads shared
fixtures from `../materials/playback/fixtures/` and requires Playwright and Chrome.
Run from package-media:

```sh
PLAYWRIGHT_MODULE=/path/to/playwright-core/index.mjs \
  node tool/web_playback_probe.mjs /tmp/opx-web-playback.json
```

Set `CHROME_PATH` when Chrome is not at the default macOS installation path.
The output argument is optional; it defaults to `/tmp/opx-web-playback.json`.
Browser probe results are written to the requested output file.

## License

This repository's code is MIT ([LICENSE](LICENSE)). Built and distributed
with FFmpeg (x264/x265), the combination is GPL-2.0-or-later. mpv, libplacebo,
libass and the other dependencies keep their own licenses.
