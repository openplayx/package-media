// File format playback tests for one engine: one test per sample of
// formats/manifest.json, prepared by
// tool/prepare_samples.py. Run them with tool/test_formats.sh, which passes:
//   --dart-define=OPX_SAMPLES=<resolved samples json>
//   --dart-define=OPX_REPORT=<report directory>
//   --dart-define=OPX_ENGINE=mpv|vlc|auto (default mpv; auto: RoutedPlayerBackend,
//     the engine router the app uses)
//
// Each sample plays through the engine's PlayerBackend, i.e. the same
// libmpv/libVLC build and options as the app:
//   1. start: playing state and advancing position;
//   2. pipeline: VLC decoder statistics (decoded/displayed/lost pictures,
//      decoded/played/lost audio buffers) and the discovered tracks;
//   3. picture: the snapshot compared with the known SMPTE bars (corrupt or
//      green/grey frames, wrong colours);
//   4. sound: the decoded audio's level and frequency compared with the
//      1 kHz tone (silence, noise, wrong decoding). libVLC writes it to a WAV
//      file (afile output); mpv measures it with FFmpeg's astats filter and
//      plays to a null output. Neither reaches the speakers;
//   5. duration, video size, and a forward seek that plays on to the end.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:openplayx_media/openplayx_media.dart';

const _samplesPath = String.fromEnvironment('OPX_SAMPLES');

/// Remote runs (Android): the sample list itself, base64 JSON, because the
/// device cannot read the host's file.
const _samplesBase64 = String.fromEnvironment('OPX_SAMPLES_B64');
const _reportPath = String.fromEnvironment('OPX_REPORT');
const _engine = String.fromEnvironment('OPX_ENGINE', defaultValue: 'mpv');

/// Diagnostics only: play through the system audio output instead of the
/// afile WAV output (the sound checks then fail for lack of a file).
const _systemAudio = bool.fromEnvironment('OPX_SYSTEM_AUDIO');

/// Check mode: 'full' runs all playback assertions; 'green_bar' only opens
/// video samples, takes a snapshot, and checks for YUV green padding bars.
const _checkMode = String.fromEnvironment(
  'OPX_CHECK_MODE',
  defaultValue: 'full',
);

/// Mean absolute RGB difference (0..255) on the comparison grid above which a
/// snapshot no longer shows the expected picture. Lossy codecs and colour
/// matrix differences stay well below it; corruption does not.
const _maxFrameDiff = 24.0;

/// How much of the media may be left unplayed when playback after a seek
/// ends. With the afile output, libVLC's clock trails the audio already
/// written, so audio-only media report the end ~1.3 s early (up to ~2 s at
/// 8 kHz); with video the clock follows the pictures. A demuxer that stops
/// early leaves more.
const _maxEndTailVideo = Duration(milliseconds: 1500);
const _maxEndTailAudioOnly = Duration(milliseconds: 2300);

/// Share of lost pictures / audio buffers tolerated in the sampling window.
const _maxLossRatio = 0.1;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Playback assertions observe native state and snapshots. Keep real frames
  // running, but do not make timed polling wait for an extra vsync: macOS may
  // withhold it from a test window while the host changes foreground apps.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  if (_samplesPath.isEmpty && _samplesBase64.isEmpty) {
    test('format samples are configured', () {
      fail('OPX_SAMPLES is not set; run tool/test_formats.sh');
    });
    return;
  }
  final samples = [
    for (final s
        in (jsonDecode(
              _samplesBase64.isNotEmpty
                  ? utf8.decode(base64.decode(_samplesBase64))
                  : File(_samplesPath).readAsStringSync(),
            ) as Map<String, dynamic>)['samples']
            as List)
      s as Map<String, dynamic>,
  ];
  // On a device (Android) the host's report directory does not exist: the
  // results are printed (OPX_RESULT lines) and collected from the log.
  var reportDir = Directory(_reportPath);
  try {
    reportDir.createSync(recursive: true);
  } catch (_) {
    reportDir = Directory.systemTemp.createTempSync('opx-formats');
  }
  final results = <Map<String, dynamic>>[];
  tearDownAll(() {
    // One file per app launch; tool/format_report.py merges them.
    final name = File(_samplesPath.isEmpty ? 'samples.json' : _samplesPath)
        .uri
        .pathSegments
        .last
        .replaceAll('samples', 'results');
    File('${reportDir.path}/$name').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({'results': results}),
    );
  });

  for (final sample in samples) {
    testWidgets(sample['id'] as String, (tester) async {
      final check = _Check(sample);
      results.add(check.result);
      if (sample['status'] != 'ok') {
        check.fail('sample could not be prepared: ${sample['error']}');
      } else {
        try {
          await _stageDeviceFiles(sample);
          await check.run(tester, reportDir);
        } catch (error) {
          check.fail('sample execution failed: $error');
        }
      }
      check.result['result'] = check.failures.isEmpty ? 'passed' : 'failed';
      // ignore: avoid_print
      print('OPX_RESULT ${jsonEncode(check.result)}');
      expect(check.failures, isEmpty, reason: check.failures.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}

/// Android cannot open host paths. Inputs needing native filesystem access
/// (disc images/directories, split volumes, pointers and subtitles) are staged
/// into the app's own temporary directory; other media stream over HTTP Range.
Future<void> _stageDeviceFiles(Map<String, dynamic> sample) async {
  final files = sample['device_files'] as List?;
  if (files == null || files.isEmpty) return;
  final directory = await Directory.systemTemp.createTemp('opx-materials-');
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
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: Uri.parse(item['url'] as String),
        );
      }
      await response
          .pipe(output.openWrite())
          .timeout(const Duration(minutes: 5));
    }
  } finally {
    client.close(force: true);
  }
  dynamic relocate(dynamic value) {
    if (value is String) {
      return value.replaceAll('OPX_LOCAL/', '${directory.path}/');
    }
    if (value is List) return value.map(relocate).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k as String, relocate(v)));
    }
    return value;
  }

  final relocated = relocate(sample) as Map<String, dynamic>;
  sample
    ..clear()
    ..addAll(relocated);
}

