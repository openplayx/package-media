# 素材测试总入口清单

平台：ios；完整基线 438 项。

必须通过 150 项；允许失败 8 项；待验证 280 项。
同一素材在不同引擎下是不同用例，基线不会跨引擎套用。

`pass` 必须通过；`allow_failure` 允许准备或播放失败，仍逐项记录。
`unverified` 尚无本平台证据；新失败需要分析，会使整体失败，不会自动加入豁免。
必须通过项的准备失败或播放失败使整体失败；任何漏记结果、崩溃或超时也使整体失败。

历史临时 Jellyfin 网关服务的四项流程检查另需服务环境，详见基线的 `outside_material_scope`。

| 测试组 | 准备入口 | 必须通过 | 允许失败 | 待验证 |
|---|---|---:|---:|---:|
| formats | `tool/prepare_samples.py` | 150 | 8 | 27 |
| public | `tool/prepare_public_corpus.py` | 0 | 0 | 207 |
| advanced | `tool/prepare_advanced.py` | 0 | 0 | 7 |
| backlog | `tool/prepare_backlog_coverage.py` | 0 | 0 | 15 |
| fixes | `tool/prepare_failed_fixes.py` | 0 | 0 | 10 |
| batch12 | `tool/prepare_batch12_tests.py` | 0 | 0 | 11 |
| iso | `tool/prepare_iso_tests.py` | 0 | 0 | 3 |

