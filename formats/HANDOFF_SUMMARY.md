# `package-media` 全平台素材播放测试与修复交接文档

> **生成时间**：2026-11-28 15:43（AEDT）  
> **跟进时间**：2026-11-28 21:40（AEDT）
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
- **完整 Windows 门禁启动修复**（`79e546d` 已推 main）：`test_materials.sh` 在 MSYS2 使用原生 MinGW Python，`test_materials.py` 解析 Flutter BAT 的完整路径，避免 WinError 2 与 Unix 路径传给 Windows Dart。主进程及素材准备子进程均显式启用 UTF-8。
  - Windows 节点独立诊断目录已通过实际 MP3 准备、原生 `C:/...` 路径校验、中文 JSON 与中文缓存目录校验；只代表准备流程通过，不是播放通过。
- 验证：Python 单测 **25/25**（含新增播放列表路由回归）；Flutter 单测 **23/23**；`dart analyze example/lib/tvos_smoke.dart` **0 issues**。

**报告解释**：上述已逐项全过的定点补测使用 `--only`，报告仍按完整 405 项门禁判定，因此其中的 `overall=failed` 表示剩余项未跑。第二轮 Android 报告则确实另有两项失败，已保留原始记录。没有拼接历史报告宣称一次完整门禁通过。

### 仍在跟进

