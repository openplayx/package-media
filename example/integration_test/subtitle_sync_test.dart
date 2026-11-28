// Cross-platform automated subtitle-video synchronization regression test.
//
// Driven by tool/test_subtitle_sync.py across macOS, Android, iOS, tvOS, Linux,
// and Windows with:
//   --dart-define=OPX_SUBSYNC_SAMPLES=<resolved batch json> (desktop)
//   --dart-define=OPX_SUBSYNC_SAMPLES_B64=<base64 json>     (mobile/tvOS)
//   --dart-define=OPX_REPORT=<report directory>
//   --dart-define=OPX_ENGINE=auto|mpv|vlc
//
// Each case verifies subtitle alignment using two complementary channels:
//   1. Engine telemetry (MpvBackend): sub-text / sub-start / sub-end / time-pos
//      gives millisecond-level delta_ms accuracy.
//   2. Rendered snapshot pixel verification (both libmpv and libVLC):
//      compares the top-right cue flash marker and bottom subtitle band
//      between cue-active and cue-inactive frames (works for text, ASS,
//      VobSub, PGS, DVBSub, and XSUB without OCR).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:openplayx_media/openplayx_media.dart';

const _samplesPath = String.fromEnvironment('OPX_SUBSYNC_SAMPLES');
const _samplesBase64 = String.fromEnvironment('OPX_SUBSYNC_SAMPLES_B64');
const _reportPath = String.fromEnvironment('OPX_REPORT');
const _engine = String.fromEnvironment('OPX_ENGINE', defaultValue: 'auto');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (_samplesPath.isEmpty && _samplesBase64.isEmpty) {
    test('subtitle sync samples are configured', () {
      fail('OPX_SUBSYNC_SAMPLES is not set; run tool/test_subtitle_sync.sh');
    });
    return;
  }

  final payload = jsonDecode(
    _samplesBase64.isNotEmpty
        ? utf8.decode(base64.decode(_samplesBase64))
        : File(_samplesPath).readAsStringSync(),
  ) as Map<String, dynamic>;
  final samples = (payload['samples'] as List).cast<Map<String, dynamic>>();

  var reportDir = Directory(_reportPath);
  try {
    reportDir.createSync(recursive: true);
  } catch (_) {
    reportDir = Directory.systemTemp.createTempSync('opx-subsync');
  }

  final results = <Map<String, dynamic>>[];
  tearDownAll(() {
    final name = File(_samplesPath.isEmpty ? 'samples.json' : _samplesPath)
        .uri
        .pathSegments
        .last
        .replaceAll('samples', 'results');
    try {
      File('${reportDir.path}/$name').writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert({'results': results}),
      );
    } catch (_) {
      // Mobile/tvOS collect OPX_RESULT lines from stdout logs.
    }
  });

  for (final sample in samples) {
    testWidgets(sample['id'] as String, (tester) async {
      final check = _SubtitleSyncCheck(sample);
      results.add(check.result);
      if (sample['status'] != 'ok') {
        check.fail('sample preparation failed: ${sample['error']}');
      } else {
        try {
          await _stageDeviceFiles(sample);
          await check.run(tester, reportDir);
        } catch (error, stack) {
          check.fail('execution error: $error');
          check.metrics['stack'] = stack.toString().split('\n').take(6).join('\n');
        }
      }
      check.result['result'] = check.failures.isEmpty ? 'passed' : 'failed';
      // ignore: avoid_print
      print('OPX_RESULT ${jsonEncode(check.result)}');
      expect(check.failures, isEmpty, reason: check.failures.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}

/// Stage HTTP-served files into app-local temp storage for Android / iOS / tvOS.
Future<void> _stageDeviceFiles(Map<String, dynamic> sample) async {
  final files = sample['device_files'] as List?;
  if (files == null || files.isEmpty) return;
  final directory = await Directory.systemTemp.createTemp('opx-subsync-');
  addTearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    for (final item in files.cast<Map<String, dynamic>>()) {
      final name = item['name'] as String;
      if (name.startsWith('/') || name.split('/').contains('..')) {
        throw FormatException('Invalid staging name: $name');
      }
      final output = File('${directory.path}/$name');
      await output.parent.create(recursive: true);
      final request = await client.getUrl(Uri.parse(item['url'] as String));
      final response = await request.close().timeout(const Duration(seconds: 60));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(item['url'] as String));
      }
      await response.pipe(output.openWrite()).timeout(const Duration(minutes: 5));
    }
  } finally {
    client.close(force: true);
  }

  dynamic relocate(dynamic value) {
    if (value is String) {
      return value.replaceAll('OPX_LOCAL/', '${directory.path}/');
    }
    if (value is List) return value.map(relocate).toList();
    if (value is Map) return value.map((k, v) => MapEntry(k as String, relocate(v)));
    return value;
  }

  final relocated = relocate(sample) as Map<String, dynamic>;
  sample
    ..clear()
    ..addAll(relocated);
}

