# Playback format samples and checks

Run the commands below from `package-media`. The manifest, preparation script,
shared integration runner and report generator are maintained in this repository.

## 素材测试总入口（回归门禁）

```sh
tool/test_materials.sh                 # 执行完整基线；最终退出码就是整体判定
tool/test_materials.sh --list          # 输出完整入口列表，不启动播放器
tool/test_materials.sh --prepare-only # 检查准备流程，不给出播放通过结论
tool/test_materials.sh --platform android --device emulator-5554
tool/test_materials.sh --platform ios --device <iPhone模拟器ID>
```

完整列表见 [MATERIAL_TESTS.md](MATERIAL_TESTS.md)，机器可读、受版本控制的
基线见 [material-tests.json](material-tests.json)。当前快照包含 **599 项** macOS
素材测试（auto 438、mpv 86、vlc 75）：**545 项必须通过，54 项允许失败**。
同一素材在不同引擎下分别计数。545 项中有两项新发现、尚无实测结果的用例，
默认要求通过，不能自动豁免。

平台独立基线：

| 平台 | 清单 | 必须通过 | 允许失败 | 待验证 |
|---|---|---:|---:|---:|
| macOS | [599 项](MATERIAL_TESTS.md) | 545 | 54 | 0 |
| Android arm64 模拟器 | [438 项](MATERIAL_TESTS.android.md) | 152 | 6 | 280 |
| iOS arm64 模拟器 | [438 项](MATERIAL_TESTS.ios.md) | 150 | 8 | 280 |

移动端共用 438 个素材用例，通过应用实际使用的 `auto` 路由验证。Android/iOS
各自的 JSON 基线为 `material-tests.android.json`、`material-tests.ios.json`，只从
本平台旧报告提取通过和已知失败，不继承 macOS 的豁免。未实测项标记为
`unverified`：通过记作 `new_pass`；失败记作 `unverified_failure`，整体仍失败，
需要分析原因，不会自动加入允许失败名单。

省略移动端 `--device` 时选择可用模拟器。iOS 当前使用模拟器；物理设备不能
直接使用这份模拟器基线。`run.json` 和总报告记录实际设备及系统版本。
移动端测试使用独立的 `example-wandroid/`、`example-wios/` 构建目录。

Android 通过 `adb reverse` 和只发布已登记素材的 HTTP Range 服务读取主机素材。
光盘/分卷/本地指针文件/外置字幕会下载到应用临时目录，保留文件路径、相邻分卷
和字幕配对语义；截图参考通过 HTTP 读取。测试结束后关闭转发和服务，并清理
设备暂存。iOS 模拟器读取主机素材。两端通过日志回收 `OPX_RESULT` 原始结果，
不依赖设备能写入主机报告目录。

入口统一调用七组素材准备逻辑：基础格式/素材包/外部素材、公开语料、
HDR/Dolby Vision/光盘高级场景、字幕和播放列表、历史修复、分卷和高清音频、ISO。
运行时从当前工作区重新准备素材，不依赖旧 `build/formats` 报告或其中的绝对路径。
历史报告路径仅保留为基线来源。四项依赖临时 Jellyfin 网关 URL 的服务流程检查
在基线 `outside_material_scope` 中列明，需要单独的服务环境，不属于本素材文件入口。

判定规则：

- `pass`：准备成功且实际播放测试通过。失败、缺素材或漏跑任何一项，整体不通过。
- `allow_failure`：允许该项准备失败或播放断言失败；仍逐项记录原因，不计为回归。
  若实际通过，标记为 `improved`，但不会自动改写基线。
- `unverified`：尚无该平台证据；失败不视为已知豁免，仍使整体不通过。
- 整批准备进程失败、Flutter 崩溃/超时、结果缺失/损坏/重复、执行中断均使整体不通过。
- 不自动重试，不自动将回归降级为允许失败。允许失败只匹配清单中的精确 ID、测试组和引擎。

每次运行建立新的 `build/material-tests/<平台>-<时间>/`，写入原始日志、批次结果、基线快照、
`summary.json` 和 `report.md`。退出码 `0` 表示整体通过，`1` 表示测试或执行不通过，
`2` 表示配置错误。macOS 基线不能用于认定 Android/iOS/Linux 的测试通过。

```sh
tool/test_materials.sh --check build/material-tests/<时间>  # 重新核验原始结果，不相信旧摘要
tool/test_materials.sh --platform android --check <Android报告目录>
tool/test_materials.sh --suite public --engine auto --only '*atmos*' # 局部诊断
python3 -m unittest discover -s tool -p 'test_material*.py'
```

局部诊断仍按完整基线判定，未运行项会使整体不通过，不能用于宣称整套通过。
`--check` 会核对基线指纹；基线变化后必须重新运行。已有报告目录不允许复用，
防止旧的通过记录掩盖本次漏跑。新通过项应在核实报告后手动将基线改为 `pass`；
运行失败不会修改基线。

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

### Public corpus regressions

```sh
tool/test_public_corpus.sh --engine auto --source ffmpeg-fate,matroska-test-files
python3 -m unittest discover -s tool -p test_prepare_public_corpus.py
```

Public corpus preparation also decodes the first five seconds of each audio
source with host FFmpeg and the runner's low-pass filter. Playback RMS must be
at least one tenth of that reference; the fixed threshold is retained when a
reference cannot be decoded. This keeps very quiet codec conformance signals
distinct from lost audio. Silent sources still require audio statistics and a
decoded audio track. This check detects missing sound; it is not a waveform
fidelity comparison.

Audio-only clips shorter than one second repeat their original bytes in mpv
during inspection, so even individual DTS/TrueHD packets can be sampled. These
results record `repeated_short_audio`; they verify decoding and output rather
than seek or end timing. Every sample writes an mpv warning/error log beside
its result.

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

- The public AC-4 and MPEG-H 3D Audio samples still need decoders absent from
  the bundled engines. IAMF additionally needs mix-presentation rendering;
  decoding a single dependent sub-stream does not verify IAMF playback.
- `ffmpeg-fate/Today.nuv` is damaged: host FFmpeg reports invalid demux data
  and LZO decompression errors and produces only eight video frames (about
  0.38 s). It cannot reliably satisfy the sustained-playback check. Keep its
  failure visible until an intact NUV playback fixture is available.
- On macOS, playing without an active CoreAudio stream (such as `--aout=afile`
  in these tests or video-only files) triggers App Nap timer coalescing (~10 Hz)
  after ~30–40 s of no user input. The example host app holds a
  `ProcessInfo.beginActivity([.userInitiated, .latencyCritical])` assertion in
  `AppDelegate.swift` so batched runs stay unthrottled (ALL-371).
