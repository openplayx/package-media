import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx_media/openplayx_media.dart';

/// Engine stand-in: records calls; [failOpen] reports an error on open.
class _FakeEngine extends PlayerBackend {
  _FakeEngine(this.name, {this.failOpen = false});
  final String name;
  final bool failOpen;
  final calls = <String>[];
  bool disposed = false;

  @override
  Future<void> open(Uri uri) async {
    calls.add('open $uri');
    value = PlayerSnapshot(
      status: failOpen ? PlaybackStatus.error : PlaybackStatus.playing,
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
    test('libmpv by default, libVLC for tracker modules', () {
      expect(both.engineFor(Uri.file('/m/a.mkv')), MediaEngine.mpv);
      expect(both.engineFor(Uri.file('/m/b.thd')), MediaEngine.mpv);
      expect(both.engineFor(Uri.file('/m/tone.MOD')), MediaEngine.vlc);
      expect(both.engineFor(Uri.file('/m/song.xm')), MediaEngine.vlc);
      expect(
        both.engineFor(Uri.parse('http://h/x/a.it?token=1')),
        MediaEngine.vlc,
      );
      expect(both.engineFor(Uri.parse('http://h/stream')), MediaEngine.mpv);
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
  });

  group('RoutedPlayerBackend', () {
    late List<_FakeEngine> created;
    RoutedPlayerBackend routed({bool mpvFails = false, bool vlcFails = false}) {
      created = [];
      return RoutedPlayerBackend(
        router: both,
        createMpv: () {
          final e = _FakeEngine('mpv', failOpen: mpvFails);
          created.add(e);
          return e;
        },
        createVlc: () {
          final e = _FakeEngine('vlc', failOpen: vlcFails);
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
      final b = routed();
      await b.open(Uri.file('/m/a.mkv'));
      await b.open(Uri.file('/m/b.mod'));
      expect(b.engine, MediaEngine.vlc);
      expect(created.map((e) => e.name), ['mpv', 'vlc']);
      expect(created.first.disposed, isTrue);
      await b.open(Uri.file('/m/c.mod'));
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

    testWidgets('video view follows the engine', (tester) async {
      final b = routed();
      await tester.pumpWidget(PlayerVideoView(backend: b));
      await tester.runAsync(() => b.open(Uri.file('/m/a.mkv')));
      await tester.pump();
      expect(find.text('mpv'), findsOneWidget);
      await tester.runAsync(() => b.open(Uri.file('/m/a.mod')));
      await tester.pump();
      expect(find.text('vlc'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      b.dispose();
    });
  });
}