- Windows #25：**FAILURE**，明确根因是 CrystalHD 解压时 `/bin/sh: unzip: command not found`。经用户批准，已将 `build/scripts/media/windows.ps1` 的 `unzip` 依赖修复提交并推送到 `openplayx/build` `main`（`db1cb16`），随后以相同参数重跑 **#26**。#26 已确认 CrystalHD 解包成功，但在 FluidLite 的 `example/FluidLite -> ..` 递归示例链接上失败。
  - `package-libvlc/tool/patch_vlc_contrib.py` 已排除这一条未参与库构建的示例链接，保留库源码与原压缩包校验；本地幂等/归档验证和 Windows 节点真实归档解包均通过。
  - 按用户要求，修复提交 `147a9dd` 已直接推入 `package-libvlc/main`；不走 PR，GitHub 自动把原草稿 PR #1 标记为已合入并关闭（未执行 PR 合并）。**#27** 使用固定 `BUILD_REF=db1cb16fe309d66a735241cca6c9afd67ee6b0f5`、`SOURCE_SHA=e8900c59bd3d4c66a89ce7456ef627e0a24b58c7`、`COMPANION_SHAS=package-libvlc=147a9dd0ff6054427642a83eef87d531d9538d5d`。#27 已通过 FluidLite，但在 live555 的测试 MP3 绝对符号链接处失败。
  - live555 修复 `f4b6c32` 已直接推 `package-libvlc/main`：只排除 `live/testProgs/whiteroom.mp3`，本地幂等/归档及 Windows 真实归档解包通过。
  - VLC 工具缓存 `050fc2f` 已推 `build/main`：按 `vlc-sources.env` SHA-256 前 16 位 + GCC 版本隔离，复用已安装的旧 protoc；Windows 原生 PowerShell 语法检查通过，已按 Windows CRLF 文件实际哈希补齐该节点缓存，缓存 protoc 运行验证通过；#29 日志确认 `using cached VLC tools` 命中。
  - **#29 已失败，后续已运行至 #33**（#28 因首次缓存预填使用本机 LF 键而未命中 Windows CRLF 键，核实并补齐实际键后主动停止，以相同提交启动 #29）：`BUILD_REF=050fc2f36bc7461fb2472bb69eb3d7cc79630622`、`SOURCE_SHA=f50839c8d607f7f46a6e90847cb7da33df0d6508`、`package-libvlc=f4b6c32e080f8053bb3657aa9bc2002e1e3c6c1c`；FFmpeg 固定先前已验证的 `ba56ef1fd6de387892d38f550d45fe9170fe9e55`（后续本地 `a71ce3e` 仅改 C bridge stub，未混入本轮 native 构建验证）。
  - #29 已通过 CrystalHD / FluidLite / live555，随后 AS-DCP 因 Nettle 4 移除 SHA-1 digest 长度参数而编译失败。兼容修复 `c587c44` 已推 `package-libvlc/main`，保留 Nettle 3 分支并使用完整摘要长度；干净应用/幂等检查、Linux Nettle 3 和 Windows Nettle 4 的已知摘要向量均通过。
  - **#30 固定提交**：`SOURCE_SHA=bb282527324fc212b1e0e9f2059e95d52873a482`、`package-libvlc=c587c4433f9e21e23798214288c7b2a5b4345080`；build / FFmpeg 固定提交同前。#30 确认 AS-DCP 构建并安装成功，但旧 GNU regex 在 GCC 16 默认 C23 模式下编译失败。
  - GNU C17 构建模式修复 `94f5c72` 已推 `package-libvlc/main`：保留默认优化选项，仅 Windows 固定旧 VLC/contrib 的 C 语言版本。Windows 真实 regex 对象已成功复编，链接后的匹配 / 拒绝运行测试通过。
  - **#31 固定提交**：`package-libvlc=94f5c72d23afffcbc65d472129369b5f2faf132a`，其余固定提交同 #30。#31 的 regex 旧 Makefile 硬编码 `CFLAGS=-g`，覆盖了全局 C17；其余已处理目标正常。
  - 显式传递 CFLAGS 的 recipe 修复 `44559ce` 已推 `package-libvlc/main`。在失败工作区独立执行修复后的完整 `.regex` 目标，配置 / 编译 / 归档 / 安装均通过（`touch .regex`），没有将该独立验证算作 #31 通过。
  - Windows 文件 / 光盘 URI 修复 `fe4dbeb` 已推 `package-media/main`：盘符路径使用 `Uri.file`；光盘目录从 `Path.as_uri()` 保留 `/C:/`。Windows 独立原生素材准备及 Dart 文件系统还原检查通过。
  - **#32 固定提交**：`SOURCE_SHA=fe4dbeb06415287614f07211d95f446f4a7dc9bd`、`package-libvlc=44559ce33bff1f565e78d8b1ca70a2d94e4e6a29`，build / FFmpeg 提交同前。该轮已通过 regex，随后 FluidSynth 的 gentables 嵌套 CMake 编译器探测路径达到 263 字符，归档工具因 Windows MAX_PATH 失败。
  - 短物理源码路径修复已推 main：`package-libvlc=c7ca4da2e690bb336d4a95ec6cc4cdc5e4cc422d`、`build=9e2337bb94a4deaeb6500a6de4d98ad30054ccfd`。源码放在按 recipe / 编译器 / 包版本 / 工作区 / 编译选项隔离的 `C:/ci/cache/native/vlc-src/<16位哈希>`；未关闭 FluidSynth 或编译器检查。Windows 独立 gentables 配置 / 编译 / 两份表头生成通过，PowerShell 语法检查通过。
  - **#33 固定提交**：SOURCE_SHA / FFmpeg 同 #32，BUILD_REF / package-libvlc 使用上述短路径修复提交。实际源码目录 `C:/ci/cache/native/vlc-src/8bc964eb9f39d1de`。该轮确认 FluidSynth 完整编译 / 安装成功，后续 SID 的 `all-local` 与 `libresidc.la` 并行竞态导致 MSYS2 `ln -sf` 复制未生成的文件，最终 FAILURE；其余依赖收尾完成，未进入播放测试。
  - SID 构建顺序修复 `97b1245e1f3156eee436fa2e4228853da9fa1086` 已推 `package-libvlc/main`：`all-local` 明确依赖 `libresidc.la`，保留 SID 功能。补丁干净应用 / 幂等检查通过；首次隔离原生验证在自动生成配置阶段主动停止，避免诊断日志占用下一轮清理的旧工作区，未计为原生验证通过。随后确认 #33 已结束、#34 使用不同目录 `19abb7fed9b7b4c6`，在闲置旧缓存独立恢复 SID 并行构建 / 安装，退出码 **0**，日志 `C:/ci/cache/native/vlc-src/probe-sid-order/sid-resume.log`，包含 `PASS_SID_resume_parallel_build_install`。不将独立结果算作 #33 通过。
  - **#34 已失败**：`SOURCE_SHA=71ab0742c163e1b71cf61bd066ed6a0052ad1ac8`、`package-libvlc=97b1245e1f3156eee436fa2e4228853da9fa1086`；BUILD_REF / FFmpeg 同 #33。失败点为 VLC 主库 configure 缺 BUILDCC；43 个 contrib 依赖已构建完成。本轮范围保持现有 7 项双引擎冒烟。
  - **独立 VLC 主库预检**：在 `C:/ci/cache/native/vlc-preflight-97b1245` 使用独立输出 / 锁和闲置旧源码缓存，以 2 线程预检。首次 configure 因 MSYS2 无 `c11` / `c99` 包装器而找不到 `BUILDCC`；并非交叉编译失败。`build/main` 修复 `b221cd8` 显式选择 `gcc -std=gnu17`，保留外部 BUILDCC 覆盖。原生 PowerShell 语法检查与真实 FourCC 生成器编译 / 运行均通过（视频 871 / 音频 265 / 字幕 50 项）。恢复后的 configure 已通过，主库及 FFmpeg / DirectX 接口已编译，继续插件构建中；完整安装 / 依赖校验与冒烟仍未完成。
  - **按用户要求改成分块验证，停止盲目整条 CI 重跑**：`package-libvlc/main` 已推 `96adb2a`、`36fc416`、`e88d3f3`、`14ead3f`。`tool/check_vlc_contrib.py` 解析 GNU make 依赖图，逐包运行、独立日志、失败即停；已验证包保留，配方变更仅使该包和下游失效。编译器 / 全局参数变更拒绝混用缓存；恢复状态、未选包失效传播、路径清理与缓存标记测试 **4/4** 通过。
  - **真实 Windows 分项结果**：旧闲置源码 `C:/ci/cache/native/vlc-src/8bc964eb9f39d1de` 首轮检查 **43/43 passed，43 项缓存复用**，报告 `C:/ci/cache/native/vlc-package-checks/report/summary.json`。这表示既有 contrib 安装检查通过，不代表所有插件或播放通过。
  - **FFmpeg 插件独立验证**：VLC 的 `-Wc,-static` 使裸 `-lavformat` 选择 MSYS2 静态库；改用 package-ffmpeg 的明确 `.dll.a` 路径。AVIO、avcodec、avformat、packetizer_avparser、swscale 单独链接通过；核心加 4 个插件的 ABI / DLL 闭包检查通过（5 个二进制）。
  - **MIDI 独立验证**：明确选择 FluidLite，并添加 `FLUIDLITE_STATIC` 与静态 Vorbis 依赖；最小消费者编译 / 链接 / 运行退出 **0**，VLC fluidsynth 插件单独链接通过，保留 MIDI 功能。
  - **空间音频独立验证**：`libspatialaudio.a` 错用 mysofa DLL 导入声明；Windows 配方增加 `MYSOFA_STATIC`。隔离目录 `C:/ci/cache/native/spatialaudio-consumer-check` 的实际库编译 / 安装 / C++ 消费者链接 / 运行退出 **0**。正式单包重建与插件链接现已通过；随后 43 项全通过并全部缓存命中，其他依赖未重编。日志 `C:/ci/cache/native/vlc-package-checks/current/spatial-rebuild.log`。
  - **Windows 增量缓存修复 `build/main=01bc293`**：源码缓存键与完整打包配方解耦；逐包配方与工具链元数据另行验证。运行库缓存包含依赖状态、FFmpeg 导入库和 MIDI 参数，经过 ABI 检查后原子发布；缓存恢复仍复验。原生 PowerShell 语法、冷热状态、暖缓存稳定性、依赖 / 原生配方变更失效检查均通过。`BUILDCC` 修复 `b221cd8` 包含其中。
  - **插件矩阵已结束**：最终两个失败目标为 `libspatialaudio_plugin.la`（已修复并单独链接通过）和 `libarchive_plugin.la`。后者的 CMake 选择了 `C:/msys64/mingw64/lib/libz.dll.a`，造成静态插件未解析的 `__imp_inflate*` / `__imp_crc32`；配方指定 `ZLIB_USE_STATIC_LIBS=ON` 后，libarchive 单包编译 / 安装、覆盖所有格式与过滤器的 C 消费者链接 / 运行、归档插件链接均通过。再次全查 **43/43 passed，43 项缓存复用**。
  - **libmpv 已完成原生构建**：FreeType、FriBidi、HarfBuzz、libass、libplacebo、mpv 顺序构建全部通过；最终 DLL 只导入系统库与 owner 的 FFmpeg，原配方指纹与 CI 计算方式匹配。日志 `C:/ci/cache/native/mpv-preflight/build.log`，退出 **0**，已发布外部缓存供下一轮 CI 复用。
  - **libVLC 编译 / 安装已完成，严格检查继续暴露问题**：全量扫描 **326 个 DLL 文件**，仅 `libgme_plugin.dll` 引用外部 `libgcc_s_seh-1.dll`。`21db00e` 已推 main，移除 contrib `.pc` / `.la` 的显式 `-lgcc_s`，避免覆盖 `-static-libgcc`；正式配置下 MIDI 与 GME 独立编译 / 链接均通过。
  - **正式配置头变化**：初次独立链接使用诊断覆盖参数，随后用正式 MIDI / FFmpeg 配置重新生成 Makefile，并复用 **316 个**编译器 / 平台探测结果。配置头发生变化，Make 需要重编受影响对象；不能把先前的分项链接通过视为正式组合通过。
  - **配置记录转义修复 `ea874b1`**：VLC 的 `CONFIGURE_LINE` 没有转义环境库路径中的双引号，导致 `src/misc/messages.c` 编译失败。新增 `fix_vlc_config.py`，保留其他配置、正确编码为 C 字符串；幂等 / CRLF 单测 **2/2**，实际 Windows GCC 最小 C 消费者语法验证退出 **0**。原生 `git grep` 确认仅 `messages.c` 使用该宏，因此本次修复保留配置头时间戳并只使该对象失效，避免再次全局重编。
  - **当前最终组合验证运行中**：以 **4 线程**恢复剩余对象（无 configure 或 43 项依赖重启），日志 `C:/ci/cache/native/vlc-preflight-97b1245/production-profile.log`。完整安装 / 全 DLL ABI 检查 / 搬迁后加载与插件发现全部成功后才发布运行库缓存；之前失败日志已分别保留。
  - **缓存完善 `build/main=b1f1d24`**：增加 `OPX_VLC_BUILD_DIR` 保存主库对象、仅首次升级旧依赖状态时接管缓存，并缓存完成的 libmpv。原生 PowerShell 语法检查通过。Windows 检出是 CRLF，最终运行库指纹从真实 Windows 最新 main 检出计算，避免本地 LF 字节差异导致缓存失配。
  - **尚未跑 #35**：等待上述最终组合检查通过，然后只跑两引擎各 7 项现有播放冒烟。不把分项、原生构建或 DLL 扫描通过冒充播放通过。