class _Check {
  _Check(this.sample)
    : result = {
        'id': sample['id'],
        'ext': sample['ext'],
        'linear': sample['linear'],
        'probe': sample['probe'],
        'note': sample['note'],
      };

  final Map<String, dynamic> sample;
  final Map<String, dynamic> result;
  final failures = <String>[];
  final metrics = <String, Object?>{};

  Map<String, dynamic> get expectations =>
      sample['expect'] as Map<String, dynamic>;
  Map<String, dynamic> get probe => sample['probe'] as Map<String, dynamic>;

  void fail(String message) {
    failures.add(message);
    result['failures'] = failures;
  }

  Future<void> run(WidgetTester tester, Directory reportDir) async {
    result['metrics'] = metrics;
    final id = sample['id'] as String;
    final wantVideo = expectations['video'] == true;
    final wantAudio = expectations['audio'] == true;
    if (_checkMode == 'green_bar' && !wantVideo) {
      metrics['check_mode'] = 'green_bar';
      metrics['green_bar_skipped'] = 'no_video';
      return;
    }
    final referenceRms = (expectations['reference_audio_rms'] as num?)
        ?.toDouble();
    final referenceSeconds = (expectations['reference_audio_seconds'] as num?)
        ?.toDouble();
    // FATE includes individual 20 ms audio packets. Repeat those original
    // bytes during inspection so progress/statistics can actually be sampled.
    final repeatShortAudio =
        !wantVideo &&
        referenceSeconds != null &&
        referenceSeconds > 0 &&
        referenceSeconds < 1;
    if (repeatShortAudio) metrics['repeated_short_audio'] = true;
    // Real corpus clips include very quiet codec test signals. Compare with
    // their decoded source instead of treating everything below -60 dB as mute.
    final minimumRms = referenceRms == null ? 0.001 : referenceRms * 0.1;
    if (referenceRms != null) metrics['reference_audio_rms'] = referenceRms;
    final wav = File('${reportDir.path}/$id.wav');
    if (wav.existsSync()) wav.deleteSync();
    // Decoded audio is measured without reaching the speakers.
    // On macOS, ao=null leaves CoreAudio idle, so macOS throttles background
    // rendering after ~35 s (ALL-371); mute=yes keeps the speakers silent while
    // keeping CoreAudio active (af=astats runs before mute).
    PlayerBackend createMpv() => MpvBackend(
      mpvOptions: {
        if (Platform.isMacOS)
          'mute': _systemAudio ? 'no' : 'yes'
        else if (!_systemAudio)
          'ao': 'null',
        'log-file': '${reportDir.path}/$id-mpv.log',
        'msg-level': 'all=warn',
        if (repeatShortAudio) 'loop-file': 'inf',
        // Statistics over 50 codec frames (TrueHD frames are only 40
        // samples) behind a low-pass: lossy codecs add noise around
        // zero that would count as crossings.
        if (wantAudio)
          'af': '@st:lavfi=[lowpass=f=3000,astats=metadata=1:reset=50]',
      },
    );
    PlayerBackend createVlc() => LibVlcBackend(
      extraOptions: wantAudio && !_systemAudio
          ? [
              '--aout=afile',
              '--audiofile-file=${wav.path}',
              '--audiofile-format=s16',
              '--audiofile-wav',
            ]
          : const [],
    );
    final routed = _engine == 'auto'
        ? RoutedPlayerBackend(createMpv: createMpv, createVlc: createVlc)
        : null;
    final PlayerBackend backend =
        routed ?? (_engine == 'mpv' ? createMpv() : createVlc());
    // The engine backend actually playing (the router's choice in auto mode).
    PlayerBackend engineBackend() => routed?.inner ?? backend;
    bool isMpv() => engineBackend() is MpvBackend;
    void recordEngine() => result['engine'] = routed == null
        ? _engine
        : 'auto:${routed.engine?.name}${routed.fellBack ? ' (fallback)' : ''}';
    recordEngine();
    // mpv: cumulative astats of the decoded audio.
    Future<Map<String, dynamic>> astats() async {
      final engine = engineBackend();
      if (engine is! MpvBackend) return const {};
      try {
        return jsonDecode(await engine.getProperty('af-metadata/st'))
            as Map<String, dynamic>;
      } catch (_) {
        return const {};
      }
    }

    // mpv: audio frames seen, sampled every 200 ms (RMS dB, crossings rate).
    final frames = <(double, double)>[];
    var sampledFrames = 0;
    final sampler = !wantAudio || _engine == 'vlc'
        ? null
        : Timer.periodic(const Duration(milliseconds: 200), (_) async {
            if (!isMpv()) return;
            final st = await astats();
            final rmsText = '${st['lavfi.astats.Overall.RMS_level']}';
            final db = rmsText == '-inf'
                ? double.negativeInfinity
                : double.tryParse(rmsText);
            final zcr = double.tryParse(
              '${st['lavfi.astats.1.Zero_crossings_rate']}',
            );
            if (db != null && zcr != null) {
              sampledFrames++;
              frames.add((db, zcr));
            }
          });
    addTearDown(() => sampler?.cancel());
    Future<int?> audioSamples() async => isMpv() ? sampledFrames : null;
    _Level? mpvLevel;
    var disposed = false;
    Future<void> release() async {
      if (disposed) return;
      disposed = true;
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
      // libVLC finishes the WAV file when its audio output closes.
      await tester.pump(const Duration(milliseconds: 500));
    }

    addTearDown(release);

    Future<bool> waitFor(
      bool Function() condition, {
      Duration timeout = const Duration(seconds: 10),
    }) async {
      final watch = Stopwatch()..start();
      while (watch.elapsed < timeout) {
        await tester.pump(const Duration(milliseconds: 100));
        if (condition()) return true;
      }
      return false;
    }

    final width = (probe['width'] as int?) ?? 320;
    final height = (probe['height'] as int?) ?? 240;
    await tester.pumpWidget(
      ColoredBox(
        color: const Color(0xFF000000),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: width.toDouble(),
              height: height.toDouble(),
              child: PlayerVideoView(backend: backend),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // 1. Start.
    final opened = Stopwatch()..start();
    final path = sample['path'] as String;
    // Frames keep coming while opening: in auto mode the engine is created
    // inside open(), and its setup needs the frame loop running.
    var openDone = false;
    final opening = backend
        .open(
          Uri.tryParse(path)?.hasScheme == true
              ? Uri.parse(path)
              : Uri.file(path),
        )
        .whenComplete(() => openDone = true);
    await waitFor(() => openDone, timeout: const Duration(seconds: 15));
    await opening;
    final started = await waitFor(
      () =>
          backend.value.status == PlaybackStatus.error ||
          (backend.value.status == PlaybackStatus.playing &&
              (repeatShortAudio
                  ? sampledFrames > 0
                  : backend.value.position >
                        const Duration(milliseconds: 300)) &&
              (!wantVideo || backend.value.videoSize != null)),
      timeout: const Duration(seconds: 15),
    );
    metrics['start_ms'] = opened.elapsedMilliseconds;
    recordEngine();
    if (!started || backend.value.status != PlaybackStatus.playing) {
      final ended = backend.value.status == PlaybackStatus.ended;
      fail(
        ended && backend.value.position == Duration.zero
            ? 'ended without reporting playback time (video '
                  '${backend.value.videoSize})'
            : 'did not start: ${backend.value.status}, position '
                  '${backend.value.position}, video ${backend.value.videoSize}',
      );
      await release();
      return;
    }

    // 3. Picture (early, while the media is certainly still playing).
    final frameRef = expectations['frame'] as String?;
    if (wantVideo) {
      try {
        final png = await backend.takeSnapshot();
        File('${reportDir.path}/$id.png').writeAsBytesSync(png);
        result['snapshot'] = '$id.png';
        final picture = img.decodeImage(png);
        if (picture != null) {
          final greenBorder = _detectGreenPaddingBar(picture);
          if (greenBorder != null) {
            metrics['green_border'] = greenBorder;
            fail('snapshot has green padding bar: $greenBorder');
          }
        }
        if (_checkMode == 'green_bar') {
          metrics['check_mode'] = 'green_bar';
          return;
        }
        final color = expectations['mean_chroma'] as List?;
        if (color != null) {
          final decoded = picture ?? img.decodeImage(png)!;
          final sums = [0.0, 0.0, 0.0];
          for (
            var y = 0;
            y < decoded.height;
            y += math.max(1, decoded.height ~/ 36)
          ) {
            for (
              var x = 0;
              x < decoded.width;
              x += math.max(1, decoded.width ~/ 64)
            ) {
              final pixel = decoded.getPixel(x, y);
              sums[0] += pixel.r;
              sums[1] += pixel.g;
              sums[2] += pixel.b;
            }
          }
          final total = sums.reduce((a, b) => a + b);
          final chroma = sums.map((s) => total > 0 ? s / total : 0.0).toList();
          metrics['mean_chroma'] = chroma;
          final error = [
            for (var i = 0; i < 3; i++) (chroma[i] - (color[i] as num)).abs(),
          ].reduce(math.max);
          metrics['chroma_error'] = error;
          if (error > (expectations['chroma_tolerance'] as num? ?? 0.12)) {
            fail(
              'snapshot colour cast: normalized mean RGB $chroma, expected ~$color (error $error)',
            );
          }
        }
        if (frameRef != null) {
          final grid = (sample['grid'] as List).cast<int>();
          final diff = await _frameDiff(
            png,
            frameRef.startsWith('http')
                ? await _fetch(frameRef)
                : File(frameRef).readAsBytesSync(),
            grid[0],
            grid[1],
          );
          metrics['frame_diff'] = double.parse(diff.toStringAsFixed(1));
          if (diff > _maxFrameDiff) {
            fail(
              'picture differs from the source (mean diff '
              '${diff.toStringAsFixed(1)} > $_maxFrameDiff): corrupt or wrong colours',
            );
          }
        }
      } catch (e) {
        fail('snapshot failed: $e');
      }
    }

    // 2. Pipeline statistics over one second windows. A window with problems
    // is measured once more: start-up hiccups pass, sustained ones fail.
    for (var window = 1; window <= 2; window++) {
      final problems = await _statsWindow(
        tester,
        backend,
        wantVideo: wantVideo,
        wantAudio: wantAudio,
        audioSamples: isMpv() ? audioSamples : null,
      );
      if (problems.isEmpty) break;
      if (window == 2) problems.forEach(fail);
    }
    try {
      final info = await backend.getMediaInfo();
      final types = [for (final t in info.tracks) t.type];
      metrics['tracks'] = [
        for (final t in info.tracks)
          {
            'type': t.type,
            'codec': t.codec,
            if (t.width != null) 'size': '${t.width}x${t.height}',
            if (t.channels != null) 'channels': t.channels,
            if (t.sampleRate != null) 'rate': t.sampleRate,
          },
      ];
      if (wantVideo && !types.contains('video')) fail('no video track found');
      if (wantAudio && !types.contains('audio')) fail('no audio track found');
    } catch (e) {
      fail('media info failed: $e');
    }

    // Optional external subtitle loading check (ALL-311..ALL-318).
    final extSubPath = expectations['external_subtitle'] as String?;
    if (extSubPath != null && extSubPath.isNotEmpty) {
      try {
        await backend.addExternalSubtitle(Uri.file(extSubPath));
        final loaded = await waitFor(
          () => true,
          timeout: const Duration(milliseconds: 500),
        );
        if (loaded) {
          await tester.pump(const Duration(milliseconds: 400));
        }
        var subTracks = await backend.getSubtitleTracks();
        for (var i = 0; i < 15 && subTracks.isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 200));
          subTracks = await backend.getSubtitleTracks();
        }
        metrics['subtitle_track_count'] = subTracks.length;
        if (subTracks.isEmpty) {
          fail('external subtitle not discovered: $extSubPath');
        } else {
          final eng = engineBackend();
          if (eng is MpvBackend) {
            final codec = await eng
                .getProperty('current-tracks/sub/codec')
                .catchError((_) => '');
            final sid = await eng.getProperty('sid').catchError((_) => '');
            metrics['subtitle_codec'] = codec;
            metrics['subtitle_sid'] = sid;
            if (sid == 'no' || sid.isEmpty) {
              await backend.setSubtitleTrack(subTracks.first.id);
              await tester.pump(const Duration(milliseconds: 300));
            }
            final sidAfter = await eng.getProperty('sid').catchError((_) => '');
            if (sidAfter == 'no' || sidAfter.isEmpty) {
              fail('external subtitle track did not activate (sid=$sidAfter)');
            }
          }
          await backend.disableSubtitle();
          await tester.pump(const Duration(milliseconds: 200));
          await backend.setSubtitleTrack(subTracks.first.id);
          await tester.pump(const Duration(milliseconds: 200));
        }
      } catch (e) {
        fail('external subtitle failed: $e');
      }
    }

    // Optional multi-track audio and subtitle switching checks (e.g. Matroska test5.mkv,
    // embedded subtitles ALL-319..ALL-321).
    final minAudioTracks = expectations['min_audio_tracks'] as int?;
    if (minAudioTracks != null) {
      try {
        final audioTracks = await backend.getAudioTracks();
        metrics['audio_track_count'] = audioTracks.length;
        if (audioTracks.length < minAudioTracks) {
          fail(
            'audio tracks ${audioTracks.length}, expected >= $minAudioTracks',
          );
        } else if (audioTracks.length >= 2) {
          await backend.setAudioTrack(audioTracks[1].id);
          await tester.pump(const Duration(milliseconds: 200));
          await backend.setAudioTrack(audioTracks[0].id);
          await tester.pump(const Duration(milliseconds: 200));
        }
      } catch (e) {
        fail('audio track switching failed: $e');
      }
    }
    final minSubTracks = expectations['min_subtitle_tracks'] as int?;
    if (minSubTracks != null) {
      try {
        var subTracks = await backend.getSubtitleTracks();
        for (var i = 0; i < 15 && subTracks.length < minSubTracks; i++) {
          await tester.pump(const Duration(milliseconds: 200));
          subTracks = await backend.getSubtitleTracks();
        }
        metrics['subtitle_track_count'] = subTracks.length;
        if (subTracks.length < minSubTracks) {
          fail(
            'subtitle tracks ${subTracks.length}, expected >= $minSubTracks',
          );
        } else if (subTracks.isNotEmpty) {
          await backend.setSubtitleTrack(subTracks.first.id);
          await tester.pump(const Duration(milliseconds: 300));
          final eng = engineBackend();
          if (eng is MpvBackend) {
            metrics['subtitle_codec'] = await eng
                .getProperty('current-tracks/sub/codec')
                .catchError((_) => '');
          }
          await backend.disableSubtitle();
          await tester.pump(const Duration(milliseconds: 200));
          await backend.setSubtitleTrack(subTracks.first.id);
          await tester.pump(const Duration(milliseconds: 200));
        }
      } catch (e) {
        fail('subtitle track switching failed: $e');
      }
    }

    // 5. Duration and size.
    final duration = backend.value.duration;
    metrics['duration_ms'] = duration.inMilliseconds;
    final wantDuration = expectations['duration_ms'] as int?;
    if (wantDuration != null &&
        (duration.inMilliseconds - wantDuration).abs() > 700) {
      fail(
        'duration ${duration.inMilliseconds} ms, expected ~$wantDuration ms',
      );
    }
    if (wantVideo) {
      final size = backend.value.videoSize;
      metrics['video_size'] = size == null
          ? null
          : '${size.width.round()}x${size.height.round()}';
      // Storage size (libVLC) or display size after the sample aspect ratio
      // (mpv), e.g. 720x576 or 768x576 for PAL DV.
      final w = probe['width'] as int, h = probe['height'] as int;
      final sar = '${probe['sar'] ?? '1:1'}'
          .split(':')
          .map(int.tryParse)
          .toList();
      final displayW = sar.length == 2 && (sar[0] ?? 0) > 0 && (sar[1] ?? 0) > 0
          ? (w * sar[0]! / sar[1]!).round()
          : w;
      final displayH = sar.length == 2 && (sar[0] ?? 0) > 0 && (sar[1] ?? 0) > 0
          ? (h * sar[1]! / sar[0]!).round()
          : h;
      final matchesStorage =
          size != null && size.width.round() == w && size.height.round() == h;
      final matchesDisplayW =
          size != null &&
          size.height.round() == h &&
          (size.width.round() - displayW).abs() <= 1;
      final matchesDisplayH =
          size != null &&
          size.width.round() == w &&
          (size.height.round() - displayH).abs() <= 1;
      final matchesRotated =
          size != null && size.width.round() == h && size.height.round() == w;
      final matchesStereo3d =
          sample['ext'] == 'mk3d' &&
          size != null &&
          size.width.round() == w &&
          size.height.round() == h * 2;
      if (!matchesStorage &&
          !matchesDisplayW &&
          !matchesDisplayH &&
          !matchesRotated &&
          !matchesStereo3d) {
        fail(
          'video size $size, expected ${w}x$h${displayW != w ? ' or ${displayW}x$h or ${w}x$displayH' : ''}',
        );
      }
    }

    // 5. Forward seek to the middle. Not closer to the end: with the afile
    // output libVLC reaches the end of short files early after a late seek.
    if (expectations['seek'] == true) {
      metrics['seekable'] = backend.value.canSeek;
      if (!backend.value.canSeek) {
        fail('not seekable');
      } else {
        final total = backend.value.duration;
        final target = total > Duration.zero
            ? total ~/ 2
            : const Duration(seconds: 4);
        final from = backend.value.position;
        await backend.seek(target);
        if (backend.value.status == PlaybackStatus.paused ||
            backend.value.status == PlaybackStatus.ended) {
          await backend.play();
        }
        final landed = await waitFor(
          () =>
              backend.value.status == PlaybackStatus.playing &&
              (backend.value.position - target).abs() <
                  const Duration(milliseconds: 600),
          timeout: const Duration(seconds: 5),
        );
        final at = backend.value.position;
        final advances =
            landed &&
            await waitFor(
              () => backend.value.position > at,
              timeout: const Duration(seconds: 3),
            );
        metrics['seek_from_ms'] = from.inMilliseconds;
        metrics['seek_landed_ms'] = at.inMilliseconds;
        if (!landed || !advances) {
          fail(
            'seek to ${target.inMilliseconds} ms from ${from.inMilliseconds} ms: '
            '${backend.value.status} '
            'at ${backend.value.position}',
          );
        } else if (expectations['play_to_end'] == false) {
          // Long real-world files: advancing after the seek is enough.
          metrics['end_status'] = 'skipped (long file)';
        } else {
          // After the seek the media must play on to its end, not stop early.
          final end = Duration(
            milliseconds: wantDuration ?? total.inMilliseconds,
          );
          var furthest = at;
          await waitFor(() {
            if (backend.value.position > furthest) {
              furthest = backend.value.position;
            }
            return backend.value.status == PlaybackStatus.ended;
          }, timeout: end - at + const Duration(seconds: 4));
          final tail = end - furthest;
          metrics['end_status'] = backend.value.status.name;
          metrics['end_tail_ms'] = tail.inMilliseconds;
          // Without a known duration (raw streams) the engine's estimate is
          // no reference: reaching the end is enough.
          if (wantDuration == null) {
            if (backend.value.status != PlaybackStatus.ended) {
              fail('after seeking, playback did not reach the end');
            }
          } else if (tail >
              (wantVideo ? _maxEndTailVideo : _maxEndTailAudioOnly)) {
            fail(
              'after seeking, playback stopped ${tail.inMilliseconds} ms '
              'before the end (${backend.value.status.name} at '
              '${furthest.inMilliseconds} of ${end.inMilliseconds} ms)',
            );
          }
        }
      }
    }

    // 4. Sound: mpv from astats before release; libVLC from the WAV file
    // once its audio output closed it.
    if (isMpv() && wantAudio) {
      if (referenceRms != null && referenceRms > 0) {
        // Some public clips start with silence. The reference covers their
        // first five seconds, so allow that interval before declaring mute.
        await waitFor(
          () => frames.any(
            (f) => f.$1.isFinite && math.pow(10, f.$1 / 20) > minimumRms,
          ),
          timeout: const Duration(seconds: 5),
        );
      }
      sampler?.cancel();
      // astats sees the decoder's rate (before any resampling for output).
      final rate = (probe['sample_rate'] as int?) ?? 48000;
      final audible = [
        for (final f in frames)
          if (f.$1.isFinite && math.pow(10, f.$1 / 20) > minimumRms) f,
      ];
      double median(List<double> v) => (v..sort())[v.length ~/ 2];
      mpvLevel = audible.isEmpty
          ? (frames.isEmpty ? null : const _Level(0, 0, 0))
          : _Level(
              math
                  .pow(10, median([for (final f in audible) f.$1]) / 20)
                  .toDouble(),
              median([for (final f in audible) f.$2]) * rate / 2,
              audible.length * 0.2,
            );
    }
    await release();
    if (wantAudio) {
      final tone = expectations['tone_hz'] as int?;
      if (isMpv()
          ? mpvLevel == null
          : !wav.existsSync() || wav.lengthSync() <= 44) {
        fail(
          isMpv()
              ? 'no audio statistics (astats)'
              : 'no decoded audio written (afile output)',
        );
      } else {
        final level = mpvLevel ?? _measure(wav.readAsBytesSync());
        metrics['audio_rms'] = double.parse(level.rms.toStringAsPrecision(6));
        metrics['audio_hz'] = level.hz.round();
        metrics['audio_seconds'] = double.parse(
          level.seconds.toStringAsFixed(2),
        );
        if (tone != null) {
          if (level.rms < 0.005) {
            fail('silent: RMS ${level.rms.toStringAsFixed(4)}, tone expected');
          } else if ((level.hz - tone).abs() > tone * 0.05) {
            fail(
              'wrong sound: ${level.hz.round()} Hz, expected $tone Hz '
              '(noise or wrong decoding)',
            );
          }
        } else if (level.rms < minimumRms) {
          fail(
            'silent: RMS ${level.rms.toStringAsExponential(4)}'
            ', minimum ${minimumRms.toStringAsExponential(4)}',
          );
        }
      }
      if (wav.existsSync()) wav.deleteSync();
    }
  }