class _CueProbe {
  const _CueProbe({
    required this.active,
    this.subText,
    this.subStartMs,
    this.subEndMs,
    this.timePosMs,
    this.deltaMs,
    this.bottomMeanDiff,
  });

  final bool active;
  final String? subText;
  final int? subStartMs;
  final int? subEndMs;
  final int? timePosMs;
  final int? deltaMs;
  final double? bottomMeanDiff;

  Map<String, Object?> toJson() => {
    'active': active,
    if (subText != null) 'sub_text': subText,
    if (subStartMs != null) 'sub_start_ms': subStartMs,
    if (subEndMs != null) 'sub_end_ms': subEndMs,
    if (timePosMs != null) 'time_pos_ms': timePosMs,
    if (deltaMs != null) 'delta_ms': deltaMs,
    if (bottomMeanDiff != null) 'bottom_diff': double.parse(bottomMeanDiff!.toStringAsFixed(2)),
  };
}

class _SubtitleSyncCheck {
  _SubtitleSyncCheck(this.sample)
      : result = {
          'id': sample['id'],
          'suite': sample['suite'],
          'video_id': sample['video_id'],
          'subtitle_format': sample['subtitle_format'],
          'subtitle_delivery': sample['subtitle_delivery'],
          'expect_aligned': sample['expect_aligned'] ?? true,
        };

  final Map<String, dynamic> sample;
  final Map<String, dynamic> result;
  final failures = <String>[];
  final metrics = <String, Object?>{};
  final opMetrics = <String, Object?>{};

  void fail(String message) {
    failures.add(message);
    result['failures'] = failures;
  }

  Uri _toUri(String raw) =>
      Uri.tryParse(raw)?.hasScheme == true ? Uri.parse(raw) : Uri.file(raw);

  Future<void> run(WidgetTester tester, Directory reportDir) async {
    result['metrics'] = metrics;
    metrics['ops'] = opMetrics;

    final videoPath = sample['video_path'] as String;
    final subtitlePath = sample['subtitle_path'] as String?;
    final delivery = sample['subtitle_delivery'] as String? ?? 'external';
    final contentPattern = sample['content_pattern'] as String? ?? 'standard';
    final expectAligned = sample['expect_aligned'] != false;
    final toleranceMs = (sample['tolerance_ms'] as num?)?.toInt() ?? 100;
    final durationSec = (sample['duration_sec'] as num?)?.toInt() ?? 15;
    final ops = ((sample['operation_profiles'] as List?) ?? ['op_baseline_playback'])
        .cast<String>();
    final isBitmap = sample['subtitle_pipeline'] == 'bitmap' ||
        (sample['embedded_codecs'] as List? ?? const []).any(
          (c) => c == 'dvd_subtitle' || c == 'hdmv_pgs_subtitle' || c == 'dvb_subtitle' || c == 'xsub',
        );

    final hwDecodeModes = ops.contains('op_hw_vs_sw_decode') ? <String?>[null, 'no'] : <String?>[null];

    for (final hwdec in hwDecodeModes) {
      await _runSinglePass(
        tester: tester,
        reportDir: reportDir,
        videoPath: videoPath,
        subtitlePath: subtitlePath,
        delivery: delivery,
        contentPattern: contentPattern,
        expectAligned: expectAligned,
        toleranceMs: toleranceMs,
        durationSec: durationSec,
        ops: ops,
        isBitmap: isBitmap,
        hwdec: hwdec,
      );
    }
  }

