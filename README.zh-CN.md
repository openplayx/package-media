# openplayx_media（package-media）

[English](README.md) | 简体中文

[OpenPlayX](https://github.com/openplayx/openplayx) 的播放层：libVLC 和 libmpv 两个引擎统一在 `PlayerBackend` 接口之后，下一步加入按格式选择引擎的路由。

```
OpenPlayX App ─ openplayx_media ─┬─ LibVlcBackend  → package-libvlc → libVLC（VLCKit，自带 FFmpeg）
                                  └─ MpvBackend     → media_kit（Dart 接口、视频组件）
                                                      → 本仓库编译的 libmpv → package-ffmpeg 的 FFmpeg 9.1
```

**只有一份 FFmpeg。** libmpv 由本仓库从锁定版本的源码编译，链接 package-ffmpeg 的 FFmpeg 动态库，与 App 媒体处理（opx_media）用的是同一份。media_kit 自带的预编译原生库由 `libs/media_kit_libs_<平台>_video` 替换。

| 平台 | libmpv 构建 | media_kit 原生库包 | 格式测试 |
|---|---|---|---|
| macOS（arm64、x86_64） | `tool/ensure_mpv_apple.sh macos` | `libs/media_kit_libs_macos_video` | integration_test |
| iOS（真机、模拟器） | `tool/ensure_mpv_apple.sh ios` | `libs/media_kit_libs_ios_video` | integration_test（模拟器） |
| tvOS（真机、模拟器） | `tool/ensure_mpv_apple.sh tvos` | `libs/media_kit_libs_tvos_video` + `forks/` | 通过 flutter-tvos 运行 `example/lib/tvos_smoke.dart` |
| Android（arm64-v8a、armeabi-v7a、x86_64） | `tool/ensure_mpv_android.sh`（Gradle 调用） | `libs/media_kit_libs_android_video` | integration_test，样本通过 HTTP 提供 |
| Linux（x86_64、arm64） | `tool/build_mpv.sh linux-<架构>`（CMake 调用） | `libs/media_kit_libs_linux` | Xvfb 下的 integration_test（`tool/linux/run.sh`） |
| Windows | 尚未完成 | – | – |

media_kit 和 media_kit_video 在 `forks/` 下各有一份副本（MIT，见 `forks/*/OPENPLAYX.md`）：增加 Apple TV 支持（Dart 层判断，以及从 iOS 移植的 `tvos/` 视频插件）；media_kit_video 去掉了没有 Apple TV 实现的 wakelock_plus，播放时保持屏幕常亮由 App 负责。

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

同级目录需要有 `../ffmpeg-package`（package-ffmpeg）和 `../package-libvlc`；需要 meson、ninja、pkg-config、cmake、python3；Apple 平台需要 Xcode，Android 需要 `ANDROID_NDK_HOME`；Linux 在同架构的 Linux 主机上编译，或使用 `tool/linux/run.sh`（Docker，Ubuntu 24.04，带 libmpv 动态链接的系统库：Fontconfig、EGL、PulseAudio、ALSA）。tvOS 使用 `../.toolchains/flutter-tvos` 中固定版本的 flutter-tvos（`FLUTTER_TVOS_BIN`）。首次构建会编译 FFmpeg 和 libmpv（每个架构几分钟），之后按指纹缓存。

## 文件格式播放测试

默认不运行。样本和检查项沿用 package-libvlc（`formats/manifest.json`），可以选择引擎：

```sh
tool/test_formats.sh --engine mpv              # 或 --engine vlc；默认 macOS
tool/test_formats.sh --engine mpv --only 'truehd,ast,mp3*'
tool/test_formats.sh --engine mpv --device <iOS 模拟器 | emulator-5554 | Apple TV 模拟器>
tool/linux/run.sh -- xvfb-run -a bash package-media/tool/test_formats.sh --engine mpv --device linux
```

Android 设备通过 HTTP 从电脑读取样本（`tool/serve_samples.py`，支持 Range），结果打印到日志后收集；Apple TV 运行冒烟测试（起播、尺寸、Seek 后播到结尾、音量和频率，不做截图比对）。

mpv 用空音频输出播放（不出声），用 FFmpeg 的 `astats` 滤镜（先低通，每 50 个编码帧统计一次）测量解码音频的音量和频率，与 1 kHz 正弦音比较。报告位于 `build/formats/<引擎>-<时间>/report.md`。

最新 macOS 结果（74 个生成样本）：mpv 通过 73 个（只有 ASX 不行），libVLC 通过 66 个。libVLC 播不了而 mpv 能播的：TrueHD、AST、Ogg 中的 FLAC、pls/m3u/cue 播放列表、带进度的裸 MPEG-2 视频。两者都不支持 ASX 播放列表。

### 已知问题

- 同一进程中播放过 AC3 之后，Yamaha ADPCM（`.mmf`）解码出的音量会低约 23 dB，原因待查。
- 同一进程中创建过很多播放器后，少数视频会轻微掉帧（远轻于 libVLC 的 ALL-371）。

## 许可

本仓库代码为 MIT（[LICENSE](LICENSE)）。与 FFmpeg（含 x264/x265）一起编译分发时，整体适用 GPL-2.0-or-later。mpv、libplacebo、libass 等依赖适用其各自的许可证。
