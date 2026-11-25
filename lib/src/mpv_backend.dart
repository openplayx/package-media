import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

import 'tvos.dart';

import 'package:media_kit_video/media_kit_video.dart';
import 'package:openplayx_playback/playback.dart';

/// libmpv engine (through media_kit) behind the app's [PlayerBackend]
/// contract. libmpv is package-media's own build, linked to package-ffmpeg's
/// FFmpeg, so it plays what libVLC's bundled FFmpeg cannot (TrueHD, AST, ...).
class MpvBackend extends PlayerBackend {
  /// [mpvOptions] are mpv properties applied before the first media, e.g.
  /// `{'ao': 'null'}` in tests.
  MpvBackend({Map<String, String> mpvOptions = const {}}) {
    _ensureInitialized();
    _player = Player(
      configuration: const PlayerConfiguration(
        // Errors and progress come from the streams below.
        logLevel: MPVLogLevel.warn,
      ),
    );
    _video = VideoController(_player);
    _ready = () async {
      for (final entry in mpvOptions.entries) {
        await _native.setProperty(entry.key, entry.value);
      }
    }();
    _subscriptions.addAll([
      _player.stream.playing.listen((_) => _sync()),
      _player.stream.completed.listen((done) {
        if (done) _ended = true;
        _sync();
      }),
      _player.stream.position.listen((_) => _sync()),
      _player.stream.duration.listen((_) => _sync()),
      _player.stream.width.listen((_) => _sync()),
      _player.stream.height.listen((_) => _sync()),
      _player.stream.buffering.listen((_) => _sync()),
      _player.stream.rate.listen((_) => _sync()),
      _player.stream.volume.listen((_) => _sync()),
      _player.stream.error.listen((_) {
        _error = true;
        _sync();
      }),
    ]);
  }

  static bool _initialized = false;
  static void _ensureInitialized() {
    if (_initialized) return;
    MediaKit.ensureInitialized();
    _initialized = true;
  }

  /// Platforms with a package-media libmpv build. On Windows, only when
  /// libmpv-2.dll was bundled: without a libmpv build the app gets
  /// media_kit_video's stub (libs/media_kit_libs_windows_video).
  static bool get isSupported =>
      !kIsWeb &&
      (isTvOS ||
          [
            TargetPlatform.macOS,
            TargetPlatform.iOS,
            TargetPlatform.android,
            TargetPlatform.linux,
          ].contains(defaultTargetPlatform) ||
          (defaultTargetPlatform == TargetPlatform.windows &&
              _windowsLibmpvBundled));

  static final bool _windowsLibmpvBundled = File(
    '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}libmpv-2.dll',
  ).existsSync();

  late final Player _player;
  late final VideoController _video;
  late final Future<void> _ready;
  final _subscriptions = <StreamSubscription<Object?>>[];
  NativePlayer get _native => _player.platform as NativePlayer;
  bool _opened = false;
  bool _ended = false;
  bool _error = false;
  bool _seekable = false;
  bool _disposed = false;

  void _sync() {
    if (_disposed) return;
    final s = _player.state;
    final status = _error
        ? PlaybackStatus.error
        : _ended
        ? PlaybackStatus.ended
        : !_opened
        ? PlaybackStatus.idle
        : s.playing
        ? (s.duration == Duration.zero && s.position == Duration.zero
              ? PlaybackStatus.opening
              : PlaybackStatus.playing)
        : PlaybackStatus.paused;
    value = PlayerSnapshot(
      status: status,
      position: s.position,
      duration: s.duration,
      canSeek: _seekable,
      videoSize: s.width != null && s.height != null && s.width! > 0
          ? Size(s.width!.toDouble(), s.height!.toDouble())
          : null,
      isBuffering: s.buffering,
      speed: s.rate,
      volume: s.volume.round(),
    );
    if (_opened && !_seekable) unawaited(_refreshSeekable());
  }

  Future<void> _refreshSeekable() async {
    try {
      final seekable = await _native.getProperty('seekable') == 'yes';
      if (seekable != _seekable && !_disposed) {
        _seekable = seekable;
        _sync();
      }
    } catch (_) {}
  }

  @override
  Future<void> open(Uri uri) async {
    await _ready;
    _opened = true;
    _ended = false;
    _error = false;
    _seekable = false;
    await _player.open(Media(uri.toString()));
    _sync();
  }

