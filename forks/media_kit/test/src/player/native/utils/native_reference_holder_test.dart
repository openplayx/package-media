import 'dart:io';
import 'dart:isolate';

import 'package:media_kit/src/player/native/utils/process_identity.dart';
import 'package:test/test.dart';

void main() {
  test('process start identity survives Dart isolate replacement', () async {
    final token = nativeProcessStartToken();
    expect(token, isNotEmpty);
    expect(await Isolate.run(nativeProcessStartToken), token);
  });

  test('a stale PID pointer file cannot be dereferenced', () async {
    final config = await Isolate.packageConfig;
    final probe = File(
      'test/src/player/native/utils/native_reference_holder_probe.dart',
    ).absolute.path;
    final result = await Process.run(Platform.resolvedExecutable, [
      if (config != null) '--packages=$config',
      probe,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('stale PID pointer ignored'));
  });
}
