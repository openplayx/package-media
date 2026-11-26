import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx_media/openplayx_media.dart';

/// Engine stand-in: records calls; [failOpen] reports an error on open,
/// [gaveUp] reports that status instead (opening first) without playing.
class _FakeEngine extends PlayerBackend {
  _FakeEngine(this.name, {this.failOpen = false, this.gaveUp, this.failsOn});
  final String name;
  final bool failOpen;
  final PlaybackStatus? gaveUp;

  /// When set, failures apply only to URIs containing it.
  final String? failsOn;
  final calls = <String>[];
  bool disposed = false;

  @override
  Future<void> open(Uri uri) async {
    calls.add('open $uri');
    final fails = failsOn == null || uri.toString().contains(failsOn!);
    final failNow = failOpen && fails;
    if (gaveUp != null && fails) {
      value = const PlayerSnapshot(status: PlaybackStatus.opening);
      value = PlayerSnapshot(status: gaveUp!);
      return;
    }
    value = PlayerSnapshot(
      status: failNow ? PlaybackStatus.error : PlaybackStatus.playing,
      position: failNow ? Duration.zero : const Duration(milliseconds: 40),
    );
  }

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> seek(Duration position) async => calls.add('seek $position');
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> setVolume(int volume) async => calls.add('volume $volume');
  @override
  Future<List<PlayerAudioTrack>> getAudioTracks() async => const [];
  @override
  Future<void> setAudioTrack(int id) async {}
  @override
  Future<List<PlayerSubtitleTrack>> getSubtitleTracks() async => const [];
  @override
  Future<void> setSubtitleTrack(int id) async {}
  @override
  Future<void> disableSubtitle() async {}
  @override
  Widget buildVideo() => Text(name, textDirection: TextDirection.ltr);
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  const both = EngineRouter(available: {MediaEngine.mpv, MediaEngine.vlc});

  group('EngineRouter', () {
    test('libmpv by default, tracker modules included', () {
      expect(both.engineFor(Uri.file('/m/a.mkv')), MediaEngine.mpv);
      expect(both.engineFor(Uri.file('/m/b.thd')), MediaEngine.mpv);
      expect(both.engineFor(Uri.file('/m/tone.MOD')), MediaEngine.mpv);
      expect(both.engineFor(Uri.file('/m/song.nsf')), MediaEngine.mpv);
      expect(both.engineFor(Uri.parse('http://h/stream')), MediaEngine.mpv);
    });

    test('byExtension overrides the default engine', () {
      const custom = EngineRouter(
        available: {MediaEngine.mpv, MediaEngine.vlc},
        byExtension: {'xm': MediaEngine.vlc},
      );
      expect(custom.engineFor(Uri.file('/m/song.XM')), MediaEngine.vlc);
      expect(
        custom.engineFor(Uri.parse('http://h/x/a.xm?token=1')),
        MediaEngine.vlc,
      );
      expect(custom.engineFor(Uri.file('/m/a.mkv')), MediaEngine.mpv);
    });

    test('libVLC only where libmpv is not built', () {
      const vlcOnly = EngineRouter(available: {MediaEngine.vlc});
      expect(vlcOnly.engineFor(Uri.file('/m/a.mkv')), MediaEngine.vlc);
      expect(vlcOnly.fallbackFor(MediaEngine.vlc), isNull);
      expect(both.fallbackFor(MediaEngine.mpv), MediaEngine.vlc);
      expect(both.fallbackFor(MediaEngine.vlc), MediaEngine.mpv);
    });

    test('extensionOf', () {
      expect(EngineRouter.extensionOf(Uri.file('/a/b.c.MP4')), 'mp4');
      expect(EngineRouter.extensionOf(Uri.file('/a/.hidden')), '');
      expect(EngineRouter.extensionOf(Uri.parse('http://h/')), '');
    });

    test('desktop disc URIs use the native mpv readers', () {
      expect(
        both.engineFor(Uri.parse('bluray:///movies/disc')),
        MediaEngine.mpv,
      );
      expect(both.engineFor(Uri.parse('dvd:///movies/disc')), MediaEngine.mpv);
    });

    test('MpvBackend.resolveStrmContent resolves URLs and relative paths', () {
      expect(
        MpvBackend.resolveStrmContent(
          '# comment\n\nhttps://example.com/movie.mp4\n',
        ),
        Uri.parse('https://example.com/movie.mp4'),
      );
      expect(
        MpvBackend.resolveStrmContent(
          '../common/baseline.mp4\n',
          strmFile: Uri.file('/tmp/ref/test.strm'),
        ),
        Uri.file('/tmp/common/baseline.mp4'),
      );
      expect(MpvBackend.resolveStrmContent('# only comments\n  '), isNull);
    });

    test('MpvBackend.resolveAsxContent resolves <ref href> URLs and relative paths', () {
      expect(
        MpvBackend.resolveAsxContent(
          '<ASX version="3.0"><ENTRY><REF HREF="https://example.com/a.mp4?x=1&amp;y=2"/></ENTRY></ASX>',
        ),
        Uri.parse('https://example.com/a.mp4?x=1&y=2'),
      );
      expect(
        MpvBackend.resolveAsxContent(
          "<asx><entry><ref href='../common/baseline.mp4'/></entry></asx>",
          asxFile: Uri.file('/tmp/ref/test.asx'),
        ),
        Uri.file('/tmp/common/baseline.mp4'),
      );
      expect(MpvBackend.resolveAsxContent('<asx></asx>'), isNull);
    });

    test('MpvBackend.detectIsoScheme identifies DVD, Blu-ray, and data ISOs', () {
      expect(MpvBackend.detectIsoScheme('...BDMV...'.codeUnits), 'bluray');
      expect(
        MpvBackend.detectIsoScheme([0, 0x42, 0, 0x44, 0, 0x4d, 0, 0x56, 0]),
        'bluray',
      );
      expect(MpvBackend.detectIsoScheme('...VIDEO_TS...'.codeUnits), 'dvd');
      expect(MpvBackend.detectIsoScheme('plain data iso'.codeUnits), isNull);
    });

    test('MpvBackend.resolveIfoDirectory strips VIDEO_TS parent', () {
      expect(
        MpvBackend.resolveIfoDirectory('/movies/disc/VIDEO_TS/VIDEO_TS.IFO'),
        '/movies/disc',
      );
      expect(
        MpvBackend.resolveIfoDirectory('/movies/disc/VTS_01_0.IFO'),
        '/movies/disc',
      );
    });

    test('MpvBackend.discoverSplitParts finds consecutive .001/.002 volumes', () {
      final existing = {
        '/tmp/clip.mkv.001',
        '/tmp/clip.mkv.002',
        '/tmp/clip.mkv.003',
      };
      expect(
        MpvBackend.discoverSplitParts(
          '/tmp/clip.mkv.001',
          exists: existing.contains,
        ),
        ['/tmp/clip.mkv.001', '/tmp/clip.mkv.002', '/tmp/clip.mkv.003'],
      );
      expect(
        MpvBackend.discoverSplitParts(
          '/tmp/solo.001',
          exists: (p) => p == '/tmp/solo.001',
        ),
        isEmpty,
      );
    });
  });

