# Playback format samples and checks

Run the commands below from `package-media`. The manifest, preparation script,
shared integration runner and report generator are maintained in this repository.

## File format playback tests

The tests do **not** run by default (they are not under `test/`, and the app's
CI does not run them). Run them when either playback package changes: the adapter, the
`vlc_player` version, the libVLC/VLCKit build or `formats/`.

```sh
brew install ffmpeg                       # sample generation and ffprobe
tool/test_formats.sh --engine vlc         # all samples, macOS
tool/test_formats.sh --engine vlc --only 'mp4-*,mp3'   # ids or globs
tool/test_formats.sh --engine vlc --pack --only 'pack-*'  # material pack samples (../materials/playback)
```

`--pack` adds the local files of the format material pack in
the shared `../materials/playback/` directory
(ALL-370) as samples named `pack-<issue>-<ext>`, tagged with their Linear
issues; expectations come from ffprobe and its 440 Hz tone. Its moving test
pattern has no reference frame, so these samples get no snapshot comparison.

The run writes `build/formats/<engine>-<timestamp>/report.md` (plus batched results JSON,
snapshots and Flutter logs) and exits non-zero when a sample fails.

### What a sample is

[`formats/manifest.json`](manifest.json) lists the samples with the
Linear issues they verify. `tool/prepare_samples.py` prepares them into
`~/.cache/openplayx-libvlc-samples` (`OPX_SAMPLE_CACHE`), never into the
repository:

- `generate`: encoded locally with ffmpeg from SMPTE colour bars (320×240,
  25 fps) and a 1 kHz stereo tone, 6 s. No licensing questions, and the test
  knows exactly what the picture and the sound must be.
- `url` + `sha256`: downloaded (retried, size-limited) and verified.
- `playlist`: a pls/m3u/asx/cue file pointing at another sample.

Every prepared file is checked with ffprobe, so the real container and codecs
are recorded instead of trusting the extension.

### What is checked

With `--engine vlc`, each sample plays through `LibVlcBackend` in package-media’s `example/` host app, so the
result covers the same libVLC build and options as OpenPlayX:

| Check | Catches |
|---|---|
| playing state and advancing time | does not open, does not start |
| decoder statistics over 1 s (re-measured once) | black screen, stalled or dropping video, stalled or lost audio |
| tracks found by libVLC | missing video or audio track |
| snapshot vs. the SMPTE bars (mean RGB difference on a 32×24 grid, limit 24) | corrupt pictures, green/grey frames, wrong colours |
| decoded audio written with libVLC's `afile` output: RMS and frequency vs. the 1 kHz tone | silence, noise, wrong decoding |
| duration and video size | wrong timing or dimensions |
| seek to the middle, then play on to the end | seek failures, playback stopping early after a seek |

Limits: the bars are a still picture, so damage only shows when it hits a
keyframe (a corrupted keyframe scores ~87, clean samples ~9); the snapshot is
the decoded picture, not what Flutter renders (HDR
tone mapping and on-screen colour need their own tests); `afile` measures the
decoded audio, not the device output (passthrough needs a receiver).

### Known issues

- On macOS, playing without an active CoreAudio stream (such as `--aout=afile`
  in these tests or video-only files) triggers App Nap timer coalescing (~10 Hz)
  after ~30–40 s of no user input. The example host app holds a
  `ProcessInfo.beginActivity([.userInitiated, .latencyCritical])` assertion in
  `AppDelegate.swift` so batched runs stay unthrottled (ALL-371).