  /// Decoder statistics over one second; returns the problems found.
  Future<List<String>> _statsWindow(
    WidgetTester tester,
    PlayerBackend backend, {
    required bool wantVideo,
    required bool wantAudio,
    Future<int?> Function()? audioSamples,
  }) async {
    final before = await backend.getStats();
    final samplesBefore = await audioSamples?.call();
    await tester.pump(const Duration(milliseconds: 1100));
    final after = await backend.getStats();
    final samplesAfter = await audioSamples?.call();
    if (before == null || after == null) return ['no decoder statistics'];
    final decodedVideo = after.decodedVideo - before.decodedVideo;
    final displayed = after.displayedPictures - before.displayedPictures;
    final lostPictures = after.lostPictures - before.lostPictures;
    // mpv has no audio buffer counters: decoded samples (astats) instead.
    final mpvAudio = audioSamples == null
        ? null
        : (samplesAfter ?? 0) - (samplesBefore ?? 0);
    final decodedAudio = mpvAudio ?? after.decodedAudio - before.decodedAudio;
    final played =
        mpvAudio ?? after.playedAudioBuffers - before.playedAudioBuffers;
    final lostAudio = mpvAudio != null
        ? 0
        : after.lostAudioBuffers - before.lostAudioBuffers;
    metrics.addAll({
      'video_decoded': decodedVideo,
      'video_displayed': displayed,
      'video_lost': lostPictures,
      'audio_decoded': decodedAudio,
      'audio_played': played,
      'audio_lost': lostAudio,
    });
    return [
      if (wantVideo && (decodedVideo <= 0 || displayed <= 0))
        'video stalled: decoded $decodedVideo, displayed $displayed in 1 s'
      else if (wantVideo &&
          lostPictures > _maxLossRatio * (displayed + lostPictures))
        'pictures dropped: $lostPictures lost, $displayed displayed in 1 s',
      if (wantAudio && (decodedAudio <= 0 || played <= 0))
        'audio stalled: decoded $decodedAudio, played $played in 1 s'
      else if (wantAudio && lostAudio > _maxLossRatio * (played + lostAudio))
        'audio buffers lost: $lostAudio lost, $played played in 1 s',
    ];
  }
}

