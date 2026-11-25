# OpenPlayX fork of media_kit_video 2.0.1

Copied from pub.dev media_kit_video 2.0.1 (MIT, see LICENSE). Changes:

- Apple TV (flutter-tvos) uses the iOS code paths in Dart and gets a native
  plugin (tvos/), ported from ios/ (OpenGL ES textures, VideoToolbox).
- The tvOS podspec links package-media's libs/media_kit_libs_tvos_video.
- No wakelock_plus dependency (no tvOS implementation; flutter-tvos registers
  every plugin in the graph): `Wakelock` is a no-op and the app keeps the
  screen on during playback.
