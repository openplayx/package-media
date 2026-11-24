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

Status: macOS only so far (arm64 + x86_64). iOS, tvOS, Android, Windows and
Linux follow; tvOS needs its own video widget implementation.

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
Xcode, meson, ninja, pkg-config, cmake, python3. The first build compiles FFmpeg
and libmpv (several minutes per architecture); later builds are cached by
fingerprint.

## File format playback tests

Not run by default. Samples and the checks are those of package-libvlc
(`formats/manifest.json`); the engine is selectable:

```sh
tool/test_formats.sh --engine mpv              # or --engine vlc
tool/test_formats.sh --engine mpv --only 'truehd,ast,mp3*'
```

mpv plays to a null audio output; the decoded audio is measured with FFmpeg's
`astats` filter (low-pass, statistics over 50 codec frames): level and
frequency against the 1 kHz tone. Report: `build/formats/<engine>-<time>/report.md`.

Latest macOS results (74 generated samples): mpv 73 passed (all but ASX); libVLC 66.
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
