import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openplayx_playback/playback.dart';

import 'mpv_backend.dart';

/// A playback engine behind [PlayerBackend].
enum MediaEngine { mpv, vlc }

/// Picks the engine for a media URI.
///
/// libmpv (package-media's build on package-ffmpeg's FFmpeg 9.1) is the
/// default: in the format tests it plays everything libVLC plays, plus
/// TrueHD, AST, FLAC in Ogg, playlists and raw MPEG-2 video, and with
/// package-ffmpeg's libopenmpt and libgme also tracker modules (more formats
/// than VLCKit's libmodplug) and game console music. Desktop disc navigation
/// also uses libmpv. libVLC takes [byExtension] overrides, every platform without a libmpv
/// build, and media libmpv fails to open ([fallbackFor]).
@immutable
class EngineRouter {
  const EngineRouter({
    this.defaultEngine = MediaEngine.mpv,
    this.byExtension = vlcExtensions,
    this.available,
  });

  /// Extensions routed to libVLC. Musepack SV7 (`.mpc`/`.mpp`/`.mp+`)
  /// overshoots to EOF on seek in FFmpeg's mpc demuxer, while libVLC seeks
  /// cleanly (ALL-267/268/269).
  static const vlcExtensions = <String, MediaEngine>{
    'mpc': MediaEngine.vlc,
    'mpp': MediaEngine.vlc,
    'mp+': MediaEngine.vlc,
  };

  final MediaEngine defaultEngine;

  /// Lower-case extension (without the dot) to engine.
  final Map<String, MediaEngine> byExtension;

  /// Engines usable on this platform; defaults to libVLC everywhere and
  /// libmpv where package-media builds it ([MpvBackend.isSupported]).
  final Set<MediaEngine>? available;

  Set<MediaEngine> get engines =>
      available ??
      {MediaEngine.vlc, if (MpvBackend.isSupported) MediaEngine.mpv};

  /// The extension of the URI's last path segment, lower case, or ''.
  static String extensionOf(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty);
    if (segments.isEmpty) return '';
    final name = segments.last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  MediaEngine engineFor(Uri uri) {
    final usable = engines;
    final wanted = byExtension[extensionOf(uri)] ?? defaultEngine;
    if (usable.contains(wanted)) return wanted;
    return usable.contains(MediaEngine.vlc) ? MediaEngine.vlc : usable.first;
  }

  /// The engine to try when [engine] cannot open a media, if any.
  MediaEngine? fallbackFor(MediaEngine engine) {
    final other = engine == MediaEngine.mpv ? MediaEngine.vlc : MediaEngine.mpv;
    return engines.contains(other) ? other : null;
  }
}

/// [PlayerBackend] that routes each media to an engine ([EngineRouter]) and
/// forwards everything to that engine's backend. When the chosen engine
/// fails before playback starts, the media is opened once with the other
/// engine.
class RoutedPlayerBackend extends PlayerBackend {
  RoutedPlayerBackend({
    this.router = const EngineRouter(),
    PlayerBackend Function()? createMpv,
    PlayerBackend Function()? createVlc,
    this.fallback = true,
  }) : _createMpv = createMpv ?? MpvBackend.new,
       _createVlc = createVlc ?? LibVlcBackend.new;

  final EngineRouter router;
  final bool fallback;
  final PlayerBackend Function() _createMpv;
  final PlayerBackend Function() _createVlc;

  PlayerBackend? _inner;
  MediaEngine? _engine;
  Uri? _uri;
  bool _started = false;
  bool _fellBack = false;
  bool _fallbackOpened = false;
  bool _failed = false;
  bool _disposed = false;
  final _current = ValueNotifier<PlayerBackend?>(null);

  /// The engine playing the current media (null before [open]).
  MediaEngine? get engine => _engine;

  /// Whether the current media is played by the fallback engine.
  bool get fellBack => _fellBack;

  /// The engine backend playing the current media.
  PlayerBackend? get inner => _inner;

  /// Calls [listener] whenever the engine backend changes.
  ValueListenable<PlayerBackend?> get currentBackend => _current;

  Future<void> _switchTo(MediaEngine engine) async {
    if (_engine == engine && _inner != null) return;
    final old = _inner;
    old?.removeListener(_forward);
    _inner = engine == MediaEngine.mpv ? _createMpv() : _createVlc();
    _engine = engine;
    _inner!.addListener(_forward);
    _current.value = _inner;
    old?.dispose();
  }

