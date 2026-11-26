import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx_media/openplayx_media.dart';

void main() {
  final corpusDir = Directory('../materials/playback/public');
  final manifestFile = File('${corpusDir.path}/manifest.json');

  group('Public media corpus (ALL-370)', () {
    test('manifest exists and records source metadata, timestamps, and hashes', () {
      if (!manifestFile.existsSync()) {
        markTestSkipped('materials/playback/public/manifest.json not present');
        return;
      }
      final manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['issue'], 'ALL-370');
      expect(manifest['updated_at'], isA<String>());

      final sources = (manifest['sources'] as List).cast<Map<String, dynamic>>();
      final sourceIds = {for (final s in sources) s['source_id'] as String};
      expect(
        sourceIds,
        containsAll(<String>[
          'jellyfin-test-videos',
          'matroska-test-files',
          'ffmpeg-fate',
          'ffmpeg-samples',
          'libxmp',
        ]),
      );

      for (final source in sources) {
        final sid = source['source_id'] as String;
        final sourceMeta = File('${corpusDir.path}/$sid/SOURCE.json');
        expect(sourceMeta.existsSync(), isTrue, reason: 'missing $sid/SOURCE.json');
        if (source['repo_url'] != null) {
          expect(
            source['commit_hash'],
            matches(RegExp(r'^[0-9a-f]{40}$')),
            reason: '$sid must pin a 40-char git commit hash',
          );
        }
        for (final file in (source['files'] as List).cast<Map<String, dynamic>>()) {
          expect(file['downloaded_at'], isA<String>());
          expect(file['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
          expect(file['source_url'], startsWith('https://'));
          expect(
            File('${corpusDir.path}/${file['relpath']}').existsSync(),
            isTrue,
            reason: 'missing local fixture ${file['relpath']}',
          );
        }
      }
    });

    test('EngineRouter resolves an engine and fallback for every corpus file', () {
      if (!manifestFile.existsSync()) {
        markTestSkipped('materials/playback/public/manifest.json not present');
        return;
      }
      const router = EngineRouter(available: {MediaEngine.mpv, MediaEngine.vlc});
      final manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      final sources = (manifest['sources'] as List).cast<Map<String, dynamic>>();
      var checked = 0;

      for (final source in sources) {
        for (final file in (source['files'] as List).cast<Map<String, dynamic>>()) {
          final uri = Uri.file('${corpusDir.path}/${file['relpath']}');
          final ext = EngineRouter.extensionOf(uri);
          expect(ext, isNotEmpty, reason: 'expected extension for ${file['relpath']}');
          final primary = router.engineFor(uri);
          final fallback = router.fallbackFor(primary);
          final expectedPrimary =
              EngineRouter.vlcExtensions[ext] ?? MediaEngine.mpv;
          final expectedFallback = expectedPrimary == MediaEngine.mpv
              ? MediaEngine.vlc
              : MediaEngine.mpv;
          expect(primary, expectedPrimary);
          expect(fallback, expectedFallback);
          checked++;
        }
      }
      expect(checked, greaterThanOrEqualTo(20));
    });
  });
}
