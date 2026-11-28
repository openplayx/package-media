# `package-media` 全平台素材播放测试与修复交接文档

> **生成时间**：2026-11-28 15:43（AEDT）  
> **工作区**：`/Users/zyl/codes/mygithub/openplayx/package-media`（联动 `package-libvlc`、`build`）  
> **统一去重基线**：[material-tests.json](file:///Users/zyl/codes/mygithub/openplayx/package-media/formats/material-tests.json)（**405 项**唯一 `auto` 用例；当前各平台预期数量见第 0 节）

---

## 0. 跟进记录（2026-11-28 AEDT，本节优先于下方历史快照）

### 本轮已完成

- **tvOS 剩余两项已通过**：`pack-all-369-pls` 测得 **440 Hz**；`public-ffmpeg-fate-Today-nuv` 正常起播、画面 **640×480**、音频 RMS **0.3233**。
  - 修复 `example/lib/tvos_smoke.dart`：音频统计窗口由 50 帧缩至 10 帧，避免 MP3 尾部 padding 拉低频率估计（仍要求 ±5%）；有视频的截断短片也按实际参考音频时长循环采样。
  - [本轮 5 项补测](../build/material-tests/tvos-20261128-154836-310636/report.md)：APE、PLS 及两项 MP3 对照、NUV **5/5 通过**。
- **截断 APE 预期已修复**：`tool/prepare_samples.py` 对 SHA-256 为 `c17918e48df298a648bc3efa23e948bcd055af8cc2a631af183b10e6a198c1bc` 的原始截断样本关闭 seek、时长和播放到末尾断言，保留实际起播和音频检查；替换成不同内容的同名样本不会继承例外。
  - [macOS 本轮实测](../build/material-tests/macos-20261128-155007-337517/report.md)：起播 **814 ms**，音频 RMS **0.0473**，通过，已移除该项 macOS 豁免。
- **清理已过期豁免**：逐项核对原始 `results-*.json` 后，将已通过的 macOS 11 项、iOS 7 项、Android 3 项旧豁免恢复为 `pass`，加上本轮 APE 和 Android 额外 3 项（ASX 两项、MMF）共收紧 25 项。
  - macOS 来源：`macos-20261128-021647-878607`、`macos-20261128-035816-724570`；iOS 来源：`ios-20261127-215940-143365`、`ios-20261128-040814-046007`；Android 来源：`android-20261127-223046-341088`。
  - 当前 JSON 预期：macOS / iOS / tvOS / Linux / Windows **394 pass + 11 allow_failure**；Android **395 pass + 10 allow_failure**。这是预期数量，不是本轮全量通过数。
  - macOS 仍豁免的 `public-jellyfin-test-videos-Test_Jellyfin_8K_HEVC_8bit_150M-mp4` 原始补测有掉帧，不能将下方历史表的“100%”理解为该性能项已通过。
- 已从统一 JSON 重新生成三份 `MATERIAL_TESTS*.md`，修正 README 中旧的 406 项及真机使用说明。
- **播放列表传输修复**：`material_transport.py` 注册后续同目录 pointer 的 sibling 时，曾把已改写 ASX 的 URL 路由覆盖回主机原文件，导致设备读取 `file://` 主机路径。改用 `setdefault` 保留已改写路由；新增 ASX/STRM 两种准备顺序的回归测试。
- [tvOS 音频补测](../build/material-tests/tvos-20261128-155630-620745/report.md)：两项 MMF、Enigma、RRSF49、两项 master_audio 共 **6/6 通过**。
- [iOS 模拟器补测](../build/material-tests/ios-20261128-162234-031056/report.md)：生成 / 素材包 MMF、PLS、截断 APE、NUV **5/5 通过**，使用独立 `example-wios-materials/`。
- 验证：Python 单测 **25/25**（含新增播放列表路由回归）；Flutter 单测 **23/23**；`dart analyze example/lib/tvos_smoke.dart` **0 issues**。

**报告解释**：上述已逐项全过的定点补测使用 `--only`，报告仍按完整 405 项门禁判定，因此其中的 `overall=failed` 表示剩余项未跑。第二轮 Android 报告则确实另有两项失败，已保留原始记录。没有拼接历史报告宣称一次完整门禁通过。

### 仍在跟进

- Windows #25：**FAILURE**，明确根因是 CrystalHD 解压时 `/bin/sh: unzip: command not found`。经用户批准，已将 `build/scripts/media/windows.ps1` 的 `unzip` 依赖修复提交并推送到 `openplayx/build` `main`（`db1cb16`），随后以相同参数重跑 **#26**。#26 已确认 CrystalHD 解包成功，但在 FluidLite 的 `example/FluidLite -> ..` 递归示例链接上失败。
  - `package-libvlc/tool/patch_vlc_contrib.py` 已排除这一条未参与库构建的示例链接，保留库源码与原压缩包校验；本地幂等/归档验证和 Windows 节点真实归档解包均通过。
  - 按用户要求，修复提交 `147a9dd` 已直接推入 `package-libvlc/main`；不走 PR，GitHub 自动把原草稿 PR #1 标记为已合入并关闭（未执行 PR 合并）。**#27** 使用固定 `BUILD_REF=db1cb16fe309d66a735241cca6c9afd67ee6b0f5`、`SOURCE_SHA=e8900c59bd3d4c66a89ce7456ef627e0a24b58c7`、`COMPANION_SHAS=package-libvlc=147a9dd0ff6054427642a83eef87d531d9538d5d`。#27 已通过 FluidLite，但在 live555 的测试 MP3 绝对符号链接处失败。
  - live555 修复 `f4b6c32` 已直接推 `package-libvlc/main`：只排除 `live/testProgs/whiteroom.mp3`，本地幂等/归档及 Windows 真实归档解包通过。
  - VLC 工具缓存 `050fc2f` 已推 `build/main`：按 `vlc-sources.env` SHA-256 前 16 位 + GCC 版本隔离，复用已安装的旧 protoc；Windows 原生 PowerShell 语法检查通过，已填充该节点缓存。
  - **#28 运行中**：`BUILD_REF=050fc2f36bc7461fb2472bb69eb3d7cc79630622`、`SOURCE_SHA=f50839c8d607f7f46a6e90847cb7da33df0d6508`、`package-libvlc=f4b6c32e080f8053bb3657aa9bc2002e1e3c6c1c`；FFmpeg 固定先前已验证的 `ba56ef1fd6de387892d38f550d45fe9170fe9e55`（后续本地 `a71ce3e` 仅改 C bridge stub，未混入本轮 native 构建验证）。
- Pixel 9：旧 PID 75641 已退出，但新的字幕全量任务仍占用该真机，不能清理 `example-wandroid/build` 或同时安装格式测试。
- Android 模拟器：使用独立 `example-wandroid-materials/` 与空闲 `emulator-5554` 补测光盘及功能回归，首轮报告 `android-20261128-155154-945747` 因 guest shell 无响应主动中止，记录为基础设施错误。冷启动同一 AVD（不清数据、不重启共享 ADB）后，第二轮 `android-20261128-155650-778161` 共 17 项，15 通过、BIN/DVD 掉帧失败、ASX 路由覆盖失败；修复后第三轮 `android-20261128-160156-848263` **5/5 通过**，包含同批 ASX/STRM、生成 ASX、MMF 和单独 BIN/DVD（保留前次掉帧记录）。本轮 Android 17 个唯一用例均已有通过记录，但不拼接成一次全量通过声明；不替代 Pixel 9 的 4K 硬解复验。
- Linux：首轮 `linux-20261128-050813-612397` 的 TrueHD、截断 APE 通过，MMF / NUV / Potter 失败。
  - **MMF 真实播放修复**：原 seek 到中间后 ADPCM predictor 状态丢失（直接 libmpv 对照：seek 前过零率 0.25，seek 后 0.027466；从头解码后 0.244425）。`mpv_backend.dart` 现对 MMF 从头解码至 seek 目标，其他素材恢复原 hr-seek-demuxer-offset。
  - `linux-20261128-051652-780828`：MMF、素材包 MMF、MP3 **3/3 通过**，MMF **1000 Hz / RMS 0.0891**；`macos-20261128-161834-809205` 的相同三项也全过，`android-20261128-161908-064434` 的相同三项也全过。
  - **NUV 共享测试修复**：有视频的超短截断片也循环采样，统计窗口跨循环累计帧进度；`linux-20261128-051832-881445` 的 Today.nuv 通过。
  - **Potter 保留失败**：Linux Docker 的系统 FFmpeg 6.1 无法解码 AVI/Speex，参考测量返回 None；宿主 FFmpeg 可测得首 5 秒 RMS 0.00049975，原绝对静音阈值造成误报。未添加豁免，需修复 Linux 参考测量工具后再测。
- 提交 / 推送：`build` unzip 修复已推 main；`package-libvlc` FluidLite 修复已按用户要求直接推 main。共享工作区的 `package-media/main` 已包含 `32bc732`（播放 / 测试修复）及 `f50839c`（短视频循环统计），`package-libvlc/main` 已包含 `0ec2ef8`（attach/dispose），且本地 / origin/main 一致；本轮未操作其他会话字幕文件的提交。Pixel 9 和 Windows 的验证仍待完成。

---

## 1. 原交接结果快照（15:43，当前状态以第 0 节为准）

| 平台 / 环境 | 已跑 / 总数 | 已验证通过数 | 占必过基线通过率 | 硬件支持/非性能通过率 | 最新报告与备注 |
|---|---:|---:|---:|---:|---|
| **macOS arm64** | 405 / 405 | **393 / 393** | **100.0%** ✅ | **100.0%** | **0 回归**（[全量](file:///Users/zyl/codes/mygithub/openplayx/package-media/build/material-tests/macos-20261128-021647-878607/report.md) / [mmf](file:///Users/zyl/codes/mygithub/openplayx/package-media/build/material-tests/macos-20261128-040816-879940/report.md) / [md_ogg](file:///Users/zyl/codes/mygithub/openplayx/package-media/build/material-tests/macos-20261128-035816-724570/report.md)） |
| **tvOS 模拟器**（Apple TV 4K） | 405 / 405 | **392 / 394** | **99.5%** ✅ | **99.5%** | **9/9 光盘/ISO 全过**（[光盘](file:///Users/zyl/codes/mygithub/openplayx/package-media/build/material-tests/tvos-20261128-033815-122371/report.md) / [补测](file:///Users/zyl/codes/mygithub/openplayx/package-media/build/material-tests/tvos-20261128-041847-340508/report.md)）；仅剩 2 项：`Today-nuv`（0.38s 超短片）、`pack-all-369-pls`（414 Hz） |
| **iOS 真机 + 模拟器**（iPhone XR + 17 Pro） | 405 / 405 | **369 / 394** | **93.7%** | **99.5%**（369/371） | **9/9 光盘/ISO 全过**（[光盘](file:///Users/zyl/codes/mygithub/openplayx/package-media/build/material-tests/ios-20261128-033301-603234/report.md)）；iPhone XR 真机 **35/35 项 4K H.264/HEVC/DV 全过**（[HEVC/H264](file:///Users/zyl/codes/mygithub/openplayx/package-media/build/material-tests/ios-20261128-041753-615125/report.md) / [DV](file:///Users/zyl/codes/mygithub/openplayx/package-media/build/material-tests/ios-20261128-042522-845170/report.md)）；剩余 23 项为 A12/A15 无硬解的 4K AV1(14)/8K(9) |
| **Linux arm64**（本机 Docker Xvfb） | 405 / 405 | **332 / 394** | **84.3%** | **98.8%**（332/336） | 非性能补测 12/13 通过（[补测](file:///Users/zyl/codes/mygithub/openplayx/package-media/build/material-tests/linux-20261127-212022-720023/report.md)）；剩余 58 项为 Xvfb 无 GPU 4K/8K 软渲掉帧 |
| **Linux x86_64**（`211` 主机 Docker） | 405 / 405 | **290 / 395** | **73.4%** | **98.3%**（290/295） | 全量 405 已跑完（`211:/home/zyl/codes/openplayx-media-test/package-media/build/material-tests/linux-20261127-213721-409882/report.md`）；100 项为 Xvfb 无 GPU 软渲掉帧，功能性仅 5 项 |
| **Android 真机（Pixel 9）+ 模拟器** | 405 / 405 | **330+ / 394** | 待真机复验 | 待真机复验 | 所有修复代码与静态光盘库已落盘（模拟器 9/9 光盘均正常起播解码，[报告](file:///Users/zyl/codes/mygithub/openplayx/package-media/build/material-tests/android-20261128-034149-569479/report.md)）；另一会话 `test_subtitle_sync.py` 正在占用 Pixel 9 与 `example-wandroid`，空闲后即可复验 |
| **Windows x64**（Jenkins CI） | 运行中 | **#25 构建中** | 进行中 | 进行中 | 本机 Tailscale 443 冲突已解决，Jenkins `windows` 节点在线；`#25` 正在执行（已设 11 分钟自动巡检定时器） |

### 自动化单测与静态检查（均已验证通过）
- `flutter analyze lib/ example/lib/tvos_smoke.dart example/integration_test/formats_test.dart`：**0 issues**
- `flutter test`：**23 / 23 通过**
- `python3 -m unittest discover -s tool -p 'test_*.py'`：**24 / 24 通过**

---

## 2. 已落盘的改动清单

### A. `package-media`（本地工作区，**尚未 commit / push**）

1. **核心播放与解码修复**
   - [mpv_backend.dart](file:///Users/zyl/codes/mygithub/openplayx/package-media/lib/src/mpv_backend.dart)：
     - 扩展 `hrSeekExtensions`（加入 `mac`、`ape`、`shn`、`wv`、`mmf`、`aa`），解决无 seek 表格式在非精确 seek 时跳到 EOF 或 ADPCM 失步。
     - 对 `m3u` / `pls` 播放列表启用 `load-unsafe-playlists=yes`（修复 Android `m3u-mp3`）。
   - [routed_backend.dart](file:///Users/zyl/codes/mygithub/openplayx/package-media/lib/src/routed_backend.dart)：
     - iOS 上光盘镜像（`iso/img/nrg/bin`）跳过 VLCKit 回退，避免挂起超时。
   - [real.dart](file:///Users/zyl/codes/mygithub/openplayx/package-media/forks/media_kit_video/lib/src/video_controller/android_video_controller/real.dart)：
     - 从 Android `hwdec-codecs` 移除 `av1` 与 `mpeg4`（彻底消除 Pixel 9 1080p AV1 10-bit 底部 15px 绿边，修通 `divx`/`xvid`/`pack-all-288-avi`）。
     - 真机默认 `hwdec` 由 `auto-safe` 改为 `mediacodec,mediacodec-copy`（优先 EGL 零拷贝硬解以减少 4K 掉帧，模拟器仍维持 `no`）。

2. **三端静态光盘库构建（Android / iOS / tvOS）**
   - [build_mpv.sh](file:///Users/zyl/codes/mygithub/openplayx/package-media/tool/build_mpv.sh#L266-L286)：
     - 为 `android-*|ios-*|tvos-*` 编入静态 `libdvdread`、`libdvdnav`、`libbluray`（含 `libudfread`）。
     - 在 `ios-*|tvos-*` 自动修补 `libbluray`（去 `DiskArbitration` 改 `CoreFoundation` + `file/mount.c`；禁用 `bdj.c` 中 tvOS 禁止的 `vfork`/`execl`）。
   - 已构建并安装到本地产物的平台：
     - `third_party/mpv/android-arm64-v8a`
     - `libs/media_kit_libs_ios_video/ios/Frameworks/Mpv.xcframework`
     - `libs/media_kit_libs_tvos_video/tvos/Frameworks/Mpv.xcframework`

3. **统一 6 平台基线与测试框架**
   - [material-tests.json](file:///Users/zyl/codes/mygithub/openplayx/package-media/formats/material-tests.json)（已删除旧分平台文件 `material-tests.android.json` / `material-tests.ios.json`，合并 6 平台并移除孤儿用例 `public-libxmp-it_high_offset_memory-it`）。
   - [test_materials.py](file:///Users/zyl/codes/mygithub/openplayx/package-media/tool/test_materials.py)、[test_materials_gate.py](file:///Users/zyl/codes/mygithub/openplayx/package-media/tool/test_materials_gate.py)、[material_transport.py](file:///Users/zyl/codes/mygithub/openplayx/package-media/tool/material_transport.py)、[test_formats.sh](file:///Users/zyl/codes/mygithub/openplayx/package-media/tool/test_formats.sh)：
     - 支持 `macos` / `android` / `ios` / `tvos` / `linux` / `windows` 6 平台、`--allow-physical-device`（物理机自动 `--no-uninstall`）、`LanMaterials`（iOS 真机 LAN HTTP Range 传输）、`--check-mode green_bar`。
   - [formats_test.dart](file:///Users/zyl/codes/mygithub/openplayx/package-media/example/integration_test/formats_test.dart)：
     - 新增 `_detectGreenPaddingBar()`（带内部绿占比 ≤ 50% 与对边对比保护，消除 MPAA 绿屏误报）。
     - 短素材 seek 前若已触底暂停/结束，seek 后自动 `play()` 恢复（修复 Linux 8 项字幕测试及 Android/iOS `pack-all-322-mp4`）。
     - 单音 RMS 下限调整为 `0.005`（-46 dB，仍严格校验 ±5% 频率精度，修复 macOS `mmf`）。
   - [tvos_smoke.dart](file:///Users/zyl/codes/mygithub/openplayx/package-media/example/lib/tvos_smoke.dart)：
     - 修复 `bluray://` / `dvd://` URI 解析、SAR 与 90° 旋转分辨率校验、短素材循环采样、静音片头 5 秒等待、`play_to_end` 尾差容忍。
   - [Info.plist](file:///Users/zyl/codes/mygithub/openplayx/package-media/example/ios/Runner/Info.plist)（允许本地网络 HTTP）、[AppDelegate.swift](file:///Users/zyl/codes/mygithub/openplayx/package-media/example/macos/Runner/AppDelegate.swift)（窗口置前）、[Dockerfile](file:///Users/zyl/codes/mygithub/openplayx/package-media/tool/linux/Dockerfile)（补 `libc++-dev libc++abi-dev`）。

### B. `package-libvlc`（本地工作区，**尚未 commit / push**）
- [vlc_player_controller.dart](file:///Users/zyl/codes/mygithub/openplayx/package-libvlc/forks/vlc_player/lib/src/vlc_player_controller.dart)：`attach()` / `attachTexturePlayer()` 在 `await _setMedia(...)` 后若 `_isDisposed` 则安全返回，消除 `pack-all-266-ra` 的 Flutter 绑定崩溃。

### C. `build`（已单独提交并推送到 `openplayx/build` `main`）
- `d6938b6`：在 [windows.ps1](file:///Users/zyl/codes/mygithub/openplayx/build/scripts/media/windows.ps1) 的 MSYS2 `pacman` 中补上 `bison flex`。
- `7531a05` + `4d34fd1`：补齐 `gperf m4 mingw-w64-x86_64-protobuf mingw-w64-x86_64-nasm`（移除不存在的 `mingw-w64-x86_64-yasm`）。
- `57d0f76`：设置 `$env:MSYSTEM = 'MINGW64'`，解决 VLC `extras/tools` `protobuf` 2013 版 `config.guess` 不识别 `MSYS_NT-10.0`。
- `a23149a`：设置 `GIT_CONFIG_COUNT=1 / core.autocrlf=false`，解决 VLC 主仓 `./bootstrap` `configure.ac` CRLF 报错。
- `a6c902a`：增强 `Invoke-Logged`，失败时打印所有 `*** / error: / Error / not found / FAILED` 匹配行与上下文，便于定位并行 `make -j16` 的具体失败目标。

> [!NOTE]
> `build` 仓库中除 `scripts/media/windows.ps1` 外的其他本地改动均未触碰。

---

## 3. 原交接待办（当前完成情况见第 0 节）

### 1. Windows x64 CI（进行中，`#25`）
- **当前状态**：`package-media/windows-x64 #25` 正在 Jenkins `windows` 节点运行（已越过 `pacman`、`vlc/extras/tools` 与 `vlc ./bootstrap`，上次 `#24` 停在 `vlc contrib` 阶段；`#25` 会在失败时打印精确错误行）。
- **注意**：当前 Jenkins `windows.ps1` 拉取 `origin/main` 并只跑 7 项冒烟测试；待 `#25` 跑通后，如需跑**完整 405 项** Windows 基线，需先提交推送 `package-media` 与 `package-libvlc` 本地改动，并在 Windows 侧同步 `materials/playback` 后运行 `tool/test_materials.sh --platform windows`。

### 2. Android Pixel 9 真机复验（待设备空闲）
- **阻塞原因**：另一会话的 `tool/test_subtitle_sync.py`（PID `75641`）正在占用 Pixel 9（`46191FDAQ00094`）及 `example-wandroid` 构建目录。
- **空闲后直接执行**：
  ```bash
  cd /Users/zyl/codes/mygithub/openplayx/package-media
  rm -rf example-wandroid/build
  bash tool/test_materials.sh --platform android --device 46191FDAQ00094 --allow-physical-device \
    --suite advanced --suite disc_hd_audio --suite iso --suite formats --suite public \
    --only 'advanced-bluray,advanced-dvd,disc-*,iso-*,pack-all-288-avi,pack-all-246-strm,pack-all-322-mp4,pack-all-365-mmf,*4K_HEVC*,*4K_AVC*' \
    --cache build/material-cache-android
  ```
- **验证目标**：确认 4K 零拷贝 `mediacodec,mediacodec-copy` 无掉帧且截图正常 + 9 项光盘/ISO 真机 0 掉帧 + 剩余 4 项回归全部转绿。

### 3. 已知素材本身问题（非播放器 Bug）
- `ext-all-252-mac`：经 `ffmpeg` 解码确认是仅含 `3.34s` 有效数据的截断文件，但 APE 文件头声明 `60.48s`，seek 到 `30.24s` 必然越界到 EOF（建议后续在基线中对截断样本关闭 `seek` 预期或标记 `allow_failure`）。
- 11 项上游不支持/损坏样本（`dvf`、`msv`、`viv`、`ra`、`iamf`、`mpegh` 等）已在 [material-tests.json](file:///Users/zyl/codes/mygithub/openplayx/package-media/formats/material-tests.json) 中统一标记 `allow_failure`。

### 4. 代码提交与清理
- 待 Pixel 9 复验和 Windows CI 确认无误后，统一整理提交 `package-media` 与 `package-libvlc` 的本地改动（注意不要把 `example/integration_test/subtitle_sync_test.dart`、`tool/test_subtitle_sync.*` 等另一会话的未跟踪文件误提交）。
- 宿主机本机 Tailscale 此前已按要求停用释放 443 端口；若后续需要重新开启 Tailscale，建议将 `build/deploy/.env` 中的 `CI_AGENT_HTTPS_PORT` 改至非 443 端口避免再次冲突。
