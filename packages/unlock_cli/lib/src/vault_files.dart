import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:unlock_core/vault.dart';

import 'common.dart';

const String vaultPathVariable = 'LUKS_UNLOCK_VAULT';

final RegExp labelPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._@+-]{0,63}$');

/// Labels name keys and secrets; each kind has its own namespace.
enum LabelKind {
  key('key', VaultRecordKind.sshKey),
  secret('secret', VaultRecordKind.passphrase);

  const LabelKind(this.word, this.recordKind);

  final String word;
  final VaultRecordKind recordKind;
}

/// The vault file plus the label index and lock file next to it.
final class VaultLocation {
  VaultLocation(String path) : vault = File(path).absolute.path;

  final String vault;

  String get dir => File(vault).parent.path;

  String get _stem {
    final name = vault.substring(vault.lastIndexOf('/') + 1);
    return name.endsWith('.json')
        ? name.substring(0, name.length - '.json'.length)
        : name;
  }

  String get index => '$dir/$_stem.index.json';
  String get lock => '$dir/$_stem.lock';

  /// Where `vault init` builds the vault before renaming it into place.
  String get staging => '$vault.new';

  bool get exists => File(vault).existsSync();

  /// `--vault`, else `$LUKS_UNLOCK_VAULT`, else `$XDG_DATA_HOME` or `~/.local/share`.
  static VaultLocation resolve(String? flag, Map<String, String> env) {
    String? nonEmpty(String? s) => s == null || s.isEmpty ? null : s;
    final explicit = nonEmpty(flag) ?? nonEmpty(env[vaultPathVariable]);
    final home = nonEmpty(env['HOME']);
    if (explicit != null) {
      return VaultLocation(
        home != null && explicit.startsWith('~/')
            ? '$home${explicit.substring(1)}'
            : explicit,
      );
    }
    var data = nonEmpty(env['XDG_DATA_HOME']);
    if (data == null || !data.startsWith('/')) {
      if (home == null) {
        throw const CliExit.usage(
          'cannot place the vault: HOME is not set; use --vault PATH',
        );
      }
      data = '$home/.local/share';
    }
    return VaultLocation('$data/luks-remote-unlocker/vault.json');
  }

  /// Runs [body] holding an exclusive lock, so writers do not overwrite each other.
  Future<T> exclusive<T>(Future<T> Function() body) async {
    await ensurePrivateDir(dir);
    final file = withOwnerOnlyUmask(
      () => File(lock).openSync(mode: FileMode.append),
    );
    try {
      file.lockSync(FileLock.blockingExclusive);
      return await body();
    } finally {
      file.closeSync();
    }
  }
}

String checkLabel(String? label, String helpFor) {
  if (label == null) throw CliExit.usage('--label is required', helpFor);
  if (!labelPattern.hasMatch(label)) {
    throw CliExit.usage(
      'invalid label "$label": use up to 64 letters, digits and ._@+- '
      'starting with a letter or digit',
      helpFor,
    );
  }
  return label;
}

/// One label. Unauthenticated: the record itself proves its label, see [SealedLabel].
final class IndexEntry {
  const IndexEntry({
    required this.label,
    required this.recordId,
    required this.created,
  });

  /// Ignores the public key fields older versions stored.
  factory IndexEntry.fromJson(Object? json) {
    if (json is! Map<String, Object?>) throw const FormatException('entry');
    String req(String k) => switch (json[k]) {
      final String s => s,
      _ => throw FormatException(k),
    };
    return IndexEntry(
      label: req('label'),
      recordId: req('recordId'),
      created: DateTime.parse(req('created')),
    );
  }

  final String label;
  final String recordId;
  final DateTime created;

  Map<String, Object?> toJson() => {
    'label': label,
    'recordId': recordId,
    'created': created.toUtc().toIso8601String(),
  };
}

/// Record payload written by this CLI: the label is sealed with the secret, so a changed index is detected.
abstract final class SealedLabel {
  static const _magic = [0x00, 0x6c, 0x62, 0x31];
  static const _header = 5;

  /// Header, label, secret; the caller wipes the result.
  static Uint8List seal(String label, Uint8List secret) {
    final name = ascii.encode(label);
    if (name.length > 255) throw ArgumentError.value(label, 'label');
    return Uint8List(_header + name.length + secret.length)
      ..setAll(0, _magic)
      ..[4] = name.length
      ..setAll(_header, name)
      ..setAll(_header + name.length, secret);
  }

