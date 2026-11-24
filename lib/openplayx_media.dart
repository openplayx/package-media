/// OpenPlayX playback: libVLC and libmpv engines behind one interface.
library;

// The playback contract (PlayerBackend and its value types) and the libVLC
// engine. The contract moves into this package with the engine router.
export 'package:openplayx_playback/playback.dart';

export 'src/mpv_backend.dart';