/// Detects a solid YUV-zero green padding bar along the bottom or right edge
/// (a common hardware-decoder slice-height / stride crop bug on 1080p/2160p).
/// Returns a description string when detected, or null when clean.
String? _detectGreenPaddingBar(img.Image image) {
  final w = image.width;
  final h = image.height;
  if (w < 32 || h < 32) return null;

  bool isPaddingGreen(int x, int y) {
    final p = image.getPixel(x, y);
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    return g >= 90 && r <= 45 && b <= 45 && (g - r) >= 65 && (g - b) >= 65;
  }

  // Confirm the interior is not an intentionally green-background frame
  // (e.g. MPAA green-band trailer rating screen or green-screen content).
  var interiorTotal = 0;
  var interiorGreen = 0;
  final sx = math.max(1, w ~/ 32);
  final sy = math.max(1, (h * 3 ~/ 4) ~/ 24);
  for (var y = 0; y < (h * 3) ~/ 4; y += sy) {
    for (var x = 0; x < (w * 3) ~/ 4; x += sx) {
      interiorTotal++;
      if (isPaddingGreen(x, y)) interiorGreen++;
    }
  }
  if (interiorTotal == 0 || interiorGreen / interiorTotal > 0.50) return null;

  bool rowIsGreen(int y) {
    var total = 0;
    var green = 0;
    final rowStep = math.max(1, w ~/ 64);
    for (var x = 0; x < w; x += rowStep) {
      total++;
      if (isPaddingGreen(x, y)) green++;
    }
    return total > 0 && green / total >= 0.90;
  }

  bool colIsGreen(int x) {
    var total = 0;
    var green = 0;
    final colStep = math.max(1, h ~/ 64);
    for (var y = 0; y < h; y += colStep) {
      total++;
      if (isPaddingGreen(x, y)) green++;
    }
    return total > 0 && green / total >= 0.90;
  }

  // Check contiguous green rows from the bottom edge upward (up to 10% of h),
  // ignoring frames whose top edge is also solid green.
  final maxBottomScan = math.max(8, h ~/ 10);
  var bottomGreenRows = 0;
  for (var y = h - 1; y >= h - maxBottomScan; y--) {
    if (rowIsGreen(y)) {
      bottomGreenRows++;
    } else {
      break;
    }
  }
  if (bottomGreenRows >= 4 && !(rowIsGreen(0) && rowIsGreen(3))) {
    return 'bottom ${bottomGreenRows}px green bar (${w}x$h)';
  }

  // Check contiguous green columns from the right edge leftward (up to 10% of w),
  // ignoring frames whose left edge is also solid green.
  final maxRightScan = math.max(8, w ~/ 10);
  var rightGreenCols = 0;
  for (var x = w - 1; x >= w - maxRightScan; x--) {
    if (colIsGreen(x)) {
      rightGreenCols++;
    } else {
      break;
    }
  }
  if (rightGreenCols >= 4 && !(colIsGreen(0) && colIsGreen(3))) {
    return 'right ${rightGreenCols}px green bar (${w}x$h)';
  }
  return null;
}

