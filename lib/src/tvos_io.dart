import 'dart:io';

/// Whether the app runs on Apple TV (flutter-tvos reports "tvos").
bool get isTvOS => Platform.operatingSystem == 'tvos';