  void _forward() {
    final inner = _inner;
    if (_disposed || inner == null) return;
    var snapshot = inner.value;
    // Started once the position moves: libVLC reports a corrupt file as
    // playing at 0 before it ends.
    if (snapshot.status == PlaybackStatus.playing &&
        snapshot.position > Duration.zero) {
      _started = true;
    }
    // A media that ends before it ever played failed to open (mpv reports a
    // corrupt file as ended before its load error): treat it as an error.
    final failedToStart =
        !_started &&
        (snapshot.status == PlaybackStatus.error ||
            (snapshot.status == PlaybackStatus.ended && !_fellBack));
    if (failedToStart && fallback && !_fellBack) {
      final other = router.fallbackFor(_engine!);
      final uri = _uri;
      // VLCKit on iOS intermittently hangs when probing raw optical disc
      // images (.iso/.img/.nrg/.bin); fail fast instead of stalling.
      final skipVlcDiscFallback =
          other == MediaEngine.vlc &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          uri != null &&
          MpvBackend.discImageExtensions.contains(EngineRouter.extensionOf(uri));
      if (other != null && uri != null && !skipVlcDiscFallback) {
        _fellBack = true;
        // Not while the failed engine is notifying: switching disposes it.
        scheduleMicrotask(() async {
          if (_disposed || _uri != uri) return;
          await _switchTo(other);
          await _inner!.open(uri);
        });
        return; // keep reporting "opening" while the other engine starts
      }
    }
    if (_fellBack && !_started) {
      // The first engine reported an error. A fallback engine that gives up
      // without playing (libVLC reports a corrupt file as ended, an HTTP
      // error as idle again) failed too: the media is an error.
      if (snapshot.status != PlaybackStatus.idle) _fallbackOpened = true;
      if (snapshot.status == PlaybackStatus.ended ||
          (snapshot.status == PlaybackStatus.idle && _fallbackOpened)) {
        _failed = true;
      }
    }
    if (_failed) snapshot = _asError(snapshot);
    value = snapshot;
  }

  static PlayerSnapshot _asError(PlayerSnapshot s) => PlayerSnapshot(
    status: PlaybackStatus.error,
    position: s.position,
    duration: s.duration,
    canSeek: s.canSeek,
    videoSize: s.videoSize,
    isBuffering: false,
    speed: s.speed,
    volume: s.volume,
    readSpeedMBps: s.readSpeedMBps,
  );

  PlayerBackend get _active {
    final inner = _inner;
    if (inner == null) throw StateError('no media opened');
    return inner;
  }

  @override
  bool get supportsPictureInPictureOutput =>
      _inner?.supportsPictureInPictureOutput ?? false;
  @override
  Future<int?> pictureInPictureHandle() async =>
      _inner?.pictureInPictureHandle();

  @override
  Future<void> open(Uri uri) async {
    _uri = uri;
    _started = false;
    _fellBack = false;
    _fallbackOpened = false;
    _failed = false;
    await _switchTo(router.engineFor(uri));
    await _inner!.open(uri);
  }

  @override
  Future<void> play() => _active.play();
  @override
  Future<void> pause() => _active.pause();
  @override
  Future<void> stop() => _inner?.stop() ?? Future.value();
  @override
  Future<void> seek(Duration position) => _active.seek(position);
  @override
  Future<void> setSpeed(double speed) => _active.setSpeed(speed);
  @override
  Future<void> setVolume(int volume) => _active.setVolume(volume);
  @override
  Future<List<PlayerAudioTrack>> getAudioTracks() => _active.getAudioTracks();
  @override
  Future<void> setAudioTrack(int id) => _active.setAudioTrack(id);
  @override
  Future<List<PlayerSubtitleTrack>> getSubtitleTracks() =>
      _active.getSubtitleTracks();
  @override
  Future<void> setSubtitleTrack(int id) => _active.setSubtitleTrack(id);
  @override
  Future<void> disableSubtitle() => _active.disableSubtitle();
  @override
  bool get supportsExternalSubtitles =>
      _inner?.supportsExternalSubtitles ?? false;
  @override
  Future<void> addExternalSubtitle(Uri file) =>
      _active.addExternalSubtitle(file);
  @override
  bool get supportsDelays => _inner?.supportsDelays ?? false;
  @override
  bool get supportsSnapshot => _inner?.supportsSnapshot ?? false;
  @override
  bool get supportsMediaInfo => _inner?.supportsMediaInfo ?? false;
  @override
  Future<void> setAudioDelay(Duration delay) => _active.setAudioDelay(delay);
  @override
  Future<void> setSubtitleDelay(Duration delay) =>
      _active.setSubtitleDelay(delay);
  @override
  Future<Uint8List> takeSnapshot() => _active.takeSnapshot();
  @override
  Future<PlayerMediaInfo> getMediaInfo() => _active.getMediaInfo();
  @override
  Future<PlayerStats?> getStats() =>
      _inner?.getStats() ?? Future<PlayerStats?>.value();

  @override
  Widget buildVideo() => ValueListenableBuilder<PlayerBackend?>(
    valueListenable: _current,
    builder: (context, inner, _) => inner == null
        ? const SizedBox.shrink()
        // A new key per engine backend: its video widget state is its own.
        : KeyedSubtree(key: ObjectKey(inner), child: inner.buildVideo()),
  );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _inner?.removeListener(_forward);
    _inner?.dispose();
    _current.dispose();
    super.dispose();
  }
}
