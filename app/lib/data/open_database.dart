import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

const databaseFileName = 'luks_remote_unlocker.sqlite';

/// Opens the database in [directory], by default the app support dir (XDG data dir on Linux).
Future<AppDatabase> openAppDatabase({String? directory}) async {
  final dir = directory ?? (await getApplicationSupportDirectory()).path;
  await Directory(dir).create(recursive: true);
  return AppDatabase(
    NativeDatabase.createInBackground(File(p.join(dir, databaseFileName))),
  );
}
