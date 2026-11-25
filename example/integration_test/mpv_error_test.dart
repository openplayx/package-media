import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx_media/openplayx_media.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('fatal end-file still reports error for missing media', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('opx-missing-media-');
    final backend = MpvBackend(mpvOptions: {'ao': 'null'});
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PlayerVideoView(backend: backend),
      ),
    );
    try {
      await tester.runAsync(
        () => backend.open(Uri.file('${dir.path}/missing.mp4')),
      );
      final watch = Stopwatch()..start();
      while (backend.value.status != PlaybackStatus.error &&
          watch.elapsed < const Duration(seconds: 10)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(backend.value.status, PlaybackStatus.error);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      backend.dispose();
      await dir.delete(recursive: true);
    }
  });
}