/// Mean absolute RGB difference between a PNG snapshot and a raw RGB24
/// reference of [gw]×[gh] pixels, after box-averaging the snapshot to the grid.
Future<double> _frameDiff(
  Uint8List png,
  Uint8List reference,
  int gw,
  int gh,
) async {
  // Decoded in Dart: dart:ui needs a GPU context, which a VM may not have
  // (Windows CI: "No Impeller context is available").
  final decoded = img.decodePng(png);
  if (decoded == null) throw const FormatException('snapshot is not a PNG');
  final w = decoded.width, h = decoded.height;
  final rgba = ByteData.sublistView(
    decoded.getBytes(order: img.ChannelOrder.rgba),
  );
  var total = 0.0;
  for (var gy = 0; gy < gh; gy++) {
    final y0 = gy * h ~/ gh, y1 = math.max(y0 + 1, (gy + 1) * h ~/ gh);
    for (var gx = 0; gx < gw; gx++) {
      final x0 = gx * w ~/ gw, x1 = math.max(x0 + 1, (gx + 1) * w ~/ gw);
      final sum = [0, 0, 0];
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final o = (y * w + x) * 4;
          for (var c = 0; c < 3; c++) {
            sum[c] += rgba.getUint8(o + c);
          }
        }
      }
      final n = (y1 - y0) * (x1 - x0);
      for (var c = 0; c < 3; c++) {
        total += (sum[c] / n - reference[(gy * gw + gx) * 3 + c]).abs();
      }
    }
  }
  return total / (gw * gh * 3);
}