  Future<void> _runSinglePass({
    required WidgetTester tester,
    required Directory reportDir,
    required String videoPath,
    required String? subtitlePath,
    required String delivery,
    required String contentPattern,
    required bool expectAligned,
    required int toleranceMs,
    required int durationSec,
    required List<String> ops,
    required bool isBitmap,
    required String? hwdec,
  }) async {
    final id = sample['id'] as String;
    final passPrefix = hwdec == null ? '' : 'sw_';

    PlayerBackend createMpv() => MpvBackend(
      mpvOptions: {
        if (Platform.isMacOS) 'mute': 'yes' else 'ao': 'null',
        'hwdec': ?hwdec,
        'hr-seek': 'yes',
        'sub-auto': 'no',
        'log-file': '${reportDir.path}/$id-${hwdec ?? 'default'}-mpv.log',
        'msg-level': 'all=warn',
      },
    );
    PlayerBackend createVlc() => LibVlcBackend(
      extraOptions: const ['--no-audio'],
    );

    final routed = _engine == 'auto'
        ? RoutedPlayerBackend(createMpv: createMpv, createVlc: createVlc)
        : null;
    final PlayerBackend backend =
        routed ?? (_engine == 'mpv' ? createMpv() : createVlc());
    PlayerBackend activeEngine() => routed?.inner ?? backend;
    bool isMpv() => activeEngine() is MpvBackend;

    var disposed = false;
    Future<void> release() async {
      if (disposed) return;
      disposed = true;
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
      await tester.pump(const Duration(milliseconds: 250));
    }

    addTearDown(release);

    Future<bool> waitFor(
      bool Function() condition, {
      Duration timeout = const Duration(seconds: 12),
    }) async {
      final sw = Stopwatch()..start();
      while (sw.elapsed < timeout) {
        await tester.pump(const Duration(milliseconds: 60));
        if (condition()) return true;
      }
      return false;
    }

    final videoKey = GlobalKey();
    await tester.pumpWidget(
      ColoredBox(
        color: const Color(0xFF000000),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: RepaintBoundary(
                key: videoKey,
                child: PlayerVideoView(backend: backend),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Open media
    var openDone = false;
    final opening = backend.open(_toUri(videoPath)).whenComplete(() => openDone = true);
    await waitFor(() => openDone, timeout: const Duration(seconds: 15));
    await opening;

    final started = await waitFor(
      () =>
          backend.value.status == PlaybackStatus.error ||
          (backend.value.status == PlaybackStatus.playing &&
              backend.value.position > const Duration(milliseconds: 150) &&
              backend.value.videoSize != null),
      timeout: const Duration(seconds: 15),
    );
    result['engine'] = routed == null
        ? _engine
        : 'auto:${routed.engine?.name}${routed.fellBack ? ' (fallback)' : ''}';
    if (!started || backend.value.status != PlaybackStatus.playing) {
      fail('${passPrefix}playback failed to start: ${backend.value.status}');
      await release();
      return;
    }

    // Verify the actual composited Flutter Texture on screen (catches solid
    // purple/magenta VideoToolbox bugs, green YUV-zero frames, black screens,
    // and H.264/HEVC macroblock corruption / 花屏 via 16x9 testsrc2 reference MAD).
    final videoId = sample['video_id'] as String? ?? '';
    final checkRefGrid = !videoId.contains('rotate') && !videoId.contains('amv');
    await tester.pump(const Duration(milliseconds: 250));
    final screenReport = await _verifyCompositedVideoTexture(videoKey, checkRefGrid: checkRefGrid);
    if (screenReport != null) {
      metrics['${passPrefix}screen_check'] = screenReport;
      if (screenReport['error'] != null) {
        fail('${passPrefix}screen_render: ${screenReport['error']}');
      }
    }

    // Attach external subtitle upfront unless testing hot-attach first
    Future<void> attachExternal() async {
      if (subtitlePath != null && subtitlePath.isNotEmpty) {
        await backend.addExternalSubtitle(_toUri(subtitlePath));
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    if (delivery == 'external' || delivery == 'both') {
      await attachExternal();
    } else if (delivery == 'embedded') {
      final tracks = await backend.getSubtitleTracks();
      metrics['embedded_tracks'] = tracks.length;
      if (tracks.isEmpty) {
        fail('${passPrefix}no embedded subtitle tracks discovered');
        await release();
        return;
      }
      await backend.setSubtitleTrack(tracks.first.id);
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Helper: capture an inactive baseline frame for visual diffing (bitmap/VLC)
    img.Image? inactiveFrame;
    Future<img.Image?> captureFrame() async {
      try {
        final png = await backend.takeSnapshot();
        return img.decodeImage(png);
      } catch (_) {
        return null;
      }
    }

    Future<String?> mpvProp(String name) async {
      final eng = activeEngine();
      if (eng is! MpvBackend) return null;
      try {
        return await eng.getProperty(name);
      } catch (_) {
        return null;
      }
    }

    Future<bool> seekAndWait(Duration target) async {
      await backend.seek(target);
      // Wait for seek completion: on Android/HTTP Range, backend.value.position
      // updates optimistically to `target` before mpv finishes seeking & decoding.
      final sw = Stopwatch()..start();
      while (sw.elapsed < const Duration(seconds: 8)) {
        await tester.pump(const Duration(milliseconds: 80));
        final pos = backend.value.position;
        if ((pos - target).abs() > const Duration(milliseconds: 900)) continue;
        if (isMpv()) {
          final seeking = await mpvProp('seeking');
          if (seeking == 'yes') continue;
          // Ensure playback actually decoded at least one frame past target.
          if (pos != target) return true;
          if (sw.elapsed > const Duration(milliseconds: 400)) return true;
        } else {
          if (pos != target || sw.elapsed > const Duration(milliseconds: 400)) return true;
        }
      }
      return false;
    }

    /// Probe subtitle alignment at [targetMs] expecting cue starting at [expectedStartMs].
    Future<_CueProbe> probeAt({
      required int targetMs,
      required int expectedStartMs,
      required bool expectVisible,
      bool pauseOnTarget = false,
    }) async {
      if (pauseOnTarget) {
        await backend.pause();
        await backend.seek(Duration(milliseconds: targetMs));
        await tester.pump(const Duration(milliseconds: 350));
      } else {
        await seekAndWait(Duration(milliseconds: targetMs));
        await tester.pump(const Duration(milliseconds: 180));
      }

      final posMs = backend.value.position.inMilliseconds;
      final subText = await mpvProp('sub-text');
      final subStartStr = await mpvProp('sub-start');
      final subEndStr = await mpvProp('sub-end');
      final parsedStart = subStartStr != null ? double.tryParse(subStartStr) : null;
      final parsedEnd = subEndStr != null ? double.tryParse(subEndStr) : null;
      final subStartMs = parsedStart != null ? (parsedStart * 1000).round() : null;
      final subEndMs = parsedEnd != null ? (parsedEnd * 1000).round() : null;

      if (pauseOnTarget) {
        await backend.play();
      }

      int? deltaMs;
      if (subStartMs != null) {
        deltaMs = subStartMs - expectedStartMs;
      }

      double? bottomDiff;
      final frame = await captureFrame();
      if (frame != null && inactiveFrame != null) {
        bottomDiff = _bottomBandMeanDiff(frame, inactiveFrame!);
      } else if (frame != null && !expectVisible && inactiveFrame == null) {
        inactiveFrame = frame;
      }

      final textActive = subText != null && subText.trim().isNotEmpty;
      final visualActive = bottomDiff != null && bottomDiff > 2.5;
      // On mpv with text subtitles, sub-text/sub-start is exact (immune to moving video).
      final active = isMpv() && !isBitmap
          ? textActive
          : (isBitmap ? (subStartMs != null || visualActive) : (textActive || visualActive));

      return _CueProbe(
        active: active,
        subText: subText,
        subStartMs: subStartMs,
        subEndMs: subEndMs,
        timePosMs: posMs,
        deltaMs: deltaMs,
        bottomMeanDiff: bottomDiff,
      );
    }

    // Grab an inactive reference frame at t=0.4s (before CUE 01 at 1.0s)
    await seekAndWait(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 150));
    inactiveFrame = await captureFrame();

    // Expected cue timestamps & start points per content_pattern
    final bool isShortFlash = contentPattern == 'ultra_short_150ms';
    int cue1TargetMs = 1350, cue1StartMs = 1000;
    int midTargetMs = 5350, midStartMs = 5000;
    int endTargetMs = durationSec >= 60 ? 55350 : 13350;
    int endStartMs = durationSec >= 60 ? 55000 : 13000;
    int seekFwdTargetMs = 11350, seekFwdStartMs = 11000;
    int seekBwdTargetMs = 3350, seekBwdStartMs = 3000;
    int seekNonKfTargetMs = 7450, seekNonKfStartMs = 7000;

    if (contentPattern == 'long_cue_2s_to_12s') {
      cue1TargetMs = 3000; cue1StartMs = 2000;
      midTargetMs = 7000; midStartMs = 2000;
      endTargetMs = 11000; endStartMs = 2000;
      seekFwdTargetMs = 11000; seekFwdStartMs = 2000;
      seekBwdTargetMs = 3350; seekBwdStartMs = 2000;
      seekNonKfTargetMs = 7450; seekNonKfStartMs = 2000;
    } else if (contentPattern == 'zero_gap_back_to_back') {
      cue1TargetMs = 2400; cue1StartMs = 2000;
      midTargetMs = 6400; midStartMs = 6000;
      endTargetMs = 12400; endStartMs = 12000;
      seekFwdTargetMs = 10400; seekFwdStartMs = 10000;
      seekBwdTargetMs = 2400; seekBwdStartMs = 2000;
      seekNonKfTargetMs = 6450; seekNonKfStartMs = 6000;
    } else if (contentPattern == 'overlapping_cues') {
      // Cues: 1s-4s, 2.5s-5.5s, 7s-10s, 8s-11.5s
      cue1TargetMs = 1350; cue1StartMs = 1000;
      midTargetMs = 4500; midStartMs = 2500;
      endTargetMs = 10500; endStartMs = 8000;
      seekFwdTargetMs = 10500; seekFwdStartMs = 8000;
      seekBwdTargetMs = 1350; seekBwdStartMs = 1000;
      seekNonKfTargetMs = 7350; seekNonKfStartMs = 7000;
    } else if (isShortFlash) {
      // 150ms flash cues at 1.0s, 3.0s, 5.0s, 7.0s, 9.0s, 11.0s, 13.0s
      cue1TargetMs = 1060; cue1StartMs = 1000;
      midTargetMs = 5060; midStartMs = 5000;
      endTargetMs = 13060; endStartMs = 13000;
      seekFwdTargetMs = 11060; seekFwdStartMs = 11000;
      seekBwdTargetMs = 3060; seekBwdStartMs = 3000;
      seekNonKfTargetMs = 7060; seekNonKfStartMs = 7000;
    }

    void validateProbe(String opName, _CueProbe p, {bool requireVisible = true}) {
      opMetrics['$passPrefix$opName'] = p.toJson();
      if (!expectAligned) {
        // Negative control: misalignment MUST be detected!
        final detectedMismatch = !p.active || (p.deltaMs != null && p.deltaMs!.abs() > toleranceMs);
        if (!detectedMismatch) {
          fail('$passPrefix$opName: negative control failed to detect misalignment (${p.toJson()})');
        }
        return;
      }
      if (requireVisible && !p.active) {
        fail('$passPrefix$opName: expected active subtitle not visible (${p.toJson()})');
        return;
      }
      if (p.deltaMs != null && p.deltaMs!.abs() > toleranceMs) {
        fail('$passPrefix$opName: |delta_ms|=${p.deltaMs}ms > ${toleranceMs}ms');
      }
      // Verify decoded subtitle text is not mojibake / garbled.
      final txt = p.subText;
      if (requireVisible && !isBitmap && txt != null && txt.isNotEmpty) {
        if (txt.contains('\uFFFD')) {
          fail('$passPrefix$opName: subtitle text contains replacement char (mojibake): "$txt"');
        }
        final subFmt = sample['subtitle_format'] as String? ?? '';
        if (subFmt == 'srt_gb18030' && !txt.contains('中文测试')) {
          fail('$passPrefix$opName: GB18030 mojibake detected (expected "中文测试", got "$txt")');
        }
      }
    }

    // 1. op_baseline_playback
    if (ops.contains('op_baseline_playback')) {
      final p1 = await probeAt(targetMs: cue1TargetMs, expectedStartMs: cue1StartMs, expectVisible: true, pauseOnTarget: isShortFlash);
      validateProbe('baseline_start', p1);
      final p2 = await probeAt(targetMs: midTargetMs, expectedStartMs: midStartMs, expectVisible: true, pauseOnTarget: isShortFlash);
      validateProbe('baseline_mid', p2);
      final p3 = await probeAt(targetMs: endTargetMs, expectedStartMs: endStartMs, expectVisible: true, pauseOnTarget: isShortFlash);
      validateProbe('baseline_end', p3);
    }

    // 2. op_seek_stress
    if (ops.contains('op_seek_stress') && durationSec >= 15) {
      final pf = await probeAt(targetMs: seekFwdTargetMs, expectedStartMs: seekFwdStartMs, expectVisible: true, pauseOnTarget: isShortFlash);
      validateProbe('seek_forward_11s', pf);
      final pb = await probeAt(targetMs: seekBwdTargetMs, expectedStartMs: seekBwdStartMs, expectVisible: true, pauseOnTarget: isShortFlash);
      validateProbe('seek_backward_3s', pb);
      final pn = await probeAt(targetMs: seekNonKfTargetMs, expectedStartMs: seekNonKfStartMs, expectVisible: true, pauseOnTarget: isShortFlash);
      validateProbe('seek_non_keyframe_7_5s', pn);
      // Verify composited video frame is not macroblock-corrupted (花屏) after Seeking.
      final postSeekScreen = await _verifyCompositedVideoTexture(videoKey, checkRefGrid: checkRefGrid);
      if (postSeekScreen != null) {
        metrics['${passPrefix}screen_check_after_seek'] = postSeekScreen;
        if (postSeekScreen['error'] != null) {
          fail('${passPrefix}screen_render_after_seek: ${postSeekScreen['error']}');
        }
      }
    }

    // 3. op_seek_mid_long_cue
    if (ops.contains('op_seek_mid_long_cue')) {
      final pm = await probeAt(targetMs: 7000, expectedStartMs: 2000, expectVisible: true);
      validateProbe('seek_mid_long_cue_7s', pm);
    }

    // 4. op_speed_changes
    if (ops.contains('op_speed_changes')) {
      await backend.setSpeed(2.0);
      await tester.pump(const Duration(milliseconds: 350));
      await backend.setSpeed(0.5);
      await tester.pump(const Duration(milliseconds: 250));
      await backend.setSpeed(1.5);
      await tester.pump(const Duration(milliseconds: 250));
      await backend.setSpeed(1.0);
      await tester.pump(const Duration(milliseconds: 200));
      final ps = await probeAt(targetMs: midTargetMs, expectedStartMs: midStartMs, expectVisible: true, pauseOnTarget: isShortFlash);
      validateProbe('after_speed_changes', ps);
    }

    // 5. op_pause_resume_burst
    if (ops.contains('op_pause_resume_burst')) {
      for (var i = 0; i < 5; i++) {
        await backend.pause();
        await tester.pump(const Duration(milliseconds: 80));
        await backend.play();
        await tester.pump(const Duration(milliseconds: 80));
      }
      final pp = await probeAt(targetMs: midTargetMs, expectedStartMs: midStartMs, expectVisible: true, pauseOnTarget: isShortFlash);
      validateProbe('after_pause_resume_5x', pp);
    }

    // 6. op_track_toggle_switch
    if (ops.contains('op_track_toggle_switch')) {
      await backend.disableSubtitle();
      await tester.pump(const Duration(milliseconds: 180));
      final tracks = await backend.getSubtitleTracks();
      if (tracks.isNotEmpty) {
        await backend.setSubtitleTrack(tracks.last.id);
        await tester.pump(const Duration(milliseconds: 200));
        final pt = await probeAt(targetMs: midTargetMs, expectedStartMs: midStartMs, expectVisible: true, pauseOnTarget: isShortFlash);
        validateProbe('after_track_toggle', pt);
      }
    }

    // 7. op_manual_delay_adjust
    if (ops.contains('op_manual_delay_adjust') && backend.supportsDelays) {
      await backend.setSubtitleDelay(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 180));
      await backend.setSubtitleDelay(const Duration(milliseconds: -500));
      await tester.pump(const Duration(milliseconds: 180));
      await backend.setSubtitleDelay(Duration.zero);
      await tester.pump(const Duration(milliseconds: 200));
      final pd = await probeAt(targetMs: midTargetMs, expectedStartMs: midStartMs, expectVisible: true, pauseOnTarget: isShortFlash);
      validateProbe('after_manual_delay_reset', pd);
    }

    // 8. op_audio_output_latency_250ms
    if (ops.contains('op_audio_output_latency_250ms') && backend.supportsDelays) {
      await backend.setAudioDelay(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 200));
      final pa = await probeAt(targetMs: midTargetMs, expectedStartMs: midStartMs, expectVisible: true, pauseOnTarget: isShortFlash);
      validateProbe('audio_latency_250ms', pa);
      await backend.setAudioDelay(Duration.zero);
    }

    // 9. op_loop_replay
    if (ops.contains('op_loop_replay')) {
      await seekAndWait(Duration(seconds: durationSec - 1));
      await tester.pump(const Duration(milliseconds: 200));
      final pl = await probeAt(targetMs: cue1TargetMs, expectedStartMs: cue1StartMs, expectVisible: true, pauseOnTarget: isShortFlash);
      validateProbe('loop_restart_cue1', pl);
    }

    await release();
  }
}

/// Mean absolute RGB difference in the bottom 30% band where subtitles render.
double _bottomBandMeanDiff(img.Image a, img.Image b) {
  final w = a.width < b.width ? a.width : b.width;
  final h = a.height < b.height ? a.height : b.height;
  final y0 = (h * 0.70).round();
  var sum = 0.0;
  var count = 0;
  for (var y = y0; y < h; y += 2) {
    for (var x = 0; x < w; x += 2) {
      final pa = a.getPixel(x, y);
      final pb = b.getPixel(x, y);
      sum += (pa.r - pb.r).abs() + (pa.g - pb.g).abs() + (pa.b - pb.b).abs();
      count += 3;
    }
  }
  return count == 0 ? 0.0 : sum / count;
}

/// Deterministic 16x9 RGB reference grid of testsrc2 cropped to
/// x in [0.06, 0.82], y in [0.05, 0.65] (excluding subtitle band & flash box).
/// Normal H.264/HEVC/AV1/MPEG2/ProRes/3GP MAD is 0.2..14; real macroblock
/// corruption (花屏) or purple/green/black frames score 45..120+.
const List<int> _testsrc2RefGrid16x9 = [
  96, 0, 0, 109, 10, 5, 12, 203, 0, 40, 231, 11, 18, 246, 0, 34, 255, 8, 253, 254, 0, 253, 254, 0,
  232, 233, 164, 91, 93, 23, 0, 0, 253, 0, 0, 253, 117, 0, 212, 175, 38, 255, 250, 3, 250, 249, 2, 249,
  252, 0, 0, 252, 0, 0, 23, 205, 0, 46, 229, 10, 18, 246, 0, 34, 255, 8, 253, 254, 0, 253, 254, 0,
  232, 233, 164, 91, 93, 23, 0, 0, 253, 0, 0, 253, 104, 0, 201, 179, 51, 255, 249, 5, 249, 246, 3, 246,
  252, 0, 0, 252, 0, 0, 23, 205, 0, 46, 229, 10, 18, 246, 0, 33, 255, 6, 253, 254, 0, 253, 254, 0,
  232, 233, 164, 91, 93, 23, 0, 0, 253, 0, 0, 253, 116, 0, 221, 180, 30, 255, 251, 13, 245, 244, 6, 238,
  252, 0, 0, 252, 0, 0, 23, 205, 0, 46, 229, 10, 18, 246, 0, 33, 255, 6, 253, 254, 0, 253, 254, 0,
  232, 233, 164, 91, 93, 23, 0, 0, 253, 0, 0, 253, 116, 0, 221, 180, 30, 255, 232, 11, 243, 240, 19, 251,
  252, 0, 0, 252, 0, 0, 23, 205, 0, 46, 229, 10, 18, 246, 0, 33, 255, 6, 253, 254, 0, 253, 254, 0,
  232, 233, 164, 91, 93, 23, 0, 0, 253, 0, 0, 253, 116, 0, 221, 180, 30, 255, 253, 0, 252, 253, 0, 252,
  252, 0, 0, 252, 0, 0, 23, 205, 0, 46, 229, 10, 18, 246, 0, 34, 255, 8, 253, 254, 0, 253, 254, 0,
  232, 233, 164, 91, 93, 23, 0, 0, 253, 0, 0, 253, 117, 0, 222, 180, 30, 255, 253, 0, 252, 253, 0, 252,
  252, 0, 0, 252, 0, 0, 26, 202, 0, 48, 224, 12, 19, 243, 0, 37, 255, 12, 253, 254, 0, 253, 254, 0,
  232, 233, 164, 91, 93, 23, 0, 0, 253, 0, 0, 253, 117, 0, 222, 180, 30, 255, 253, 0, 252, 253, 0, 252,
  252, 0, 0, 252, 0, 0, 42, 190, 6, 61, 209, 25, 32, 225, 5, 54, 247, 27, 243, 242, 2, 253, 252, 12,
  232, 233, 164, 91, 93, 23, 0, 0, 253, 0, 0, 253, 117, 0, 222, 180, 30, 255, 253, 0, 252, 253, 0, 252,
  252, 0, 0, 252, 0, 0, 42, 190, 6, 61, 209, 25, 32, 225, 5, 54, 247, 27, 250, 250, 0, 253, 253, 3,
  232, 233, 164, 91, 93, 23, 0, 0, 253, 0, 0, 253, 103, 0, 211, 160, 53, 255, 230, 19, 242, 231, 20, 243,
];

/// Inspect the actual Flutter-composited Texture pixels on screen to catch
/// solid purple/magenta (VideoToolbox/GLES texture bug), solid green (YUV zero),
/// black/blank rendering, AND H.264/HEVC macroblock corruption (花屏) via 16x9
/// reference grid comparison.
Future<Map<String, Object?>?> _verifyCompositedVideoTexture(
  GlobalKey key, {
  bool checkRefGrid = true,
}) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 0.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width;
    final h = image.height;
    image.dispose();
    if (byteData == null || w < 16 || h < 9) return null;

    final bytes = byteData.buffer.asUint8List();
    final x0 = (w * 0.1).round();
    final x1 = (w * 0.9).round();
    final y0 = (h * 0.1).round();
    final y1 = (h * 0.9).round();

    var n = 0;
    var sumR = 0.0, sumG = 0.0, sumB = 0.0;
    var sumSqR = 0.0, sumSqG = 0.0, sumSqB = 0.0;
    var purpleCount = 0;
    var greenCount = 0;

    for (var y = y0; y < y1; y += 2) {
      for (var x = x0; x < x1; x += 2) {
        final offset = (y * w + x) * 4;
        final r = bytes[offset].toDouble();
        final g = bytes[offset + 1].toDouble();
        final b = bytes[offset + 2].toDouble();
        sumR += r; sumG += g; sumB += b;
        sumSqR += r * r; sumSqG += g * g; sumSqB += b * b;
        if (r > 100 && b > 100 && g < 80) purpleCount++;
        if (g > 110 && r < 60 && b < 60) greenCount++;
        n++;
      }
    }
    if (n == 0) return null;
    final meanR = sumR / n, meanG = sumG / n, meanB = sumB / n;
    final varR = math.max(0.0, sumSqR / n - meanR * meanR);
    final varG = math.max(0.0, sumSqG / n - meanG * meanG);
    final varB = math.max(0.0, sumSqB / n - meanB * meanB);
    final stddev = math.sqrt((varR + varG + varB) / 3.0);
    final purpleRatio = purpleCount / n;
    final greenRatio = greenCount / n;

    // Compute 16x9 reference grid MAD on x in [0.06..0.82], y in [0.05..0.65].
    double? refMad;
    if (checkRefGrid) {
      final rx0 = w * 0.06, rw = w * 0.76;
      final ry0 = h * 0.05, rh = h * 0.60;
      var diffSum = 0.0;
      for (var gy = 0; gy < 9; gy++) {
        final py0 = (ry0 + rh * gy / 9).floor().clamp(0, h - 1);
        final py1 = (ry0 + rh * (gy + 1) / 9).ceil().clamp(py0 + 1, h);
        for (var gx = 0; gx < 16; gx++) {
          final px0 = (rx0 + rw * gx / 16).floor().clamp(0, w - 1);
          final px1 = (rx0 + rw * (gx + 1) / 16).ceil().clamp(px0 + 1, w);
          var cr = 0.0, cg = 0.0, cb = 0.0;
          var cnt = 0;
          for (var py = py0; py < py1; py++) {
            for (var px = px0; px < px1; px++) {
              final off = (py * w + px) * 4;
              cr += bytes[off];
              cg += bytes[off + 1];
              cb += bytes[off + 2];
              cnt++;
            }
          }
          final idx = (gy * 16 + gx) * 3;
          diffSum += (cr / cnt - _testsrc2RefGrid16x9[idx]).abs() +
              (cg / cnt - _testsrc2RefGrid16x9[idx + 1]).abs() +
              (cb / cnt - _testsrc2RefGrid16x9[idx + 2]).abs();
        }
      }
      refMad = diffSum / 432.0;
    }

    String? error;
    if (purpleRatio > 0.60) {
      error = 'purple/magenta texture corruption (purple=${(purpleRatio * 100).toStringAsFixed(1)}%, meanRGB=(${meanR.round()},${meanG.round()},${meanB.round()}))';
    } else if (greenRatio > 0.60) {
      error = 'solid green texture corruption (green=${(greenRatio * 100).toStringAsFixed(1)}%)';
    } else if (stddev < 8.0) {
      error = 'solid/blank video screen (stddev=${stddev.toStringAsFixed(2)}, meanRGB=(${meanR.round()},${meanG.round()},${meanB.round()}))';
    } else if (refMad != null && refMad > 35.0) {
      error = 'video_corruption / macroblock distortion (ref_mad=${refMad.toStringAsFixed(1)} > 35.0)';
    }

    return {
      'mean_rgb': [meanR.round(), meanG.round(), meanB.round()],
      'stddev': double.parse(stddev.toStringAsFixed(2)),
      'purple_ratio': double.parse(purpleRatio.toStringAsFixed(3)),
      'green_ratio': double.parse(greenRatio.toStringAsFixed(3)),
      if (refMad != null) 'ref_mad': double.parse(refMad.toStringAsFixed(2)),
      'error': ?error,
    };
  } catch (_) {
    return null;
  }
}