- Windows 本轮范围：用户明确选择“仅完成 Windows 构建与现有冒烟测试”。不创建素材镜像，不同步约 19GB 素材，不运行 Windows 405 项全量；继续本机原生构建与现有 7 项双引擎冒烟。
- Pixel 9：旧 PID 75641 已退出，但新的字幕全量任务仍占用该真机，不能清理 `example-wandroid/build` 或同时安装格式测试。
- Android 模拟器：使用独立 `example-wandroid-materials/` 与空闲 `emulator-5554` 补测光盘及功能回归，首轮报告 `android-20261128-155154-945747` 因 guest shell 无响应主动中止，记录为基础设施错误。冷启动同一 AVD（不清数据、不重启共享 ADB）后，第二轮 `android-20261128-155650-778161` 共 17 项，15 通过、BIN/DVD 掉帧失败、ASX 路由覆盖失败；修复后第三轮 `android-20261128-160156-848263` **5/5 通过**，包含同批 ASX/STRM、生成 ASX、MMF 和单独 BIN/DVD（保留前次掉帧记录）。本轮 Android 17 个唯一用例均已有通过记录，但不拼接成一次全量通过声明；不替代 Pixel 9 的 4K 硬解复验。
- Linux：首轮 `linux-20261128-050813-612397` 的 TrueHD、截断 APE 通过，MMF / NUV / Potter 失败。
  - **MMF 真实播放修复**：原 seek 到中间后 ADPCM predictor 状态丢失（直接 libmpv 对照：seek 前过零率 0.25，seek 后 0.027466；从头解码后 0.244425）。`mpv_backend.dart` 现对 MMF 从头解码至 seek 目标，其他素材恢复原 hr-seek-demuxer-offset。
  - `linux-20261128-051652-780828`：MMF、素材包 MMF、MP3 **3/3 通过**，MMF **1000 Hz / RMS 0.0891**；`macos-20261128-161834-809205` 的相同三项也全过，`android-20261128-161908-064434` 的相同三项也全过。
  - **NUV 共享测试修复**：有视频的超短截断片也循环采样，统计窗口跨循环累计帧进度；`linux-20261128-051832-881445` 的 Today.nuv 通过。
  - **Potter 参考测量修复并补测通过**：Linux Docker 的系统 FFmpeg 6.1 无法解码 AVI/Speex，参考测量返回 None；原绝对静音阈值造成误报。新增 `OPX_REFERENCE_FFMPEG` 选择参考解码器，仅影响源音频测量，不更换播放器或降低断言。
    - 在 `build/reference-ffmpeg/linux-arm64` 用 package-ffmpeg 固定的 FFmpeg 9.1 源码独立构建 CLI：`--disable-autodetect --disable-doc --disable-debug --disable-network --disable-avdevice --disable-ffplay --disable-ffprobe --disable-encoders --enable-encoder=pcm_s16le --disable-muxers --enable-muxer=null --disable-filters --enable-filter=lowpass,astats,aresample,anull --enable-protocol=file,pipe`；配置 / 构建 / 原始测量日志保留于该目录。
    - [Linux 实际补测](../build/material-tests/linux-20261128-064852-855280/report.md)：**1/1 通过**；参考 RMS **0.0004997537**、播放器 RMS **0.0001375**，512×304，27 帧显示 / 0 丢帧。运行命令：`tool/linux/run.sh -- env OPX_REFERENCE_FFMPEG=/Users/zyl/codes/mygithub/openplayx/package-media/build/reference-ffmpeg/linux-arm64/ffmpeg xvfb-run -a bash package-media/tool/test_materials.sh --platform linux --device linux --only public-ffmpeg-fate-potter512-400-partial-avi --timeout 900`。
    - 无豁免；系统默认 FFmpeg 6.1 仍不兼容，后续该环境跑公共素材需保留上述参考工具配置。Python 单测重新验证 **25/25**。
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

## 2. 原交接改动清单（当前提交见第 0 节）

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
