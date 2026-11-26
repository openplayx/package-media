import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show
        ContentType,
        Directory,
        File,
        HttpHeaders,
        HttpServer,
        HttpStatus,
        InternetAddress,
        Platform;

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
      _player.stream.error.listen((message) {
        // Decoder log errors can recover (e.g. AC3 after a DVD cell seek).
        // Our media_kit fork reports fatal MPV_EVENT_END_FILE errors with
        // this prefix; only those make the playback session fail.
        if (!message.startsWith('end-file:')) return;
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
  _SplitVolumeServer? _splitServer;

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

  /// Game console music played by FFmpeg's libgme demuxer (package-ffmpeg).
  /// Its probe scores files under 16 KB at 25, below mpv's minimum of 26
  /// (`demuxer-lavf-probescore`), and most such files are that small: the
  /// demuxer is named for these extensions instead. VGZ needs zlib, which
  /// package-ffmpeg's libgme is built without.
  static const gmeExtensions = {
    'nsf', 'nsfe', 'gym', 'spc', 'vgm', 'gbs', 'hes', 'kss', 'sap', 'ay', //
  };

  /// Formats whose FFmpeg probe score sits at or below mpv's minimum of 26
  /// (`demuxer-lavf-probescore`), requiring an explicit `demuxer-lavf-format`.
  static const lavfFormatByExtension = {'adp': 'adp', 'dtk': 'adp'};

  /// Formats whose FFmpeg demuxer lacks a seek table and overshoots to EOF on
  /// fast/inaccurate seeks; exact (`hr-seek=yes`) seeking decodes to the target.
  static const hrSeekExtensions = {'mpc', 'mpp', 'mp+'};

  /// Optical disc image extensions that may wrap a DVD-Video (`VIDEO_TS`) or
  /// Blu-ray (`BDMV`) filesystem and should be probed for `dvd://`/`bluray://`.
  static const discImageExtensions = {'iso', 'img', 'nrg', 'bin'};

  /// Resolves a `.strm` pointer file's first non-empty, non-comment line to a
  /// target URI (supports absolute URIs and paths relative to [strmFile]).
  static Uri? resolveStrmContent(String content, {Uri? strmFile}) {
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parsed = Uri.tryParse(line);
      if (parsed != null && parsed.hasScheme && parsed.scheme.length > 1) {
        return parsed;
      }
      if (strmFile != null && strmFile.isScheme('file')) {
        return strmFile.resolveUri(Uri.file(line));
      }
      return Uri.file(line);
    }
    return null;
  }

  /// Resolves an `.asx` XML playlist's first `<ref href="..."/>` entry to a
  /// target URI (supports absolute URIs and paths relative to [asxFile]).
  static Uri? resolveAsxContent(String content, {Uri? asxFile}) {
    final match = RegExp(
      r'''<ref\b[^>]*\bhref\s*=\s*(?:"([^"]+)"|'([^']+)')''',
      caseSensitive: false,
    ).firstMatch(content);
    final href = (match?.group(1) ?? match?.group(2))?.trim();
    if (href == null || href.isEmpty) return null;
    final decoded = href
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
    final parsed = Uri.tryParse(decoded);
    if (parsed != null && parsed.hasScheme && parsed.scheme.length > 1) {
      return parsed;
    }
    if (asxFile != null && asxFile.isScheme('file')) {
      return asxFile.resolveUri(Uri.file(decoded));
    }
    return Uri.file(decoded);
  }

  /// Detects whether an `.iso` image header belongs to a Blu-ray (`bluray`) or
  /// DVD-Video (`dvd`) disc by scanning for BDMV / VIDEO_TS directory or header
  /// markers (ASCII and UTF-16LE/BE). Returns null for non-video data ISOs.
  static String? detectIsoScheme(List<int> header) {
    bool containsAscii(String needle) {
      final bytes = needle.codeUnits;
      if (bytes.isEmpty || header.length < bytes.length) return false;
      outer:
      for (var i = 0; i <= header.length - bytes.length; i++) {
        for (var j = 0; j < bytes.length; j++) {
          if (header[i + j] != bytes[j]) continue outer;
        }
        return true;
      }
      return false;
    }

    bool containsUtf16(String needle) {
      // Matches both UTF-16LE (X 0) and UTF-16BE (0 X) for ASCII characters.
      final units = needle.codeUnits;
      final span = units.length * 2;
      if (units.isEmpty || header.length < span) return false;
      for (final offset in [0, 1]) {
        outer:
        for (var i = 0; i <= header.length - span; i++) {
          for (var j = 0; j < units.length; j++) {
            if (header[i + j * 2 + offset] != units[j] ||
                header[i + j * 2 + (1 - offset)] != 0) {
              continue outer;
            }
          }
          return true;
        }
      }
      return false;
    }

    if (containsAscii('BDMV') ||
        containsUtf16('BDMV') ||
        containsAscii('INDX0200') ||
        containsAscii('INDX0100')) {
      return 'bluray';
    }
    if (containsAscii('VIDEO_TS') ||
        containsUtf16('VIDEO_TS') ||
        containsAscii('DVDVIDEO-VMG')) {
      return 'dvd';
    }
    return null;
  }

  static Future<String?> _detectLocalIsoScheme(Uri uri) async {
    try {
      final file = File.fromUri(uri);
      final raf = await file.open();
      try {
        final len = await raf.length();
        // UDF/ISO-9660 descriptors and root directory entries sit in the first
        // ~2 MB of a disc image.
        final bytes = await raf.read(
          len < 2 * 1024 * 1024 ? len : 2 * 1024 * 1024,
        );
        return detectIsoScheme(bytes);
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Resolves a DVD-Video `.ifo` file path (e.g. `.../disc/VIDEO_TS/VIDEO_TS.IFO`)
  /// to the root directory expected by `libdvdread` (`.../disc`).
  static String resolveIfoDirectory(String ifoPath) {
    final parent = File(ifoPath).parent;
    final segments = parent.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isNotEmpty && segments.last.toLowerCase() == 'video_ts') {
      return Directory(parent.parent.path).path;
    }
    return parent.path;
  }

  /// Parses an unencrypted Harmonix `.mogg` header (version `0x0A` followed by
  /// the little-endian byte offset of the embedded `OggS` stream). Returns null
  /// for encrypted or non-MOGG headers.
  static int? parseMoggOffset(List<int> header) {
    if (header.length < 12) return null;
    int u32(int i) =>
        header[i] |
        (header[i + 1] << 8) |
        (header[i + 2] << 16) |
        (header[i + 3] << 24);
    final version = u32(0);
    final offset = u32(4);
    if (version != 0x0A || offset < 8) return null;
    if (header.length >= offset + 4) {
      if (header[offset] != 0x4F ||
          header[offset + 1] != 0x67 ||
          header[offset + 2] != 0x67 ||
          header[offset + 3] != 0x53) {
        return null;
      }
    }
    return offset;
  }

  /// Builds a 44-byte RIFF/WAVE header wrapping headerless Dialogic OKI ADPCM
  /// (`.vox`) audio (format tag `0x0017`, default 8 kHz mono 4-bit) so FFmpeg's
  /// `adpcm_ima_oki` decoder can open and seek it cleanly.
  static Uint8List buildVoxWavHeader(
    int rawBytes, {
    int sampleRate = 8000,
    int channels = 1,
  }) {
    final data = ByteData(44);
    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    final byteRate = (sampleRate * channels) ~/ 2;
    writeAscii(0, 'RIFF');
    data.setUint32(4, 36 + rawBytes, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 0x0017, Endian.little); // Dialogic OKI ADPCM
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, byteRate, Endian.little);
    data.setUint16(32, 1, Endian.little);
    data.setUint16(34, 4, Endian.little);
    writeAscii(36, 'data');
    data.setUint32(40, rawBytes, Endian.little);
    return data.buffer.asUint8List();
  }

  static Future<int?> _detectLocalMoggOffset(Uri uri) async {
    try {
      final raf = await File.fromUri(uri).open();
      try {
        final len = await raf.length();
        final bytes = await raf.read(len < 4096 ? len : 4096);
        final offset = parseMoggOffset(bytes);
        if (offset == null || offset >= len) return null;
        if (bytes.length < offset + 4) {
          await raf.setPosition(offset);
          final magic = await raf.read(4);
          if (magic.length < 4 ||
              magic[0] != 0x4F ||
              magic[1] != 0x67 ||
              magic[2] != 0x67 ||
              magic[3] != 0x53) {
            return null;
          }
        }
        return offset;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Discovers consecutive split volume parts (`.001`, `.002`, ...) alongside
  /// [firstPartPath]. Returns an empty list if fewer than 2 parts exist.
  static List<String> discoverSplitParts(
    String firstPartPath, {
    bool Function(String path)? exists,
  }) {
    if (!firstPartPath.toLowerCase().endsWith('.001')) return const [];
    final check = exists ?? (p) => File(p).existsSync();
    if (!check(firstPartPath)) return const [];
    final prefix = firstPartPath.substring(0, firstPartPath.length - 4);
    final parts = <String>[firstPartPath];
    for (var i = 2; i <= 999; i++) {
      final next = '$prefix.${i.toString().padLeft(3, '0')}';
      if (!check(next)) break;
      parts.add(next);
    }
    return parts.length >= 2 ? parts : const [];
  }

  @override
  Future<void> open(Uri uri) async {
    await _ready;
    _opened = true;
    _ended = false;
    _error = false;
    _seekable = false;
    var target = uri;
    final rawName =
        uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';
    final rawDot = rawName.lastIndexOf('.');
    final rawExt = rawDot <= 0
        ? ''
        : rawName.substring(rawDot + 1).toLowerCase();
    if ((rawExt == 'strm' || rawExt == 'asx') && uri.isScheme('file')) {
      try {
        final content = await File.fromUri(uri).readAsString();
        final resolved = rawExt == 'strm'
            ? resolveStrmContent(content, strmFile: uri)
            : resolveAsxContent(content, asxFile: uri);
        if (resolved != null) target = resolved;
      } catch (_) {}
    }
    final name =
        target.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';
    final dot = name.lastIndexOf('.');
    final ext = dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
    await _splitServer?.close();
    _splitServer = null;
    final lavfFormat = gmeExtensions.contains(ext)
        ? 'libgme'
        : (lavfFormatByExtension[ext] ?? '');
    await _native.setProperty('demuxer-lavf-format', lavfFormat);
    await _native.setProperty(
      'hr-seek',
      hrSeekExtensions.contains(ext) ? 'yes' : 'default',
    );
    // Disc stream readers expect a local device/image path, not URL-escaped text.
    String location;
    if ({'bluray', 'dvd'}.contains(target.scheme)) {
      location =
          '${target.scheme}://longest/${target.replace(scheme: 'file').toFilePath()}';
    } else if (ext == 'ifo' && target.isScheme('file')) {
      location = 'dvd://longest/${resolveIfoDirectory(target.toFilePath())}';
    } else if (discImageExtensions.contains(ext) && target.isScheme('file')) {
      final discScheme = await _detectLocalIsoScheme(target);
      location = discScheme != null
          ? '$discScheme://longest/${target.toFilePath()}'
          : target.toString();
    } else if (ext == '001' && target.isScheme('file')) {
      final parts = discoverSplitParts(target.toFilePath());
      if (parts.isNotEmpty) {
        _splitServer = await _SplitVolumeServer.start(parts);
        location = _splitServer!.url.toString();
      } else {
        location = target.toString();
      }
    } else if (ext == 'mogg' && target.isScheme('file')) {
      final offset = await _detectLocalMoggOffset(target);
      if (offset != null) {
        _splitServer = await _SplitVolumeServer.startSlice(
          target.toFilePath(),
          startOffset: offset,
          suffix: '.ogg',
        );
        location = _splitServer!.url.toString();
      } else {
        location = target.toString();
      }
    } else if (ext == 'vox' && target.isScheme('file')) {
      final file = File.fromUri(target);
      if (await file.exists()) {
        final len = await file.length();
        _splitServer = await _SplitVolumeServer.startPrefixed(
          file.path,
          prefix: buildVoxWavHeader(len),
          suffix: '.wav',
        );
        location = _splitServer!.url.toString();
      } else {
        location = target.toString();
      }
    } else {
      location = target.toString();
    }
    await _player.open(Media(location));
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
  bool get supportsPictureInPictureOutput => !isTvOS;
  @override
  Future<int?> pictureInPictureHandle() => _player.handle;

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
    unawaited(_splitServer?.close());
    _splitServer = null;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}

/// Ephemeral loopback HTTP range server that serves virtual byte streams
/// (split `.001/.002/...` volumes, `.mogg` Ogg slices, or `.vox` with a WAV
/// header) without copying media files to disk.
class _SplitVolumeServer {
  _SplitVolumeServer._(
    this._server,
    this._parts,
    this._partOffsets,
    this._lengths,
    this._prefix,
    this._total,
    this.url,
  );

  final HttpServer _server;
  final List<File> _parts;
  final List<int> _partOffsets;
  final List<int> _lengths;
  final Uint8List _prefix;
  final int _total;
  final Uri url;

  static Future<_SplitVolumeServer> start(List<String> paths) async {
    final files = paths.map(File.new).toList(growable: false);
    final offsets = List<int>.filled(files.length, 0);
    final lengths = <int>[];
    var total = 0;
    for (final f in files) {
      final len = await f.length();
      lengths.add(len);
      total += len;
    }
    // Preserve inner extension when present (e.g. movie.mkv.001 -> /stream.mkv).
    final firstName = files.first.uri.pathSegments.last;
    final stem = firstName.substring(0, firstName.length - 4);
    final innerDot = stem.lastIndexOf('.');
    final suffix = innerDot > 0 ? stem.substring(innerDot) : '';
    return _bind(files, offsets, lengths, Uint8List(0), total, suffix);
  }

  static Future<_SplitVolumeServer> startSlice(
    String path, {
    required int startOffset,
    required String suffix,
  }) async {
    final file = File(path);
    final len = await file.length();
    final sliceLen = (len - startOffset).clamp(0, len);
    return _bind(
      [file],
      [startOffset],
      [sliceLen],
      Uint8List(0),
      sliceLen,
      suffix,
    );
  }

  static Future<_SplitVolumeServer> startPrefixed(
    String path, {
    required Uint8List prefix,
    required String suffix,
  }) async {
    final file = File(path);
    final len = await file.length();
    return _bind([file], [0], [len], prefix, prefix.length + len, suffix);
  }

  static Future<_SplitVolumeServer> _bind(
    List<File> files,
    List<int> partOffsets,
    List<int> lengths,
    Uint8List prefix,
    int total,
    String suffix,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final url = Uri.parse('http://127.0.0.1:${server.port}/stream$suffix');
    final instance = _SplitVolumeServer._(
      server,
      files,
      partOffsets,
      lengths,
      prefix,
      total,
      url,
    );
    unawaited(instance._serve());
    return instance;
  }

  Future<void> _serve() async {
    await for (final req in _server) {
      final res = req.response;
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      res.headers.contentType = ContentType.binary;
      var start = 0;
      var end = _total - 1;
      final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final spec = rangeHeader.substring(6).split(',').first.trim();
        final dash = spec.indexOf('-');
        if (dash >= 0) {
          final a = spec.substring(0, dash).trim();
          final b = spec.substring(dash + 1).trim();
          if (a.isNotEmpty) start = int.tryParse(a) ?? 0;
          if (b.isNotEmpty) end = int.tryParse(b) ?? (_total - 1);
          if (a.isEmpty && b.isNotEmpty) {
            final suffixLen = int.tryParse(b) ?? 0;
            start = (_total - suffixLen).clamp(0, _total - 1);
            end = _total - 1;
          }
        }
        if (start >= _total || start > end) {
          res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$_total');
          await res.close();
          continue;
        }
        end = end.clamp(start, _total - 1);
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$_total',
        );
      } else {
        res.statusCode = HttpStatus.ok;
      }
      final count = end - start + 1;
      res.headers.contentLength = count;
      if (req.method == 'HEAD') {
        await res.close();
        continue;
      }
      try {
        var remaining = count;
        var pos = start;
        var offset = 0;
        if (_prefix.isNotEmpty) {
          if (pos < _prefix.length) {
            final take = (_prefix.length - pos) < remaining
                ? (_prefix.length - pos)
                : remaining;
            res.add(_prefix.sublist(pos, pos + take));
            pos += take;
            remaining -= take;
          }
          offset += _prefix.length;
        }
        for (var i = 0; i < _parts.length && remaining > 0; i++) {
          final len = _lengths[i];
          if (pos >= offset + len) {
            offset += len;
            continue;
          }
          final localStart = _partOffsets[i] + (pos - offset);
          final take = (len - (pos - offset)) < remaining
              ? (len - (pos - offset))
              : remaining;
          await res.addStream(
            _parts[i].openRead(localStart, localStart + take),
          );
          pos += take;
          remaining -= take;
          offset += len;
        }
      } catch (_) {
        // Client closed connection early (e.g. during seek or probe).
      } finally {
        try {
          await res.close();
        } catch (_) {}
      }
    }
  }

  Future<void> close() => _server.close(force: true);
}