| 测试组 | 引擎 | 用例 | 要求 | 基线依据 |
|---|---|---|---|---|
| advanced | auto | advanced-bluray | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| advanced | auto | advanced-dovi-p5 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| advanced | auto | advanced-dovi-p8.1 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| advanced | auto | advanced-dovi-p8.4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| advanced | auto | advanced-dvd | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| advanced | auto | advanced-hdr10plus | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| advanced | auto | advanced-web-baseline | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-246-strm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-296-vc1 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-311-srt | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-312-ass | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-313-ssa | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-314-vtt | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-315-vobsub | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-316-pgs | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-317-mks | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-318-sami | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-319-mov_text | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-320-eia608 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-321-eia708 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-362-cue | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| backlog | auto | backlog-all-369-pls | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| batch12 | auto | audio-adp-gamecube | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| batch12 | auto | audio-afc-gamecube | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| batch12 | auto | audio-dolby-atmos-truehd | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| batch12 | auto | audio-dtshd-ma | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| batch12 | auto | audio-dtsx-714 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| batch12 | auto | container-bivx-dual-audio | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| batch12 | auto | disc-bin-dvd | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| batch12 | auto | disc-ifo-dvd | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| batch12 | auto | disc-img-dvd | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| batch12 | auto | disc-nrg-dvd | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| batch12 | auto | split-001-mkv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| fixes | auto | fix-all-227-dvr-ms | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| fixes | auto | fix-all-234-asx | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| fixes | auto | fix-all-237-mk3d | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| fixes | auto | fix-all-249-wv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| fixes | auto | fix-all-251-shn | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| fixes | auto | fix-all-252-mac | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| fixes | auto | fix-all-267-mpc | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| fixes | auto | fix-all-268-mpp | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| fixes | auto | fix-all-269-mp+ | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| fixes | auto | fix-all-273-aa | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | 3g2-h263-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | 3gp-aac-audio | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | 3gp-h263-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | aac-adts | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ac3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | adx | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | aif-pcm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | aifc-pcm-le | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | amv | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | asf-wmv2-wmav2 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ast | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | asx-mp4 | allow_failure | ios 已知未通过：ended without reporting playback time (video null) |
| formats | auto | au-pcm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | avi-mpeg4sp-mp3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | cue-wav | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | divx-mpeg4asp-mp3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | dts | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | dv-pal | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | eac3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ec3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-224-rec | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-225-pva | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-226-ty | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-227-dvr-ms | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-236-fli | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-239-nsv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-240-nuv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-241-ogm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-243-svq3 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-244-viv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-245-vp3 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-251-shn | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-252-mac | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-264-amr | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-265-awb | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-266-ra | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-267-mpc | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-268-mpp | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-269-mp+ | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-271-vox | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-273-aa | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-332-xm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-333-it | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-334-s3m | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-335-nsf | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-337-669 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-340-amf | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-341-dmf | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-344-far | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-345-gdm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-346-gym | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-347-imf | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-348-m15 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-349-med | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-350-okt | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-351-sfx | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-352-stm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-353-ult | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ext-all-357-act | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-358-adp | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-363-dvf | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-366-mogg | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | ext-all-367-msv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | f4v-h264-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | flac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | flv-h264-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | m2t-mpeg2-mp2 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | m2ts-h264-ac3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | m2v-mpeg2 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | m3u-mp3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | m4a-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | m4a-alac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | m4b-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | m4v-h264-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mk3d-h264-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mka-opus | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mka-truehd | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mkv-av1-opus | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mkv-hevc-10bit | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mkv-hevc-opus | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mmf | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mov-h264-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mov-prores-pcm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mp2 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mp3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mp3-vbr | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mp4-h264-10bit | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mp4-h264-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mp4-hevc-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mpa | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mpe-mpeg2-mp2 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mpg-mpeg2-mp2 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | mxf-mpeg2-pcm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | oga-flac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ogg-flac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ogg-opus | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ogg-vorbis | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ogv-vp8-opus | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | opus | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-215-asf | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-216-rm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-217-divx | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-218-xvid | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-220-qt | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-221-m2t | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-222-m2v | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-223-tp | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-228-wtv | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-229-mxf | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-230-dv | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-232-3g2 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-233-amv | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-234-asx | allow_failure | ios 已知未通过：ended without reporting playback time (video null) |
| formats | auto | pack-all-235-f4v | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-237-mk3d | allow_failure | ios 已知未通过：video size Size(640.0, 480.0), expected 640x240 |
| formats | auto | pack-all-238-mpe | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-242-ogv | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-246-strm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-247-alac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-248-dsf | allow_failure | ios 已知未通过：seek to 505 ms from 1000 ms: PlaybackStatus.paused at 0:00:00.504997 |
| formats | auto | pack-all-249-wv | allow_failure | ios 已知未通过：seek to 1500 ms from 1904 ms: PlaybackStatus.ended at 0:00:03.000000 |
| formats | auto | pack-all-250-mka | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-253-rf64 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-254-ac3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-255-eac3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-256-ec3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-257-dts | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-258-mp2 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-259-mpa | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-260-oga | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-261-aif | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-262-aifc | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-263-au | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-266-ra | allow_failure | ios 已知未通过：did not start: PlaybackStatus.ended, position 0:00:00.020000, video null |
| formats | auto | pack-all-270-gsm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-272-3gp | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-275-m4b | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-276-mod | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-286-mpg | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-287-avi | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-288-avi | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-289-mp4 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-290-mp4 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-291-mp4 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-292-mp4 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-293-webm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-294-webm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-295-webm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-297-rm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-298-mp3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-299-m4a | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-300-flac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-301-m4a | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-302-ogg | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-303-opus | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-307-thd | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-319-mp4 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-322-mp4 | allow_failure | ios 已知未通过：pictures dropped: 1 lost, 3 displayed in 1 s; seek to 1000 ms from 1958 ms: PlaybackStatus.paused at 0:00:01.000000 |
| formats | auto | pack-all-323-mp4 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-324-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| formats | auto | pack-all-326-mp4 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-331-mp4 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-338-adx | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-360-ast | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-362-cue | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pack-all-365-mmf | allow_failure | ios 已知未通过：seek to 1536 ms from 1966 ms: PlaybackStatus.ended at 0:00:03.072000; wrong sound: 104 Hz, expected 440 Hz (noise or wrong decoding) |
| formats | auto | pack-all-369-pls | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | pls-mp3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | qt-h264-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | rf64-pcm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | rm-rv20-ac3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | tp-h264-ac3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | truehd | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | ts-h264-aac | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | tta | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | vob-mpeg2-ac3 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | wav-pcm | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | webm-av1-opus | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | webm-vp8-opus | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | webm-vp9-opus | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | wma-wmav2 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | wmv-wmv2-wmav2 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | wtv-mpeg2-mp2 | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | wv-wavpack | pass | ios 已有通过记录，必须保持通过 |
| formats | auto | xvid-mpeg4asp-mp3 | pass | ios 已有通过记录，必须保持通过 |
| iso | auto | iso-bluray-bdmv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| iso | auto | iso-dvd-video | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| iso | auto | iso-kodi-3dlr-patterns | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-01-Untitled-partial-oma | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-102400samples_qt-lc-aac-m4a | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-2.0_32-bit_float-wv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-4.75k-amr | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-Beethovens_9th-1_small-wma | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-C0023S01-mxf | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-Closedcaption_rollup-m2v | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-Enigma_Principles_of_Lust-part-flv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-FLCL_Ending_My-short-wav | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-PVA_test-partial-pva | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-RA5.0_16kbps_voice_wideband-ra | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-RRSF49-short-webm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-SA00040-vc1 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-Today-nuv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-Vertical400kbit.sorenson3-mov | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-achterba-vqf | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-al_sbr_ps_04_new-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-atmos-thd | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-audio_id_ims_25fps-ts | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-banjo_48_2_303-qoa | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-binkaudio_rdft-bik | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-bug821-2-asf | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-bush-aa | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-caf-pcm16-caf | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-cavs-mpg | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-csi_miami_5.1_256_spx_small-eac3 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-ct_ending_cut-mov | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-demo11_02_partial-ast | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-dtsx_7.1.4_24bit-dts | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-empty_theora_packets-ogv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-ergon-xwma | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-evrc-qcp | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-fli-engines-fli | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-fragmented-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-frames_refs_short_signaling-ivf | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-h264small-ts | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-ilbc-lost-mov | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-inside-mp7-mpc | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-interlaced32x32-avi | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-law-and-order-partial-wtv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-loz-mm-mikau-bcstm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-lozswd_partial-brstm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-luckynight-mac394b1-c2000-ape | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-luckynight-partial-shn | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-master_audio_2.0_24bit-wma | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-master_audio_7.1_24bit-dts | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-mc_sich_at3_105_small-wav | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-millers_crossing_4.0-ac3 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-mpeg2_field_encoding-ts | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-mpegh_config_change_cicp_2_14_6_lc_baseline_compatible_32kbps-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-packed_maindata.mp3-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-potter512-400-partial-avi | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-ra_cook-rm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-seed-6k60-awb | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-shakespr_partial-adp | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-sonateno14op27-2-cut-aa3 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-spherical-mkv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-streaming_CBR-7K-wma | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-test72x72-rmhd | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-test_000096-iamf | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-test_tones_small-aea | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-testvector12-mka | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-tos-ogg | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-vp31-avi | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-w64-pcm16-w64 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-wetlogo-smk | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-witchblade-51kbps-nsv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-fate-wmv_drm-wmv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-samples-07011600-msv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-samples-REC01-act | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-samples-SS2-dvr-ms | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-samples-md_ogg-ogm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-samples-s2short1-viv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-ffmpeg-samples-taxis-dvf | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_10M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_15M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_20M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_25M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_30M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_3M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_5M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_10M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_15M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_20M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_25M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_30M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_3M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_5M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_10M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_15M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_20M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_30M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_3M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_5M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_DV_P5-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_DV_P8.1-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_DV_P8.4-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_10M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_15M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_20M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_30M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_3M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_5M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_10M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_15M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_20M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_25M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_30M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_3M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_5M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_10M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_15M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_20M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_30M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_3M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_5M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_100M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_40M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_50M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_60M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_70M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_80M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_90M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_100M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_40M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_50M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_60M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_70M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_80M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_90M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_100M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_150M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_40M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_50M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_60M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_70M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_80M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_90M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_DV_P5-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_DV_P8.1-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_DV_P8.4-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_100M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_150M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_40M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_50M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_60M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_70M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_80M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_90M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_100M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_150M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_40M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_50M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_60M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_70M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_80M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_90M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_100M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_150M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_40M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_50M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_60M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_70M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_80M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_90M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_AV1_10bit_100M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_AV1_HDR10_100M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_AVC_150M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_DV_P5-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_DV_P8.1-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_DV_P8.4-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_HEVC_10bit_150M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_HEVC_8bit_150M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_HEVC_HDR10_150M-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-kodi-samples-305_24p-mp4 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-kodi-samples-3D_LR_Pattern-mkv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-kodi-samples-HDR10__Sample_Video-webm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-3d_foot-gdm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-4th_Symmetriad-it | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-Crockett_s_theme-sfx | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-FROZEN-dmf | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-Gaffeltruck-mod | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-Inertiaload-1-med | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-Jarre-Like-med | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-Yes-PartII-okt | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-astaris-imf | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-cybocult-ult | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-fracture-stm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-ft2_delay_envelope_on-xm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-inside_out-s3m | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-it_high_offset_memory-it | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-musicind-amf | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-oxygene2-mod | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-reverse_it-it | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-s3m_sample_porta-s3m | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-sonic_boom-669 | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-stereo-xm | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-libxmp-thunddrm-far | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-matroska-test-files-test1-mkv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-matroska-test-files-test2-mkv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-matroska-test-files-test3-mkv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-matroska-test-files-test4-mkv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-matroska-test-files-test5-mkv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-matroska-test-files-test6-mkv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-matroska-test-files-test7-mkv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-matroska-test-files-test8-mkv | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
| public | auto | public-pixeltools-cea708_dtv-mpg | unverified | 尚无 ios 实测证据；不继承 macOS 的通过或豁免，新失败需分析 |