class _Level {
  const _Level(this.rms, this.hz, this.seconds);
  final double rms, hz, seconds;
}

/// RMS (0..1) and zero-crossing frequency of the first channel of a 16-bit
/// PCM WAV file. Chunk sizes are not trusted: libVLC may leave them unset.
_Level _measure(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var channels = 2, rate = 48000, offset = 12, start = -1;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    if (id == 'fmt ') {
      channels = data.getUint16(offset + 10, Endian.little);
      rate = data.getUint32(offset + 12, Endian.little);
    }
    if (id == 'data') {
      start = offset + 8;
      break;
    }
    offset += 8 + size + (size & 1);
  }
  if (start < 0 || channels == 0 || rate == 0) return const _Level(0, 0, 0);
  final frames = (bytes.length - start) ~/ (2 * channels);
  // Skip the first 0.2 s (decoder priming, fades).
  final skip = math.min(frames, rate ~/ 5);
  var sum = 0.0;
  var crossings = 0;
  var previous = 0.0;
  for (var i = skip; i < frames; i++) {
    final v = data.getInt16(start + i * 2 * channels, Endian.little) / 32768;
    sum += v * v;
    if (i > skip && (previous < 0) != (v < 0)) crossings++;
    previous = v;
  }
  final n = frames - skip;
  if (n <= 0) return const _Level(0, 0, 0);
  final seconds = n / rate;
  return _Level(math.sqrt(sum / n), crossings / 2 / seconds, frames / rate);
}

/// Bytes of an HTTP resource (samples served by the host in remote runs).
Future<Uint8List> _fetch(String url) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add);
    return builder.takeBytes();
  } finally {
    client.close();
  }
}
