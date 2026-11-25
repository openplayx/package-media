// Apple TV (flutter-tvos) detection without importing dart:io on the web.
export 'tvos_stub.dart' if (dart.library.io) 'tvos_io.dart';
