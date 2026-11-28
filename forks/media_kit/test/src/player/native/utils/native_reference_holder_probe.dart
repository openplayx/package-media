import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:media_kit/src/player/native/utils/native_reference_holder.dart';
import 'package:media_kit/src/player/native/utils/process_identity.dart';
import 'package:media_kit/src/player/native/utils/temp_file.dart';

Future<void> main() async {
  final prefix = path.join(TempFile.directory,
      'com.alexmercerind.media_kit.NativeReferenceHolder.$pid');
  final oldFile = File(prefix);
  final newFile = File('$prefix.${nativeProcessStartToken()}');
  // Reproduce the stale pointer file left when an earlier process used this
  // PID. Dereferencing address 1 would crash the unpatched implementation.
  oldFile.writeAsStringSync('1');
  try {
    NativeReferenceHolder.ensureInitialized((references) {
      if (references.isNotEmpty) throw StateError('Loaded stale references');
    });
    await NativeReferenceHolder.instance.add(Pointer<Void>.fromAddress(42));
    await NativeReferenceHolder.instance.remove(Pointer<Void>.fromAddress(42));
    if (!newFile.existsSync())
      throw StateError('Missing process-specific file');
    print('stale PID pointer ignored');
  } finally {
    if (oldFile.existsSync()) oldFile.deleteSync();
    if (newFile.existsSync()) newFile.deleteSync();
  }
}
