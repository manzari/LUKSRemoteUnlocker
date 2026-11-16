import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

const databaseFileName = 'luks_remote_unlocker.sqlite';

/// Opens the database in [directory], by default the app support dir (XDG data dir on Linux).
Future<AppDatabase> openAppDatabase({String? directory}) async {
  final dir = directory ?? (await getApplicationSupportDirectory()).path;
  await Directory(dir).create(recursive: true);
  final file = File(p.join(dir, databaseFileName));
  restrictDatabaseAccess(dir, file);
  return AppDatabase(NativeDatabase.createInBackground(file));
}

/// Owner-only access on Linux and macOS; SQLite gives -journal, -wal and -shm files the database file's mode.
@visibleForTesting
void restrictDatabaseAccess(String dir, File file) {
  if (!Platform.isLinux && !Platform.isMacOS) return;
  if (!file.existsSync()) file.createSync();
  _chmodOrWarn(dir, 0x1c0);
  for (final suffix in ['', '-journal', '-wal', '-shm']) {
    final path = '${file.path}$suffix';
    if (File(path).existsSync()) _chmodOrWarn(path, 0x180);
  }
}

void _chmodOrWarn(String path, int mode) {
  final encoded = utf8.encode(path);
  final cPath = Uint8List(encoded.length + 1)..setAll(0, encoded);
  if (_chmod(cPath.address, mode) != 0) {
    debugPrint('Could not restrict access to $path');
  }
}

// dart:io cannot change file modes.
@Native<Int32 Function(Pointer<Uint8>, Uint32)>(symbol: 'chmod', isLeaf: true)
external int _chmod(Pointer<Uint8> path, int mode);
