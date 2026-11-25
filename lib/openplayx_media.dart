/// OpenPlayX playback: libVLC and libmpv engines behind one interface, and
/// [RoutedPlayerBackend], which picks the engine per media.
library;

// The playback contract (PlayerBackend and its value types) and the libVLC
// engine.
export 'package:openplayx_playback/playback.dart';

export 'src/mpv_backend.dart';
export 'src/routed_backend.dart';
