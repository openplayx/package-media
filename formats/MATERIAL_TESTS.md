# 素材测试总入口清单

平台：macos；完整基线 599 项。

必须通过 545 项；允许失败 54 项；待验证 0 项。
同一素材在不同引擎下是不同用例，基线不会跨引擎套用。

`pass` 必须通过；`allow_failure` 允许准备或播放失败，仍逐项记录。
`unverified` 尚无本平台证据；新失败需要分析，会使整体失败，不会自动加入豁免。
必须通过项的准备失败或播放失败使整体失败；任何漏记结果、崩溃或超时也使整体失败。

历史临时 Jellyfin 网关服务的四项流程检查另需服务环境，详见基线的 `outside_material_scope`。

| 测试组 | 准备入口 | 必须通过 | 允许失败 | 待验证 |
|---|---|---:|---:|---:|
| formats | `tool/prepare_samples.py` | 303 | 42 | 0 |
| public | `tool/prepare_public_corpus.py` | 196 | 11 | 0 |
| advanced | `tool/prepare_advanced.py` | 7 | 1 | 0 |
| backlog | `tool/prepare_backlog_coverage.py` | 15 | 0 | 0 |
| fixes | `tool/prepare_failed_fixes.py` | 10 | 0 | 0 |
| batch12 | `tool/prepare_batch12_tests.py` | 11 | 0 | 0 |
| iso | `tool/prepare_iso_tests.py` | 3 | 0 | 0 |

