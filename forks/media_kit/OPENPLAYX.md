# OpenPlayX fork of media_kit 1.2.6

Copied from pub.dev media_kit 1.2.6 (MIT, see LICENSE). Changes:

- Apple TV (flutter-tvos, `Platform.operatingSystem == 'tvos'`) uses the iOS
  code paths and loads `Mpv.framework/Mpv` (lib/src/tvos*.dart and the
  `isTvOS` checks).
- A media that ends with `MPV_END_FILE_REASON_ERROR` (cannot be loaded) is
  reported on `stream.error` (lib/src/player/native/player/real.dart), so
  corrupt files and HTTP errors are errors, not an idle or ended player.

Native libraries come from package-media (libs/), not media_kit's packages.