  @override
  Future<void> play() async {
    if (_ended) {
      _ended = false;
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() async {
    await _player.stop();
    _opened = false;
    _ended = false;
    value = const PlayerSnapshot();
  }

  @override
  Future<void> seek(Duration position) async {
    _ended = false;
    await _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setRate(speed);
  @override
  Future<void> setVolume(int volume) =>
      _player.setVolume(volume.clamp(0, 100).toDouble());

  int? _id(String id) => int.tryParse(id);

  @override
  Future<List<PlayerAudioTrack>> getAudioTracks() async => [
    for (final t in _player.state.tracks.audio)
      if (_id(t.id) != null)
        PlayerAudioTrack(
          id: _id(t.id)!,
          name: t.title ?? t.codec ?? 'Track ${t.id}',
          language: t.language,
        ),
  ];
  @override
  Future<void> setAudioTrack(int id) => _player.setAudioTrack(
    _player.state.tracks.audio.firstWhere((t) => t.id == '$id'),
  );
  @override
  Future<List<PlayerSubtitleTrack>> getSubtitleTracks() async => [
    for (final t in _player.state.tracks.subtitle)
      if (_id(t.id) != null)
        PlayerSubtitleTrack(
          id: _id(t.id)!,
          name: t.title ?? t.codec ?? 'Track ${t.id}',
          language: t.language,
        ),
  ];
  @override
  Future<void> setSubtitleTrack(int id) => _player.setSubtitleTrack(
    _player.state.tracks.subtitle.firstWhere((t) => t.id == '$id'),
  );
  @override
  Future<void> disableSubtitle() =>
      _player.setSubtitleTrack(SubtitleTrack.no());

  @override
  bool get supportsExternalSubtitles => true;
  @override
  Future<void> addExternalSubtitle(Uri file) =>
      _player.setSubtitleTrack(SubtitleTrack.uri(file.toString()));

  @override
  bool get supportsDelays => true;
  @override
  bool get supportsSnapshot => true;
  @override
  bool get supportsMediaInfo => true;
  @override
  Future<void> setAudioDelay(Duration delay) => _native.setProperty(
    'audio-delay',
    (delay.inMicroseconds / 1e6).toString(),
  );
  @override
  Future<void> setSubtitleDelay(Duration delay) =>
      _native.setProperty('sub-delay', (delay.inMicroseconds / 1e6).toString());

  @override
  Future<Uint8List> takeSnapshot() async {
    final png = await _player.screenshot(format: 'image/png');
    if (png == null) throw StateError('No video frame to snapshot');
    return png;
  }

  @override
  Future<PlayerMediaInfo> getMediaInfo() async {
    final list = jsonDecode(await _native.getProperty('track-list')) as List;
    return PlayerMediaInfo(
      title: await _native.getProperty('media-title'),
      tracks: [
        for (final t in list.cast<Map<String, dynamic>>())
          PlayerTrackInfo(
            type: switch (t['type']) {
              'video' => 'video',
              'audio' => 'audio',
              'sub' => 'subtitle',
              _ => 'unknown',
            },
            codec: t['codec'] as String?,
            language: t['lang'] as String?,
            bitrate: (t['demux-bitrate'] as num?)?.toInt(),
            width: (t['demux-w'] as num?)?.toInt(),
            height: (t['demux-h'] as num?)?.toInt(),
            channels: (t['demux-channel-count'] as num?)?.toInt(),
            sampleRate: (t['demux-samplerate'] as num?)?.toInt(),
          ),
      ],
    );
  }

  /// mpv has no libVLC-style decoder counters. Pictures: frames presented
  /// (estimated frame number) and dropped by decoder or output; audio buffer
  /// counters stay 0 (audio is checked with [audioLevels] instead).
  @override
  Future<PlayerStats?> getStats() async {
    Future<int> prop(String name) async =>
        int.tryParse(await _native.getProperty(name)) ?? 0;
    var frame = await prop('estimated-frame-number');
    if (frame == 0) {
      // Containers without a frame rate (Ogg): time × filter-chain fps.
      final time = double.tryParse(await _native.getProperty('time-pos')) ?? 0;
      final fps =
          double.tryParse(await _native.getProperty('estimated-vf-fps')) ?? 0;
      frame = (time * fps).round();
    }
    final dropped =
        await prop('frame-drop-count') + await prop('decoder-frame-drop-count');
    return PlayerStats(
      decodedVideo: frame + dropped,
      displayedPictures: frame,
      lostPictures: dropped,
    );
  }

  /// mpv property access for diagnostics and tests.
  Future<String> getProperty(String name) => _native.getProperty(name);
  Future<void> setProperty(String name, String value) =>
      _native.setProperty(name, value);

  @override
  Widget buildVideo() => Video(
    controller: _video,
    controls: NoVideoControls,
    fill: const Color(0xFF000000),
  );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}
