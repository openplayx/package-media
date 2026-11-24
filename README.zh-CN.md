# openplayx_media（package-media）

[English](README.md) | 简体中文

[OpenPlayX](https://github.com/openplayx/openplayx) 的播放层：libVLC 和 libmpv 两个引擎统一在 `PlayerBackend` 接口之后，下一步加入按格式选择引擎的路由。

```
OpenPlayX App ─ openplayx_media ─┬─ LibVlcBackend  → package-libvlc → libVLC（VLCKit，自带 FFmpeg）
                                  └─ MpvBackend     → media_kit（Dart 接口、视频组件）
                                                      → 本仓库编译的 libmpv → package-ffmpeg 的 FFmpeg 9.1
```

**只有一份 FFmpeg。** libmpv 由本仓库从锁定版本的源码编译，链接 package-ffmpeg 的 FFmpeg 动态库，与 App 媒体处理（opx_media）用的是同一份。media_kit 自带的预编译原生库由 `libs/media_kit_libs_<平台>_video` 替换。

当前状态：只完成了 macOS（arm64 + x86_64）。iOS、tvOS、Android、Windows、Linux 依次跟进；tvOS 需要自己实现视频组件。

## 目录

| 路径 | 内容 |
|---|---|
| `lib/` | 基于 media_kit 实现 `PlayerBackend` 的 `MpvBackend`；同时导出接口和 `LibVlcBackend` |
| `tool/mpv-deps.tsv` | 锁定的源码：mpv 0.42.0、libplacebo 7.387.0、libass 0.17.5、freetype、harfbuzz、fribidi、glad、jinja2、markupsafe、fast_float、Vulkan-Headers |
| `tool/build_mpv.sh <目标>` | 静态编译依赖，动态编译 libmpv，链接 package-ffmpeg |
| `tool/make_mpv_frameworks.sh`、`tool/ensure_mpv_apple.sh` | 生成通用 `Mpv.xcframework`，FFmpeg 引用指向 package-ffmpeg 的框架 |
| `tool/patches/` | 应用到 mpv 源码的补丁 |
| `libs/media_kit_libs_macos_video` | 替换 media_kit 的 macOS 原生库包，在 `pod install` 时编译 libmpv |
| `example/` | 播放测试的宿主 App |
| `tool/test_formats.sh` | 按引擎运行的文件格式播放测试 |

## 环境要求

同级目录需要有 `../ffmpeg-package`（package-ffmpeg）和 `../package-libvlc`；需要 Xcode、meson、ninja、pkg-config、cmake、python3。首次构建会编译 FFmpeg 和 libmpv（每个架构几分钟），之后按指纹缓存。

## 文件格式播放测试

默认不运行。样本和检查项沿用 package-libvlc（`formats/manifest.json`），可以选择引擎：

```sh
tool/test_formats.sh --engine mpv              # 或 --engine vlc
tool/test_formats.sh --engine mpv --only 'truehd,ast,mp3*'
```

mpv 用空音频输出播放（不出声），用 FFmpeg 的 `astats` 滤镜（先低通，每 50 个编码帧统计一次）测量解码音频的音量和频率，与 1 kHz 正弦音比较。报告位于 `build/formats/<引擎>-<时间>/report.md`。

最新 macOS 结果（74 个生成样本）：mpv 通过 73 个（只有 ASX 不行），libVLC 通过 66 个。libVLC 播不了而 mpv 能播的：TrueHD、AST、Ogg 中的 FLAC、pls/m3u/cue 播放列表、带进度的裸 MPEG-2 视频。两者都不支持 ASX 播放列表。

### 已知问题

- 同一进程中播放过 AC3 之后，Yamaha ADPCM（`.mmf`）解码出的音量会低约 23 dB，原因待查。
- 同一进程中创建过很多播放器后，少数视频会轻微掉帧（远轻于 libVLC 的 ALL-371）。

## 许可

本仓库代码为 MIT（[LICENSE](LICENSE)）。与 FFmpeg（含 x264/x265）一起编译分发时，整体适用 GPL-2.0-or-later。mpv、libplacebo、libass 等依赖适用其各自的许可证。