  group('RoutedPlayerBackend', () {
    late List<_FakeEngine> created;
    RoutedPlayerBackend routed({
      EngineRouter router = both,
      bool mpvFails = false,
      bool vlcFails = false,
      PlaybackStatus? vlcGivesUp,
      String? failsOn,
    }) {
      created = [];
      return RoutedPlayerBackend(
        router: router,
        createMpv: () {
          final e = _FakeEngine('mpv', failOpen: mpvFails, failsOn: failsOn);
          created.add(e);
          return e;
        },
        createVlc: () {
          final e = _FakeEngine(
            'vlc',
            failOpen: vlcFails,
            gaveUp: vlcGivesUp,
            failsOn: failsOn,
          );
          created.add(e);
          return e;
        },
      );
    }

    test('opens with the routed engine and forwards calls', () async {
      final b = routed();
      await b.open(Uri.file('/m/a.mkv'));
      expect(b.engine, MediaEngine.mpv);
      expect(b.value.status, PlaybackStatus.playing);
      await b.seek(const Duration(seconds: 2));
      await b.setVolume(30);
      expect(created.single.calls, [
        'open file:///m/a.mkv',
        'seek 0:00:02.000000',
        'volume 30',
      ]);
      b.dispose();
      expect(created.single.disposed, isTrue);
    });

    test('switches engines between media and disposes the old one', () async {
      final b = routed(
        router: const EngineRouter(
          available: {MediaEngine.mpv, MediaEngine.vlc},
          byExtension: {'vlconly': MediaEngine.vlc},
        ),
      );
      await b.open(Uri.file('/m/a.mkv'));
      await b.open(Uri.file('/m/b.vlconly'));
      expect(b.engine, MediaEngine.vlc);
      expect(created.map((e) => e.name), ['mpv', 'vlc']);
      expect(created.first.disposed, isTrue);
      await b.open(Uri.file('/m/c.vlconly'));
      expect(created.length, 2, reason: 'same engine is reused');
      b.dispose();
    });

    test('falls back to the other engine when opening fails', () async {
      final b = routed(mpvFails: true);
      await b.open(Uri.file('/m/a.ast'));
      await pumpEventQueue();
      expect(b.engine, MediaEngine.vlc);
      expect(b.fellBack, isTrue);
      expect(b.value.status, PlaybackStatus.playing);
      expect(created.last.calls, ['open file:///m/a.ast']);
      b.dispose();
    });

    test(
      'reports the error when both engines fail (one fallback only)',
      () async {
        final b = routed(mpvFails: true, vlcFails: true);
        await b.open(Uri.file('/m/a.asx'));
        await pumpEventQueue();
        expect(b.value.status, PlaybackStatus.error);
        expect(created.length, 2);
        b.dispose();
      },
    );

    for (final status in [PlaybackStatus.ended, PlaybackStatus.idle]) {
      test(
        'a fallback that gives up without playing ($status) is an error',
        () async {
          final b = routed(
            mpvFails: true,
            vlcGivesUp: status,
            failsOn: 'corrupt',
          );
          await b.open(Uri.file('/m/corrupt.mp4'));
          await pumpEventQueue();
          expect(b.fellBack, isTrue);
          expect(b.value.status, PlaybackStatus.error);
          // The next media starts clean.
          await b.open(Uri.file('/m/ok.mkv'));
          await pumpEventQueue();
          expect(b.value.status, PlaybackStatus.playing);
          b.dispose();
        },
      );
    }

    test('a media that ends before playing falls back too', () async {
      created = [];
      final b = RoutedPlayerBackend(
        router: both,
        createMpv: () {
          final e = _FakeEngine('mpv', gaveUp: PlaybackStatus.ended);
          created.add(e);
          return e;
        },
        createVlc: () {
          final e = _FakeEngine('vlc');
          created.add(e);
          return e;
        },
      );
      await b.open(Uri.file('/m/a.mkv'));
      await pumpEventQueue();
      expect(b.fellBack, isTrue);
      expect(b.engine, MediaEngine.vlc);
      expect(b.value.status, PlaybackStatus.playing);
      b.dispose();
    });

    test('playing at 0 then ending is not a start', () async {
      created = [];
      final b = RoutedPlayerBackend(
        router: both,
        createMpv: () {
          final e = _FakeEngine('mpv', failOpen: true);
          created.add(e);
          return e;
        },
        createVlc: () {
          final e = _FakeEngine('vlc', gaveUp: PlaybackStatus.ended);
          created.add(e);
          return e;
        },
      );
      await b.open(Uri.file('/m/corrupt.mp4'));
      await pumpEventQueue();
      // libVLC: playing at position 0, then ended.
      created.last.value = const PlayerSnapshot(status: PlaybackStatus.playing);
      created.last.value = const PlayerSnapshot(status: PlaybackStatus.ended);
      expect(b.value.status, PlaybackStatus.error);
      b.dispose();
    });

    testWidgets('video view follows the engine', (tester) async {
      final b = routed(
        router: const EngineRouter(
          available: {MediaEngine.mpv, MediaEngine.vlc},
          byExtension: {'vlconly': MediaEngine.vlc},
        ),
      );
      await tester.pumpWidget(PlayerVideoView(backend: b));
      await tester.runAsync(() => b.open(Uri.file('/m/a.mkv')));
      await tester.pump();
      expect(find.text('mpv'), findsOneWidget);
      await tester.runAsync(() => b.open(Uri.file('/m/a.vlconly')));
      await tester.pump();
      expect(find.text('vlc'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      b.dispose();
    });

    test('parses unencrypted Harmonix MOGG header offsets', () {
      final valid = [
        0x0A, 0x00, 0x00, 0x00, // version 0x0A
        0x14, 0x00, 0x00, 0x00, // offset 20
        ...List.filled(12, 0),
        0x4F, 0x67, 0x67, 0x53, // OggS
      ];
      expect(MpvBackend.parseMoggOffset(valid), 20);
      // Encrypted MOGG (version 0x0B) is rejected.
      final encrypted = [0x0B, ...valid.sublist(1)];
      expect(MpvBackend.parseMoggOffset(encrypted), isNull);
    });

    test('builds Dialogic OKI ADPCM WAV header for raw .vox files', () {
      final hdr = MpvBackend.buildVoxWavHeader(17597);
      expect(hdr.length, 44);
      expect(String.fromCharCodes(hdr.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(hdr.sublist(8, 12)), 'WAVE');
      expect(hdr[20] | (hdr[21] << 8), 0x0017);
      expect(hdr[22] | (hdr[23] << 8), 1);
      final rate = hdr[24] | (hdr[25] << 8) | (hdr[26] << 16) | (hdr[27] << 24);
      expect(rate, 8000);
    });
  });
}
