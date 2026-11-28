# openplayx_media（package-media）

[English](README.md) | 简体中文

[OpenPlayX](https://github.com/openplayx/openplayx) 的播放层：libVLC 和 libmpv 两个引擎统一在 `PlayerBackend` 接口之后，并由路由（`RoutedPlayerBackend`）为每个媒体选择引擎。

```
OpenPlayX App ─ openplayx_media ─ RoutedPlayerBackend（EngineRouter）
                                  ┌──────────────┘
                                  ├─ LibVlcBackend  → package-libvlc → libVLC（VLCKit，自带 FFmpeg）
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
| Windows（x86_64） | `tool/build_mpv.sh windows-x86_64`（MSYS2、MinGW-w64；CI 在 `flutter build` 前编译） | `libs/media_kit_libs_windows_video`（没有 libmpv 时为空实现） | integration_test（Windows CI 上的关键样本） |

media_kit 和 media_kit_video 在 `forks/` 下各有一份副本（MIT，见 `forks/*/OPENPLAYX.md`）：增加 Apple TV 支持（Dart 层判断，以及从 iOS 移植的 `tvos/` 视频插件）、iOS 15+ AVKit 画中画输出、macOS `MPV_RENDER_PARAM_ADVANCED_CONTROL` 纹理更新，并去掉没有 Apple TV 实现的 `wakelock_plus`（播放时保持屏幕常亮由 App 负责）。

## 引擎路由

```dart
final player = RoutedPlayerBackend();      // 默认的 EngineRouter
await player.open(Uri.file('/media/a.mkv')); // libmpv
await player.open(Uri.file('/media/b.mpc')); // libVLC（Musepack SV7 Seek）
player.engine;                              // MediaEngine.vlc
```

`EngineRouter` 默认把媒体交给 libmpv，包括模块音乐（`.mod`、`.xm`、`.it`、`.s3m` 等，由 package-ffmpeg 的 libopenmpt 解码）、游戏机音乐（`.nsf`、`.gym`、`.spc`、`.vgm` 等，由 package-ffmpeg 的 libgme 解码，`MpvBackend` 会对这些后缀直接指定该解封装器）以及桌面端光盘播放（`libbluray`、`libdvdread`、`libdvdnav`）。显式配置在 `byExtension` 中的后缀（当前为 Musepack 的 `.mpc` / `.mpp` / `.mp+`）以及没有 libmpv 构建的平台（Windows 上指没有打包 `libmpv-2.dll` 的构建）交给 libVLC。选中的引擎在起播前失败时，`RoutedPlayerBackend` 会用另一个引擎再打开一次（`fellBack`）。默认引擎、扩展名表和可用引擎都可以通过构造参数指定。单元测试：`flutter test`。

## 目录

| 路径 | 内容 |
|---|---|
| `lib/` | `RoutedPlayerBackend` 和 `EngineRouter`；基于 media_kit 实现 `PlayerBackend` 的 `MpvBackend`；同时导出接口和 `LibVlcBackend` |
| `tool/mpv-deps.tsv` | 锁定的源码：mpv（`09cf7a11`）、libplacebo 7.387.0、libass 0.17.5、freetype、harfbuzz、fribidi、glad、jinja2、markupsafe、fast_float、Vulkan-Headers、libdvdread 7.1.1、libdvdnav 7.0.0、libbluray 1.5.0 |
| `tool/build_mpv.sh <目标>` | 静态编译依赖，动态编译 libmpv，链接 package-ffmpeg |
| `tool/make_mpv_frameworks.sh`、`tool/ensure_mpv_apple.sh` | 生成通用 `Mpv.xcframework`，FFmpeg 引用指向 package-ffmpeg 的框架 |
| `tool/patches/` | 应用到 mpv 源码的补丁 |
| `libs/media_kit_libs_*` | 替换 media_kit 的各平台原生库包（macOS、iOS、tvOS、Android、Linux、Windows） |
| `forks/` | `media_kit` 和 `media_kit_video` 的本地分支（见 `forks/*/OPENPLAYX.md`） |
| `formats/` | 样本清单、跨平台统一回归基线（`material-tests.json`、`MATERIAL_TESTS*.md`）与测试说明 |
| `example/` | 播放测试的宿主 App |
| `tool/test_materials.sh` | 统一的跨平台素材回归门禁入口（405 项唯一素材，走 `auto` 路由） |
| `tool/test_formats.sh` | 按引擎运行的文件格式播放测试（`auto`、`mpv` 或 `vlc`） |

## 环境要求

同级目录需要有 `../ffmpeg-package`（package-ffmpeg）和 `../package-libvlc`；需要 meson、ninja、pkg-config、cmake、python3；Apple 平台需要 Xcode，Android 需要 `ANDROID_NDK_HOME`；Linux 在同架构的 Linux 主机上编译，或使用 `tool/linux/run.sh`（Docker，Ubuntu 24.04，带 libmpv 动态链接的系统库：Fontconfig、EGL、PulseAudio、ALSA）。tvOS 使用 `../.toolchains/flutter-tvos` 中固定版本的 flutter-tvos（`FLUTTER_TVOS_BIN`）。首次构建会编译 FFmpeg 和 libmpv（每个架构几分钟），之后按指纹缓存。

## 文件格式播放测试

默认不运行。[样本清单](formats/manifest.json)、跨平台素材回归门禁（`tool/test_materials.sh`）、`tool/prepare_samples.py`、两个引擎共用的播放集成测试和报告生成均维护在本仓库。完整说明与基线见 [formats/README.md](formats/README.md)。

### 素材回归门禁（总入口）

```sh
tool/test_materials.sh                                      # 执行完整 macOS 基线（438 项，走 auto 路由）
tool/test_materials.sh --list                               # 列出全部用例，不启动播放器
tool/test_materials.sh --prepare-only                       # 仅检查素材准备流程
tool/test_materials.sh --platform android --device emulator-5554
tool/test_materials.sh --platform ios --device <iPhone 模拟器 ID>
tool/test_materials.sh --check build/material-tests/<目录>   # 按基线重新核验原始结果
```

总入口覆盖七组素材套件（基础格式/素材包/外部素材、公开语料、HDR/Dolby Vision/光盘、字幕与播放列表、历史修复、分卷与高清音频、ISO），全部走 `auto` 路由，并按平台独立基线判定：
- macOS：[438 项](formats/MATERIAL_TESTS.md)（409 必须通过，29 允许失败）
- Android arm64 模拟器：[438 项](formats/MATERIAL_TESTS.android.md)（152 必须通过，6 允许失败，280 待验证）
- iOS arm64 模拟器：[438 项](formats/MATERIAL_TESTS.ios.md)（150 必须通过，8 允许失败，280 待验证）

### 按引擎 / 分组运行

```sh
tool/test_formats.sh --engine auto --pack      # 经过路由，与 App 的播放方式一致
tool/test_formats.sh --engine mpv              # 或 --engine vlc；默认 macOS
tool/test_formats.sh --engine mpv --only 'truehd,ast,mp3*'
tool/test_formats.sh --engine mpv --pack --only 'pack-*'   # 素材包样本
tool/test_formats.sh --engine mpv --device <iOS 模拟器 | emulator-5554 | Apple TV 模拟器>
tool/test_formats.sh --engine auto --device emulator-5554,emulator-5556   # 两个进程
tool/linux/run.sh -- xvfb-run -a bash package-media/tool/test_formats.sh --engine mpv --device linux
tool/test_public_corpus.sh --engine auto --source ffmpeg-fate,matroska-test-files
```

`--pack` 把共享目录 `../materials/playback/` 素材包（ALL-370）中的本地文件加为样本，命名为 `pack-<编号>-<扩展名>`，并标注 Linear 编号；期望值来自 ffprobe 和素材包的 440 Hz 正弦音。素材包的视频是动态测试图案，没有参考画面，这些样本不做截图比对。

`OPX_PARALLEL` 指定测试进程数（Mac Studio 上默认 2）。每个进程使用一份独立的宿主 App 目录（`example-w<N>/`）和一台设备：macOS 共用本机，模拟器需要每个进程一台，用 `--device` 逗号分隔传入（例如再开一台 Android 模拟器：`emulator -avd <avd> -read-only -port 5556`）。原生库在各进程启动前统一编译一次。

Android 设备通过 HTTP 从电脑读取样本（`tool/serve_samples.py` 或 `tool/material_transport.py`，支持 Range），结果打印到日志后收集；Apple TV 运行冒烟测试（起播、尺寸、Seek 后播到结尾、音量和频率，不做截图比对）。

mpv 用空音频输出播放（不出声），用 FFmpeg 的 `astats` 滤镜（先低通，每 50 个编码帧统计一次）测量解码音频的音量和频率，与参考音比较。报告分别位于 `build/material-tests/<平台>-<时间>/report.md`（总入口）或 `build/formats/<引擎>-<时间>/report.md`（单套件）。

### 高级播放回归

在 `../materials/playback` 运行 `python3 build_advanced.py --tsmuxer /path/to/tsMuxeR --download-dv` 准备已登记的素材，再在本仓库运行 `bash tool/test_advanced.sh`。覆盖 HDR10+、Dolby Vision P5/P8.1/P8.4、完整 Blu-ray/DVD 目录及 Web 基础 MP4。可用 `--only 'advanced-bluray,advanced-dvd'` 只执行目录测试；报告写入 `build/formats/advanced-*`，或由 `OPX_REPORT_DIR` 指定。

macOS/Linux 的 mpv 构建静态链接固定版本的 libbluray 1.5.0（附带 libudfread）、libdvdread 7.1.1 和 libdvdnav 7.0.0。仅验收未加密本地目录的主片与 Seek，不提供 BD-J 菜单或解密库。其他平台尚未启用这组依赖；Linux 构建与播放需要独立验证。依赖来源和 SHA-256 在 `tool/mpv-deps.tsv`，许可文本在 `LICENSES/`。

### 已知问题

- 同一进程中播放过 AC3 之后，Yamaha ADPCM（`.mmf`）解码出的音量会低约 23 dB，原因待查。
- 同一进程中创建过很多播放器后，少数视频会轻微掉帧（远轻于 libVLC 的 ALL-371）。
- 公开语料中的 AC-4、MPEG-H 3D Audio 和 IAMF 样本需要当前未内置的解码器/渲染器；`ffmpeg-fate/Today.nuv` 为损坏样本。

## 浏览器播放验证

`tool/web_playback_probe.mjs` 使用 Chrome 检查原生 MP4、原生 HLS 可用性和 MSE/fMP4 的播放进度、解码帧及 Seek。素材读取自 `../materials/playback/fixtures/`，需要 Playwright 和 Chrome。在 package-media 中运行：

```sh
PLAYWRIGHT_MODULE=/path/to/playwright-core/index.mjs \
  node tool/web_playback_probe.mjs /tmp/opx-web-playback.json
```

Chrome 不在默认 macOS 安装路径时可用 `CHROME_PATH` 指定。输出路径参数可省略，默认 `/tmp/opx-web-playback.json`。浏览器验证结果写入指定的输出文件。

## 许可

本仓库代码为 MIT（[LICENSE](LICENSE)）。与 FFmpeg（含 x264/x265）一起编译分发时，整体适用 GPL-2.0-or-later。mpv、libplacebo、libass 等依赖适用其各自的许可证。
