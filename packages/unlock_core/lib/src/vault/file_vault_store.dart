import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'vault_exceptions.dart';
import 'vault_models.dart';
import 'vault_store.dart';

/// [VaultStore] in one JSON file (mode 0600); each write replaces it atomically via temp file + rename.
final class FileVaultStore implements VaultStore {
  FileVaultStore._(this.path, this._state, this._onBeforeRename);

  static const int fileVersion = 1;

  /// Loads [path] if it exists; the file is created on the first write. [onBeforeRename] is a fault-injection hook for tests.
  static Future<FileVaultStore> open(
    String path, {
    Future<void> Function()? onBeforeRename,
  }) async {
    final file = File(path);
    final state = file.existsSync()
        ? _FileState.decode(await file.readAsBytes())
        : _FileState.empty;
    return FileVaultStore._(path, state, onBeforeRename);
  }

  final String path;
  final Future<void> Function()? _onBeforeRename;
  _FileState _state;
  Future<void> _queue = Future<void>.value();

  String get tempPath => '$path.tmp';

  @override
  Future<VaultMetadata?> readMetadata() async => _state.metadata;

  @override
  Future<void> writeMetadata(VaultMetadata metadata) =>
      _update((s) => s.withMetadata(metadata));

  @override
  Future<PasswordSlot?> readPasswordSlot() async => _state.slot;

  @override
  Future<void> writePasswordSlot(PasswordSlot slot) =>
      _update((s) => s.withSlot(slot));

  @override
  Future<void> deletePasswordSlot() => _update((s) => s.withSlot(null));

  @override
  Future<VaultRecord?> readRecord(String id) async => _state.records[id];

  @override
  Future<List<String>> listRecordIds() async => List.of(_state.records.keys);

  @override
  Future<void> writeRecord(VaultRecord record) =>
      _update((s) => s.withRecord(record));

  @override
  Future<void> deleteRecord(String id) => _update((s) => s.withoutRecord(id));

  // Writes run one at a time; memory changes only after the file was replaced.
  Future<void> _update(_FileState Function(_FileState current) change) {
    final done = _queue.then((_) async {
      final next = change(_state);
      await _persist(next);
      _state = next;
    });
    _queue = done.then<void>((_) {}, onError: (Object _) {});
    return done;
  }

  Future<void> _persist(_FileState state) async {
    final bytes = utf8.encode(jsonEncode(state.toJson()));
    final temp = File(tempPath);
    await _ensureDirectory(temp.parent);
    try {
      if (temp.existsSync()) {
        await temp.delete();
      }
      await temp.create(exclusive: true);
      await _chmod('600', temp.path);
      await temp.writeAsBytes(bytes, flush: true);
      await _onBeforeRename?.call();
      await temp.rename(path);
    } catch (_) {
      await _deleteQuietly(temp);
      rethrow;
    }
  }

  static Future<void> _ensureDirectory(Directory dir) async {
    if (dir.existsSync()) {
      return;
    }
    await dir.create(recursive: true);
    await _chmod('700', dir.path);
  }

  static Future<void> _chmod(String mode, String target) async {
    if (Platform.isWindows) {
      return;
    }
    final result = await Process.run('chmod', [mode, '--', target]);
    if (result.exitCode != 0) {
      throw FileSystemException('chmod $mode failed', target);
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException {
      // Best effort: the original error is rethrown by the caller.
    }
  }
}

final class _FileState {
  const _FileState(this.metadata, this.slot, this.records);

  static const _FileState empty = _FileState(null, null, {});

  final VaultMetadata? metadata;
  final PasswordSlot? slot;
  final Map<String, VaultRecord> records;

  _FileState withMetadata(VaultMetadata value) =>
      _FileState(value, slot, records);

  _FileState withSlot(PasswordSlot? value) =>
      _FileState(metadata, value, records);

  _FileState withRecord(VaultRecord record) =>
      _FileState(metadata, slot, {...records, record.id: record});

  _FileState withoutRecord(String id) =>
      _FileState(metadata, slot, Map.of(records)..remove(id));

  Map<String, Object?> toJson() => {
    'fileVersion': FileVaultStore.fileVersion,
    'metadata': metadata?.toJson(),
    'passwordSlot': slot?.toJson(),
    'records': [for (final record in records.values) record.toJson()],
  };

  static _FileState decode(Uint8List bytes) {
    const malformed = VaultCorruptException('malformed vault file');
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw malformed;
    }
    if (json is! Map<String, Object?>) {
      throw malformed;
    }
    final version = json['fileVersion'];
    if (version is! int) {
      throw malformed;
    }
    if (version != FileVaultStore.fileVersion) {
      throw VaultUnsupportedVersionException(version);
    }
    final recordList = json['records'];
    if (recordList is! List<Object?>) {
      throw malformed;
    }
    final records = <String, VaultRecord>{};
    for (final item in recordList) {
      final record = VaultRecord.fromJson(item);
      if (records.containsKey(record.id)) {
        throw malformed;
      }
      records[record.id] = record;
    }
    final metadata = json['metadata'];
    final slot = json['passwordSlot'];
    return _FileState(
      metadata == null ? null : VaultMetadata.fromJson(metadata),
      slot == null ? null : PasswordSlot.fromJson(slot),
      records,
    );
  }
}
