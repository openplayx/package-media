// Apple TV playback smoke test for MpvBackend (flutter-tvos has no
// integration_test runner here). Run by tool/test_formats.sh for an Apple TV
// simulator: flutter-tvos run -t lib/tvos_smoke.dart with
// --dart-define=OPX_SAMPLES_B64=<base64 sample list>. Prints each sample's
// result (the fields of integration_test/formats_test.dart for the checks it
// runs) as base64 JSON in OPX_CHUNK lines, then OPX_DONE, and exits.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:openplayx_media/openplayx_media.dart';

const _samplesBase64 = String.fromEnvironment('OPX_SAMPLES_B64');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final host = ValueNotifier<Widget>(const SizedBox());
  runApp(
    ColoredBox(
      color: const Color(0xFF000000),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<Widget>(
          valueListenable: host,
          builder: (_, child, _) => Center(child: child),
        ),
      ),
    ),
  );
  final samples = [
    for (final s
        in (jsonDecode(utf8.decode(base64.decode(_samplesBase64)))
                as Map<String, dynamic>)['samples']
            as List)
      s as Map<String, dynamic>,
  ];
  for (final sample in samples) {
    final result = await _check(sample, host);
    // flutter-tvos forwards the simulator log, which mangles quotes and long
    // lines: base64 in short chunks, joined again by tool/test_formats.sh.
    final encoded = base64.encode(utf8.encode(jsonEncode(result)));
    const chunk = 400;
    final parts = (encoded.length / chunk).ceil();
    for (var i = 0; i < parts; i++) {
      final end = math.min(encoded.length, (i + 1) * chunk);
      // ignore: avoid_print
      print(
        'OPX_CHUNK ${sample['id']} $i/$parts ${encoded.substring(i * chunk, end)}',
      );
    }
  }
  // ignore: avoid_print
  print('OPX_DONE');
  exit(0);
}

Future<Map<String, dynamic>> _check(
  Map<String, dynamic> sample,
  ValueNotifier<Widget> host,
) async {
  final failures = <String>[];
  final metrics = <String, Object?>{};
  final result = <String, dynamic>{
    'id': sample['id'],
    'ext': sample['ext'],
    'linear': sample['linear'],
    'probe': sample['probe'],
    'engine': 'mpv',
    'metrics': metrics,
  };
  if (sample['status'] != 'ok') {
    failures.add('sample could not be prepared: ${sample['error']}');
    return result..addAll({'failures': failures, 'result': 'failed'});
  }
  final expect = sample['expect'] as Map<String, dynamic>;
  final probe = sample['probe'] as Map<String, dynamic>;
  final wantVideo = expect['video'] == true;
  final wantAudio = expect['audio'] == true;
  final backend = MpvBackend(
    mpvOptions: {
      'ao': 'null',
      if (wantAudio)
        'af': '@st:lavfi=[lowpass=f=3000,astats=metadata=1:reset=50]',
    },
  );
  host.value = SizedBox(width: 320, height: 240, child: backend.buildVideo());
  final frames = <(double, double)>[];
  final sampler = !wantAudio
      ? null
      : Timer.periodic(const Duration(milliseconds: 200), (_) async {
          try {
            final st = jsonDecode(
              await backend.getProperty('af-metadata/st'),
            ) as Map<String, dynamic>;
            final db = double.tryParse(
              '${st['lavfi.astats.Overall.RMS_level']}',
            );
            final zcr = double.tryParse(
              '${st['lavfi.astats.1.Zero_crossings_rate']}',
            );
            if (db != null && zcr != null) frames.add((db, zcr));
          } catch (_) {}
        });
  Future<bool> waitFor(bool Function() condition, Duration timeout) async {
    final watch = Stopwatch()..start();
    while (watch.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (condition()) return true;
    }
    return false;
  }

  try {
    final path = sample['path'] as String;
    final opened = Stopwatch()..start();
    await backend.open(
      path.startsWith('http') ? Uri.parse(path) : Uri.file(path),
    );
    final started = await waitFor(
      () =>
          backend.value.status == PlaybackStatus.error ||
          (backend.value.status == PlaybackStatus.playing &&
              backend.value.position > const Duration(milliseconds: 300) &&
              (!wantVideo || backend.value.videoSize != null)),
      const Duration(seconds: 15),
    );
    metrics['start_ms'] = opened.elapsedMilliseconds;
    if (!started || backend.value.status != PlaybackStatus.playing) {
      failures.add('did not start: ${backend.value.status}');
    } else {
      final size = backend.value.videoSize;
      if (wantVideo) {
        metrics['video_size'] =
            '${size?.width.round()}x${size?.height.round()}';
        if (size == null || size.height.round() != probe['height']) {
          failures.add(
            'video size $size, expected ${probe['width']}x${probe['height']}',
          );
        }
      }
      final total = backend.value.duration;
      metrics['duration_ms'] = total.inMilliseconds;
      final target = total > Duration.zero
          ? total ~/ 2
          : const Duration(seconds: 3);
      await backend.seek(target);
      final landed = await waitFor(
        () =>
            backend.value.status == PlaybackStatus.playing &&
            (backend.value.position - target).abs() <
                const Duration(milliseconds: 600),
        const Duration(seconds: 5),
      );
      metrics['seek_landed_ms'] = backend.value.position.inMilliseconds;
      if (!landed) failures.add('seek to ${target.inMilliseconds} ms failed');
      await waitFor(
        () => backend.value.status == PlaybackStatus.ended,
        total - target + const Duration(seconds: 4),
      );
      metrics['end_status'] = backend.value.status.name;
      if (backend.value.status != PlaybackStatus.ended) {
        failures.add('did not reach the end after seeking');
      }
    }
  } catch (e) {
    failures.add('error: $e');
  } finally {
    sampler?.cancel();
    host.value = const SizedBox();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    backend.dispose();
  }
  if (wantAudio) {
    final rate = (probe['sample_rate'] as int?) ?? 48000;
    final audible = [
      for (final f in frames)
        if (f.$1.isFinite && f.$1 > -60) f,
    ];
    double median(List<double> v) => (v..sort())[v.length ~/ 2];
    if (audible.isEmpty) {
      failures.add('silent or no audio statistics');
    } else {
      final rms = math.pow(10, median([for (final f in audible) f.$1]) / 20);
      final hz = median([for (final f in audible) f.$2]) * rate / 2;
      metrics['audio_rms'] = double.parse(rms.toStringAsFixed(4));
      metrics['audio_hz'] = hz.round();
      final tone = expect['tone_hz'] as int?;
      if (tone != null && (hz - tone).abs() > tone * 0.05) {
        failures.add('wrong sound: ${hz.round()} Hz, expected $tone Hz');
      }
    }
  }
  return result..addAll({
    if (failures.isNotEmpty) 'failures': failures,
    'result': failures.isEmpty ? 'passed' : 'failed',
  });
}
