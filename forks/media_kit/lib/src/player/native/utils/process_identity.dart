import 'dart:ffi';
import 'dart:io';

import 'package:media_kit/ffi/src/allocation.dart';

/// Stable across Dart hot restarts, but different when the OS reuses a PID.
/// Persisted native addresses must never be loaded by a later process.
String nativeProcessStartToken() {
  if (Platform.isLinux || Platform.isAndroid) {
    final stat = File('/proc/self/stat').readAsStringSync();
    // comm (field 2) may contain spaces or parentheses. Fields after its final
    // ')' start at state (3); starttime is field 22, in kernel clock ticks.
    return stat.substring(stat.lastIndexOf(')') + 2).split(RegExp(r'\s+'))[19];
  }
  if (Platform.isWindows) {
    final currentProcess = stdlib.lookupFunction<Pointer<Void> Function(),
        Pointer<Void> Function()>('GetCurrentProcess');
    final times = stdlib.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Uint64>, Pointer<Uint64>,
            Pointer<Uint64>, Pointer<Uint64>),
        int Function(Pointer<Void>, Pointer<Uint64>, Pointer<Uint64>,
            Pointer<Uint64>, Pointer<Uint64>)>('GetProcessTimes');
    // FILETIME is two little-endian DWORDs: read the creation time as uint64.
    final values = calloc<Uint64>(4);
    try {
      if (times(currentProcess(), values, values + 1, values + 2, values + 3) ==
          0) {
        throw StateError('GetProcessTimes failed');
      }
      return values.value.toString();
    } finally {
      calloc.free(values);
    }
  }
  if (Platform.isMacOS ||
      Platform.isIOS ||
      Platform.operatingSystem == 'tvos') {
    final sysctl = stdlib.lookupFunction<
        Int32 Function(Pointer<Int32>, Uint32, Pointer<Void>, Pointer<Size>,
            Pointer<Void>, Size),
        int Function(Pointer<Int32>, int, Pointer<Void>, Pointer<Size>,
            Pointer<Void>, int)>('sysctl');
    final mib = calloc<Int32>(4);
    final size = calloc<Size>();
    Pointer<Uint8> info = nullptr;
    try {
      // Public Darwin sysctl ABI: CTL_KERN, KERN_PROC, KERN_PROC_PID, pid.
      mib.asTypedList(4).setAll(0, [1, 14, 1, pid]);
      if (sysctl(mib, 4, nullptr, size, nullptr, 0) != 0 || size.value < 16) {
        throw StateError('Cannot query process start time');
      }
      info = calloc<Uint8>(size.value);
      if (sysctl(mib, 4, info.cast(), size, nullptr, 0) != 0 ||
          size.value < 16) {
        throw StateError('Cannot read process start time');
      }
      // kinfo_proc begins with extern_proc.p_starttime (struct timeval).
      final seconds = info.cast<Long>().value;
      final micros = (info + sizeOf<Long>()).cast<Int32>().value;
      return '$seconds-$micros';
    } finally {
      calloc.free(info);
      calloc.free(size);
      calloc.free(mib);
    }
  }
  throw UnsupportedError('Process identity on ${Platform.operatingSystem}');
}