  /// The sealed label, null for a record from before labels were sealed, and a view of the secret.
  static (String?, Uint8List) open(Uint8List payload) {
    for (var i = 0; i < _magic.length; i++) {
      if (i >= payload.length || payload[i] != _magic[i]) return (null, payload);
    }
    final end = payload.length > 4 ? _header + payload[4] : -1;
    if (end < 0 || end > payload.length) {
      throw const CliExit.failure('damaged vault record: bad label header');
    }
    final String label;
    try {
      label = ascii.decode(Uint8List.sublistView(payload, _header, end));
    } on FormatException {
      throw const CliExit.failure('damaged vault record: bad label');
    }
    return (label, Uint8List.sublistView(payload, end));
  }
}

/// Non-secret map from labels to vault record ids, stored as JSON next to the vault.
final class VaultIndex {
  VaultIndex(this.vaultId, {List<IndexEntry>? keys, List<IndexEntry>? secrets})
    : _entries = {LabelKind.key: keys ?? [], LabelKind.secret: secrets ?? []};

  static const int version = 1;

  final String vaultId;
  final Map<LabelKind, List<IndexEntry>> _entries;

  List<IndexEntry> of(LabelKind kind) => List.unmodifiable(_entries[kind]!);

  IndexEntry? find(LabelKind kind, String label) {
    for (final e in _entries[kind]!) {
      if (e.label == label) return e;
    }
    return null;
  }

  void add(LabelKind kind, IndexEntry entry) {
    if (find(kind, entry.label) != null) {
      throw CliExit.failure(
        'a ${kind.word} labelled ${entry.label} already exists',
      );
    }
    _entries[kind]!.add(entry);
  }

  void remove(LabelKind kind, String label) =>
      _entries[kind]!.removeWhere((e) => e.label == label);

  Set<String> get recordIds => {
    for (final list in _entries.values)
      for (final e in list) e.recordId,
  };

  /// A missing index is an empty one; an index of another vault is refused.
  static VaultIndex load(VaultLocation loc, String vaultId) {
    final file = File(loc.index);
    if (!file.existsSync()) return VaultIndex(vaultId);
    final VaultIndex index;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map<String, Object?> || json['version'] != version) {
        throw const FormatException('version');
      }
      List<IndexEntry> list(String k) => switch (json[k]) {
        null => [],
        final List<Object?> l => [for (final e in l) IndexEntry.fromJson(e)],
        _ => throw FormatException(k),
      };
      final id = json['vaultId'];
      if (id is! String) throw const FormatException('vaultId');
      index = VaultIndex(id, keys: list('keys'), secrets: list('secrets'));
    } on FormatException catch (e) {
      throw CliExit.failure('damaged label index ${loc.index} (${e.message})');
    } on FileSystemException catch (e) {
      throw CliExit.failure('${loc.index}: ${osMessage(e)}');
    }
    if (index.vaultId != vaultId) {
      throw CliExit.failure(
        'label index ${loc.index} belongs to another vault (${index.vaultId})',
      );
    }
    return index;
  }

  Future<void> save(VaultLocation loc) => writePrivateAtomic(
    loc.index,
    utf8.encode(
      '${const JsonEncoder.withIndent('  ').convert({
        'version': version,
        'vaultId': vaultId,
        'keys': [for (final e in _entries[LabelKind.key]!) e.toJson()],
        'secrets': [for (final e in _entries[LabelKind.secret]!) e.toJson()],
      })}\n',
    ),
  );
}

/// Writes a temp file created with mode 0600, renames it over [path] and syncs the directory.
Future<void> writePrivateAtomic(String path, List<int> bytes) async {
  final temp = File('$path.tmp');
  try {
    withOwnerOnlyUmask(() {
      if (temp.existsSync()) temp.deleteSync();
      temp.createSync(exclusive: true);
    });
    temp.writeAsBytesSync(bytes, flush: true);
    temp.renameSync(path);
    syncDirectory(temp.parent.path);
  } catch (_) {
    if (temp.existsSync()) temp.deleteSync();
    rethrow;
  }
}

/// Creates missing directories with mode 0700.
Future<void> ensurePrivateDir(String path) async {
  final dir = Directory(path);
  if (dir.existsSync()) return;
  withOwnerOnlyUmask(() => dir.createSync(recursive: true));
}
