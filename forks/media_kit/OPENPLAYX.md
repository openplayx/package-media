# OpenPlayX fork of media_kit 1.2.6

Copied from pub.dev media_kit 1.2.6 (MIT, see LICENSE). Changes:

- Apple TV (flutter-tvos, `Platform.operatingSystem == 'tvos'`) uses the iOS
  code paths and loads `Mpv.framework/Mpv` (lib/src/tvos*.dart and the
  `isTvOS` checks).

Native libraries come from package-media (libs/), not media_kit's packages.
