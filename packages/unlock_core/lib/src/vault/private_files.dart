import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

/// Runs [body] under umask 077, so files and directories it creates synchronously are owner-only.
///
/// The umask is process-wide and restored before this returns; do not call it from two isolates at once.
/// Does nothing special on Windows.
T withOwnerOnlyUmask<T>(T Function() body) {
  if (Platform.isWindows) return body();
  final old = _umask(0x3f);
  try {
    return body();
  } finally {
    _umask(old & 0x1ff);
  }
}

/// Flushes a directory's entries to disk, so a rename in it survives a crash. Best effort.
void syncDirectory(String path) {
  if (Platform.isWindows) return;
  final fd = _open(_cString(path).address, 0);
  if (fd < 0) return;
  _fsync(fd);
  _close(fd);
}

Uint8List _cString(String s) {
  final encoded = utf8.encode(s);
  return Uint8List(encoded.length + 1)..setAll(0, encoded);
}

// dart:io can neither set a creation mode nor open a directory, so these go to libc.
@Native<Uint32 Function(Uint32)>(symbol: 'umask', isLeaf: true)
external int _umask(int mask);

@Native<Int32 Function(Pointer<Uint8>, Int32)>(symbol: 'open', isLeaf: true)
external int _open(Pointer<Uint8> path, int flags);

@Native<Int32 Function(Int32)>(symbol: 'fsync', isLeaf: true)
external int _fsync(int fd);

@Native<Int32 Function(Int32)>(symbol: 'close', isLeaf: true)
external int _close(int fd);