| 测试组 | 引擎 | 用例 | 要求 | 基线依据 |
|---|---|---|---|---|
| advanced | auto | advanced-bluray | pass | 已有通过记录，必须保持通过 |
| advanced | auto | advanced-dovi-p5 | pass | 已有通过记录，必须保持通过 |
| advanced | auto | advanced-dovi-p8.1 | pass | 已有通过记录，必须保持通过 |
| advanced | auto | advanced-dovi-p8.4 | pass | 已有通过记录，必须保持通过 |
| advanced | auto | advanced-dvd | pass | 已有通过记录，必须保持通过 |
| advanced | auto | advanced-hdr10plus | pass | 已有通过记录，必须保持通过 |
| advanced | auto | advanced-web-baseline | pass | 已有通过记录，必须保持通过 |
| advanced | vlc | advanced-dovi-p5 | allow_failure | 已知未通过：snapshot colour cast: normalized mean RGB [0.1986976734845518, 0.41611691819541924, 0.3851854083200289], expected ~[0.2967148836279448, 0.22621773085778038, 0.47706738551427486] (error 0.18989918733763886) |
| backlog | auto | backlog-all-246-strm | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-296-vc1 | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-311-srt | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-312-ass | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-313-ssa | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-314-vtt | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-315-vobsub | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-316-pgs | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-317-mks | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-318-sami | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-319-mov_text | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-320-eia608 | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-321-eia708 | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-362-cue | pass | 已有通过记录，必须保持通过 |
| backlog | auto | backlog-all-369-pls | pass | 已有通过记录，必须保持通过 |
| batch12 | auto | audio-adp-gamecube | pass | 已有通过记录，必须保持通过 |
| batch12 | auto | audio-afc-gamecube | pass | 已有通过记录，必须保持通过 |
| batch12 | auto | audio-dolby-atmos-truehd | pass | 已有通过记录，必须保持通过 |
| batch12 | auto | audio-dtshd-ma | pass | 已有通过记录，必须保持通过 |
| batch12 | auto | audio-dtsx-714 | pass | 已有通过记录，必须保持通过 |
| batch12 | auto | container-bivx-dual-audio | pass | 已有通过记录，必须保持通过 |
| batch12 | auto | disc-bin-dvd | pass | 已有通过记录，必须保持通过 |
| batch12 | auto | disc-ifo-dvd | pass | 已有通过记录，必须保持通过 |
| batch12 | auto | disc-img-dvd | pass | 已有通过记录，必须保持通过 |
| batch12 | auto | disc-nrg-dvd | pass | 已有通过记录，必须保持通过 |
| batch12 | auto | split-001-mkv | pass | 已有通过记录，必须保持通过 |
| fixes | auto | fix-all-227-dvr-ms | pass | 已有通过记录，必须保持通过 |
| fixes | auto | fix-all-234-asx | pass | 已有通过记录，必须保持通过 |
| fixes | auto | fix-all-237-mk3d | pass | 已有通过记录，必须保持通过 |
| fixes | auto | fix-all-249-wv | pass | 已有通过记录，必须保持通过 |
| fixes | auto | fix-all-251-shn | pass | 已有通过记录，必须保持通过 |
| fixes | auto | fix-all-252-mac | pass | 已有通过记录，必须保持通过 |
| fixes | auto | fix-all-267-mpc | pass | 已有通过记录，必须保持通过 |
| fixes | auto | fix-all-268-mpp | pass | 已有通过记录，必须保持通过 |
| fixes | auto | fix-all-269-mp+ | pass | 已有通过记录，必须保持通过 |
| fixes | auto | fix-all-273-aa | pass | 已有通过记录，必须保持通过 |
| formats | auto | 3g2-h263-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | 3gp-aac-audio | pass | 已有通过记录，必须保持通过 |
| formats | auto | 3gp-h263-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | aac-adts | pass | 已有通过记录，必须保持通过 |
| formats | auto | ac3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | adx | pass | 已有通过记录，必须保持通过 |
| formats | auto | aif-pcm | pass | 已有通过记录，必须保持通过 |
| formats | auto | aifc-pcm-le | pass | 已有通过记录，必须保持通过 |
| formats | auto | amv | pass | 已有通过记录，必须保持通过 |
| formats | auto | asf-wmv2-wmav2 | pass | 已有通过记录，必须保持通过 |
| formats | auto | ast | pass | 已有通过记录，必须保持通过 |
| formats | auto | asx-mp4 | allow_failure | 已知未通过：ended without reporting playback time (video null) |
| formats | auto | au-pcm | pass | 已有通过记录，必须保持通过 |
| formats | auto | avi-mpeg4sp-mp3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | cue-wav | pass | 已有通过记录，必须保持通过 |
| formats | auto | divx-mpeg4asp-mp3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | dts | pass | 已有通过记录，必须保持通过 |
| formats | auto | dv-pal | pass | 已有通过记录，必须保持通过 |
| formats | auto | eac3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | ec3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-224-rec | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-225-pva | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-226-ty | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-227-dvr-ms | allow_failure | 已知未通过：duration 6506 ms, expected ~344 ms; video size Size(720.0, 540.0), expected 720x480 or 640x480 |
| formats | auto | ext-all-236-fli | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-239-nsv | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-240-nuv | allow_failure | 已知未通过：did not start: PlaybackStatus.ended, position 0:00:00.380226, video Size(640.0, 480.0) |
| formats | auto | ext-all-241-ogm | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-243-svq3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-244-viv | allow_failure | 已知未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video Size(160.0, 120.0) |
| formats | auto | ext-all-245-vp3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-251-shn | allow_failure | 已知未通过：seek to 4000 ms from 1542 ms: PlaybackStatus.error at 0:00:04.000000 |
| formats | auto | ext-all-252-mac | allow_failure | 已知未通过：seek to 30240 ms from 1565 ms: PlaybackStatus.error at 0:00:30.240000 |
| formats | auto | ext-all-264-amr | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-265-awb | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-266-ra | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-267-mpc | allow_failure | 已知未通过：seek to 5955 ms from 1542 ms: PlaybackStatus.ended at 0:00:11.766433 |
| formats | auto | ext-all-268-mpp | allow_failure | 已知未通过：seek to 5955 ms from 1505 ms: PlaybackStatus.ended at 0:00:11.717364 |
| formats | auto | ext-all-269-mp+ | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-271-vox | allow_failure | 已知未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video null |
| formats | auto | ext-all-273-aa | allow_failure | 已知未通过：seek to 2684581 ms from 1516 ms: PlaybackStatus.ended at 0:44:44.581000 |
| formats | auto | ext-all-332-xm | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-333-it | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-334-s3m | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-335-nsf | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-337-669 | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-340-amf | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-341-dmf | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-344-far | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-345-gdm | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-346-gym | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-347-imf | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-348-m15 | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-349-med | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-350-okt | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-351-sfx | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-352-stm | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-353-ult | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-357-act | pass | 已有通过记录，必须保持通过 |
| formats | auto | ext-all-358-adp | allow_failure | 已知未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video null |
| formats | auto | ext-all-363-dvf | allow_failure | 已知未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video null |
| formats | auto | ext-all-366-mogg | allow_failure | 已知未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video null |
| formats | auto | ext-all-367-msv | allow_failure | 已知未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video null |
| formats | auto | f4v-h264-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | flac | pass | 已有通过记录，必须保持通过 |
| formats | auto | flv-h264-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | m2t-mpeg2-mp2 | pass | 已有通过记录，必须保持通过 |
| formats | auto | m2ts-h264-ac3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | m2v-mpeg2 | pass | 已有通过记录，必须保持通过 |
| formats | auto | m3u-mp3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | m4a-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | m4a-alac | pass | 已有通过记录，必须保持通过 |
| formats | auto | m4b-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | m4v-h264-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | mk3d-h264-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | mka-opus | pass | 已有通过记录，必须保持通过 |
| formats | auto | mka-truehd | pass | 已有通过记录，必须保持通过 |
| formats | auto | mkv-av1-opus | pass | 已有通过记录，必须保持通过 |
| formats | auto | mkv-hevc-10bit | pass | 已有通过记录，必须保持通过 |
| formats | auto | mkv-hevc-opus | pass | 已有通过记录，必须保持通过 |
| formats | auto | mmf | pass | 已有通过记录，必须保持通过 |
| formats | auto | mov-h264-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | mov-prores-pcm | pass | 已有通过记录，必须保持通过 |
| formats | auto | mp2 | pass | 已有通过记录，必须保持通过 |
| formats | auto | mp3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | mp3-vbr | pass | 已有通过记录，必须保持通过 |
| formats | auto | mp4-h264-10bit | pass | 已有通过记录，必须保持通过 |
| formats | auto | mp4-h264-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | mp4-hevc-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | mpa | pass | 已有通过记录，必须保持通过 |
| formats | auto | mpe-mpeg2-mp2 | pass | 已有通过记录，必须保持通过 |
| formats | auto | mpg-mpeg2-mp2 | pass | 已有通过记录，必须保持通过 |
| formats | auto | mxf-mpeg2-pcm | pass | 已有通过记录，必须保持通过 |
| formats | auto | oga-flac | pass | 已有通过记录，必须保持通过 |
| formats | auto | ogg-flac | pass | 已有通过记录，必须保持通过 |
| formats | auto | ogg-opus | pass | 已有通过记录，必须保持通过 |
| formats | auto | ogg-vorbis | pass | 已有通过记录，必须保持通过 |
| formats | auto | ogv-vp8-opus | pass | 已有通过记录，必须保持通过 |
| formats | auto | opus | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-215-asf | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-216-rm | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-217-divx | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-218-xvid | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-220-qt | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-221-m2t | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-222-m2v | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-223-tp | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-228-wtv | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-229-mxf | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-230-dv | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-232-3g2 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-233-amv | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-234-asx | allow_failure | 已知未通过：ended without reporting playback time (video null) |
| formats | auto | pack-all-235-f4v | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-237-mk3d | allow_failure | 已知未通过：video size Size(640.0, 480.0), expected 640x240 |
| formats | auto | pack-all-238-mpe | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-242-ogv | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-246-strm | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-247-alac | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-248-dsf | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-249-wv | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-250-mka | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-253-rf64 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-254-ac3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-255-eac3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-256-ec3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-257-dts | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-258-mp2 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-259-mpa | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-260-oga | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-261-aif | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-262-aifc | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-263-au | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-266-ra | allow_failure | 已知未通过：did not start: PlaybackStatus.ended, position 0:00:00.020000, video null |
| formats | auto | pack-all-270-gsm | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-272-3gp | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-275-m4b | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-276-mod | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-286-mpg | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-287-avi | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-288-avi | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-289-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-290-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-291-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-292-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-293-webm | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-294-webm | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-295-webm | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-297-rm | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-298-mp3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-299-m4a | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-300-flac | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-301-m4a | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-302-ogg | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-303-opus | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-307-thd | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-319-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-322-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-323-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-324-mp4 | pass | 暂无实测结果，默认必须通过，未自动豁免 |
| formats | auto | pack-all-326-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-331-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-338-adx | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-360-ast | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-362-cue | pass | 已有通过记录，必须保持通过 |
| formats | auto | pack-all-365-mmf | allow_failure | 已知未通过：seek to 1536 ms from 1992 ms: PlaybackStatus.ended at 0:00:03.072000; wrong sound: 104 Hz, expected 440 Hz (noise or wrong decoding) |
| formats | auto | pack-all-369-pls | pass | 已有通过记录，必须保持通过 |
| formats | auto | pls-mp3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | qt-h264-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | rf64-pcm | pass | 已有通过记录，必须保持通过 |
| formats | auto | rm-rv20-ac3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | tp-h264-ac3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | truehd | pass | 已有通过记录，必须保持通过 |
| formats | auto | ts-h264-aac | pass | 已有通过记录，必须保持通过 |
| formats | auto | tta | pass | 已有通过记录，必须保持通过 |
| formats | auto | vob-mpeg2-ac3 | pass | 已有通过记录，必须保持通过 |
| formats | auto | wav-pcm | pass | 已有通过记录，必须保持通过 |
| formats | auto | webm-av1-opus | pass | 已有通过记录，必须保持通过 |
| formats | auto | webm-vp8-opus | pass | 已有通过记录，必须保持通过 |
| formats | auto | webm-vp9-opus | pass | 已有通过记录，必须保持通过 |
| formats | auto | wma-wmav2 | pass | 已有通过记录，必须保持通过 |
| formats | auto | wmv-wmv2-wmav2 | pass | 已有通过记录，必须保持通过 |
| formats | auto | wtv-mpeg2-mp2 | pass | 已有通过记录，必须保持通过 |
| formats | auto | wv-wavpack | pass | 已有通过记录，必须保持通过 |
| formats | auto | xvid-mpeg4asp-mp3 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-332-xm | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-333-it | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-334-s3m | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-335-nsf | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-337-669 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-340-amf | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-341-dmf | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-344-far | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-345-gdm | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-346-gym | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-347-imf | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-348-m15 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-349-med | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-350-okt | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-351-sfx | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-352-stm | pass | 已有通过记录，必须保持通过 |
| formats | mpv | ext-all-353-ult | pass | 已有通过记录，必须保持通过 |
| formats | mpv | mkv-hevc-10bit | pass | 已有通过记录，必须保持通过 |
| formats | mpv | mp4-h264-aac | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-215-asf | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-216-rm | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-217-divx | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-218-xvid | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-220-qt | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-221-m2t | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-222-m2v | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-223-tp | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-228-wtv | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-229-mxf | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-230-dv | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-232-3g2 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-233-amv | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-234-asx | allow_failure | 已知未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video null |
| formats | mpv | pack-all-235-f4v | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-237-mk3d | allow_failure | 已知未通过：video size Size(640.0, 480.0), expected 640x240 |
| formats | mpv | pack-all-238-mpe | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-242-ogv | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-246-strm | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-247-alac | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-248-dsf | allow_failure | 已知未通过：seek to 505 ms from 1000 ms: PlaybackStatus.paused at 0:00:00.504997 |
| formats | mpv | pack-all-249-wv | allow_failure | 已知未通过：seek to 1500 ms from 1896 ms: PlaybackStatus.ended at 0:00:03.000000 |
| formats | mpv | pack-all-250-mka | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-253-rf64 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-254-ac3 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-255-eac3 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-256-ec3 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-257-dts | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-258-mp2 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-259-mpa | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-260-oga | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-261-aif | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-262-aifc | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-263-au | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-266-ra | allow_failure | 已知未通过：did not start: PlaybackStatus.ended, position 0:00:00.020000, video null |
| formats | mpv | pack-all-270-gsm | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-272-3gp | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-275-m4b | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-276-mod | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-286-mpg | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-287-avi | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-288-avi | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-289-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-290-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-291-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-292-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-293-webm | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-294-webm | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-295-webm | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-297-rm | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-298-mp3 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-299-m4a | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-300-flac | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-301-m4a | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-302-ogg | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-303-opus | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-307-thd | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-319-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-322-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-323-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-326-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-331-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-338-adx | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-360-ast | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-362-cue | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-365-mmf | pass | 已有通过记录，必须保持通过 |
| formats | mpv | pack-all-369-pls | pass | 已有通过记录，必须保持通过 |
| formats | vlc | mkv-av1-opus | pass | 已有通过记录，必须保持通过 |
| formats | vlc | mkv-hevc-opus | pass | 已有通过记录，必须保持通过 |
| formats | vlc | mp3 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | mp4-h264-aac | pass | 已有通过记录，必须保持通过 |
| formats | vlc | oga-flac | pass | 已有通过记录，必须保持通过 |
| formats | vlc | ogg-vorbis | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-215-asf | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-216-rm | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-217-divx | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-218-xvid | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-220-qt | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-221-m2t | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-222-m2v | allow_failure | 已知未通过：ended without reporting playback time (video Size(320.0, 240.0)) |
| formats | vlc | pack-all-223-tp | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-228-wtv | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-229-mxf | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-230-dv | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-232-3g2 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-233-amv | allow_failure | 已知未通过：seek to 4000 ms from 1665 ms: PlaybackStatus.ended at 0:00:01.665000 |
| formats | vlc | pack-all-234-asx | allow_failure | 已知未通过：ended without reporting playback time (video null) |
| formats | vlc | pack-all-235-f4v | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-237-mk3d | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-238-mpe | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-242-ogv | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-246-strm | allow_failure | 已知未通过：ended without reporting playback time (video null) |
| formats | vlc | pack-all-247-alac | allow_failure | 已知未通过：seek to 1500 ms from 1406 ms: PlaybackStatus.ended at 0:00:01.500000 |
| formats | vlc | pack-all-248-dsf | allow_failure | 已知未通过：ended without reporting playback time (video null) |
| formats | vlc | pack-all-249-wv | allow_failure | 已知未通过：did not start: PlaybackStatus.ended, position 0:00:00.910000, video null |
| formats | vlc | pack-all-250-mka | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-253-rf64 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-254-ac3 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-255-eac3 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-256-ec3 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-257-dts | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-258-mp2 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-259-mpa | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-260-oga | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-261-aif | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-262-aifc | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-263-au | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-266-ra | allow_failure | 已知未通过：ended without reporting playback time (video null) |
| formats | vlc | pack-all-270-gsm | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-272-3gp | allow_failure | 已知未通过：seek to 1500 ms from 1410 ms: PlaybackStatus.ended at 0:00:01.500000 |
| formats | vlc | pack-all-275-m4b | allow_failure | 已知未通过：seek to 1500 ms from 1157 ms: PlaybackStatus.ended at 0:00:01.500000 |
| formats | vlc | pack-all-276-mod | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-286-mpg | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-287-avi | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-288-avi | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-289-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-290-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-291-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-292-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-293-webm | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-294-webm | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-295-webm | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-297-rm | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-298-mp3 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-299-m4a | allow_failure | 已知未通过：seek to 1500 ms from 1402 ms: PlaybackStatus.ended at 0:00:01.500000 |
| formats | vlc | pack-all-300-flac | allow_failure | 已知未通过：seek to 1500 ms from 1688 ms: PlaybackStatus.ended at 0:00:01.500000 |
| formats | vlc | pack-all-301-m4a | allow_failure | 已知未通过：seek to 1500 ms from 1407 ms: PlaybackStatus.ended at 0:00:01.500000 |
| formats | vlc | pack-all-302-ogg | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-303-opus | allow_failure | 已知未通过：seek to 1463 ms from 1830 ms: PlaybackStatus.ended at 0:00:01.830000 |
| formats | vlc | pack-all-307-thd | allow_failure | 已知未通过：audio stalled: decoded 0, played 0 in 1 s; seek to 1499 ms from 1784 ms: PlaybackStatus.ended at 0:00:01.784000; no decoded audio written (afile output) |
| formats | vlc | pack-all-319-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-322-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-323-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-326-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-331-mp4 | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-338-adx | pass | 已有通过记录，必须保持通过 |
| formats | vlc | pack-all-360-ast | allow_failure | 已知未通过：audio stalled: decoded 0, played 0 in 1 s; seek to 1500 ms from 1809 ms: PlaybackStatus.ended at 0:00:01.809000; no decoded audio written (afile output) |
| formats | vlc | pack-all-362-cue | allow_failure | 已知未通过：ended without reporting playback time (video null) |
| formats | vlc | pack-all-365-mmf | allow_failure | 已知未通过：audio stalled: decoded 0, played 0 in 1 s; seek to 1536 ms from 957 ms: PlaybackStatus.ended at 0:00:00.957000 |
| formats | vlc | pack-all-369-pls | allow_failure | 已知未通过：ended without reporting playback time (video null) |
| formats | vlc | webm-vp9-opus | pass | 已有通过记录，必须保持通过 |
| iso | auto | iso-bluray-bdmv | pass | 已有通过记录，必须保持通过 |
| iso | auto | iso-dvd-video | pass | 已有通过记录，必须保持通过 |
| iso | auto | iso-kodi-3dlr-patterns | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-01-Untitled-partial-oma | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-102400samples_qt-lc-aac-m4a | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-2.0_32-bit_float-wv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-4.75k-amr | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-Beethovens_9th-1_small-wma | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-C0023S01-mxf | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-Closedcaption_rollup-m2v | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-Enigma_Principles_of_Lust-part-flv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-FLCL_Ending_My-short-wav | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-PVA_test-partial-pva | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-RA5.0_16kbps_voice_wideband-ra | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-RRSF49-short-webm | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-SA00040-vc1 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-Today-nuv | allow_failure | 当前修复复测仍未通过：video stalled: decoded 0, displayed 0 in 1 s |
| public | auto | public-ffmpeg-fate-Vertical400kbit.sorenson3-mov | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-achterba-vqf | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-al_sbr_ps_04_new-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-atmos-thd | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-audio_id_ims_25fps-ts | allow_failure | 当前修复复测仍未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video null |
| public | auto | public-ffmpeg-fate-banjo_48_2_303-qoa | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-binkaudio_rdft-bik | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-bug821-2-asf | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-bush-aa | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-caf-pcm16-caf | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-cavs-mpg | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-csi_miami_5.1_256_spx_small-eac3 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-ct_ending_cut-mov | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-demo11_02_partial-ast | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-dtsx_7.1.4_24bit-dts | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-empty_theora_packets-ogv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-ergon-xwma | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-evrc-qcp | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-fli-engines-fli | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-fragmented-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-frames_refs_short_signaling-ivf | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-h264small-ts | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-ilbc-lost-mov | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-inside-mp7-mpc | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-interlaced32x32-avi | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-law-and-order-partial-wtv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-loz-mm-mikau-bcstm | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-lozswd_partial-brstm | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-luckynight-mac394b1-c2000-ape | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-luckynight-partial-shn | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-master_audio_2.0_24bit-wma | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-master_audio_7.1_24bit-dts | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-mc_sich_at3_105_small-wav | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-millers_crossing_4.0-ac3 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-mpeg2_field_encoding-ts | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-mpegh_config_change_cicp_2_14_6_lc_baseline_compatible_32kbps-mp4 | allow_failure | 当前修复复测仍未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video null |
| public | auto | public-ffmpeg-fate-packed_maindata.mp3-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-potter512-400-partial-avi | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-ra_cook-rm | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-seed-6k60-awb | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-shakespr_partial-adp | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-sonateno14op27-2-cut-aa3 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-spherical-mkv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-streaming_CBR-7K-wma | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-test72x72-rmhd | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-test_000096-iamf | allow_failure | 当前修复复测仍未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video null |
| public | auto | public-ffmpeg-fate-test_tones_small-aea | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-testvector12-mka | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-tos-ogg | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-vp31-avi | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-w64-pcm16-w64 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-wetlogo-smk | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-witchblade-51kbps-nsv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-fate-wmv_drm-wmv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-samples-07011600-msv | allow_failure | 已知未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video null |
| public | auto | public-ffmpeg-samples-REC01-act | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-samples-SS2-dvr-ms | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-samples-md_ogg-ogm | pass | 已有通过记录，必须保持通过 |
| public | auto | public-ffmpeg-samples-s2short1-viv | allow_failure | 已知未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video Size(160.0, 120.0) |
| public | auto | public-ffmpeg-samples-taxis-dvf | allow_failure | 已知未通过：did not start: PlaybackStatus.error, position 0:00:00.000000, video null |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_10M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_15M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_20M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_25M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_30M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_3M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_10bit_5M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_10M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_15M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_20M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_25M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_30M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_3M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AV1_HDR10_5M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_10M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_15M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_20M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_30M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_3M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_AVC_5M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_DV_P5-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_DV_P8.1-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_DV_P8.4-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_10M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_15M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_20M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_30M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_3M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_10bit_5M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_10M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_15M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_20M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_25M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_30M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_3M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_8bit_5M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_10M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_15M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_20M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_30M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_3M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_1080p_HEVC_HDR10_5M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_100M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_40M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_50M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_60M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_70M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_80M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_10bit_90M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_100M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_40M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_50M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_60M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_70M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_80M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AV1_HDR10_90M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_100M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_150M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_40M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_50M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_60M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_70M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_80M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_AVC_90M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_DV_P5-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_DV_P8.1-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_DV_P8.4-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_100M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_150M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_40M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_50M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_60M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_70M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_80M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_10bit_90M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_100M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_150M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_40M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_50M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_60M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_70M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_80M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_8bit_90M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_100M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_150M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_40M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_50M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_60M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_70M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_80M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_4K_HEVC_HDR10_90M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_AV1_10bit_100M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_AV1_HDR10_100M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_AVC_150M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_DV_P5-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_DV_P8.1-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_DV_P8.4-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_HEVC_10bit_150M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_HEVC_8bit_150M-mp4 | allow_failure | 已知未通过：pictures dropped: 41 lost, 62 displayed in 1 s |
| public | auto | public-jellyfin-test-videos-Test_Jellyfin_8K_HEVC_HDR10_150M-mp4 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-kodi-samples-305_24p-mp4 | allow_failure | 已知未通过：audio stalled: decoded 0, played 0 in 1 s; no audio statistics (astats) |
| public | auto | public-kodi-samples-3D_LR_Pattern-mkv | allow_failure | 已知未通过：audio stalled: decoded 0, played 0 in 1 s; no audio statistics (astats) |
| public | auto | public-kodi-samples-HDR10__Sample_Video-webm | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-3d_foot-gdm | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-4th_Symmetriad-it | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-Crockett_s_theme-sfx | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-FROZEN-dmf | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-Gaffeltruck-mod | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-Inertiaload-1-med | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-Jarre-Like-med | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-Yes-PartII-okt | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-astaris-imf | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-cybocult-ult | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-fracture-stm | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-ft2_delay_envelope_on-xm | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-inside_out-s3m | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-it_high_offset_memory-it | allow_failure | 已知未通过：did not start: PlaybackStatus.ended, position 0:00:00.709583, video null |
| public | auto | public-libxmp-musicind-amf | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-oxygene2-mod | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-reverse_it-it | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-s3m_sample_porta-s3m | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-sonic_boom-669 | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-stereo-xm | pass | 已有通过记录，必须保持通过 |
| public | auto | public-libxmp-thunddrm-far | pass | 已有通过记录，必须保持通过 |
| public | auto | public-matroska-test-files-test1-mkv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-matroska-test-files-test2-mkv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-matroska-test-files-test3-mkv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-matroska-test-files-test4-mkv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-matroska-test-files-test5-mkv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-matroska-test-files-test6-mkv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-matroska-test-files-test7-mkv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-matroska-test-files-test8-mkv | pass | 已有通过记录，必须保持通过 |
| public | auto | public-pixeltools-cea708_dtv-mpg | pass | 暂无实测结果，默认必须通过，未自动豁免 |
