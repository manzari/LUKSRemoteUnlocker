import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:unlock_core/keys.dart';
import 'package:unlock_core/vault.dart';

import 'database.dart';
import 'errors.dart';
import 'host_repository.dart';
import 'ids.dart';

/// Public parts of a stored SSH key; the private key lives in its vault record.
@immutable
final class StoredKey {
  const StoredKey({
    required this.id,
    required this.label,
    required this.typeName,
    required this.bits,
    required this.publicLine,
    required this.fingerprint,
    required this.vaultRecordId,
    required this.createdAt,
  });

  final String id;
  final String label;

  /// Wire name such as `ssh-ed25519`.
  final String typeName;
  final int bits;
  final String publicLine;
  final String fingerprint;
  final String vaultRecordId;
  final DateTime createdAt;

  String get typeLabel => switch (SshKeyType.fromWireName(typeName)) {
    SshKeyType.ed25519 => 'Ed25519',
    SshKeyType.rsa => 'RSA $bits',
    SshKeyType.ecdsaP256 ||
    SshKeyType.ecdsaP384 ||
    SshKeyType.ecdsaP521 => 'ECDSA $bits',
    null => typeName,
  };
}

final class KeyRepository {
  KeyRepository(this._db, this._hosts);

  final AppDatabase _db;
  final HostRepository _hosts;

  Stream<List<StoredKey>> watchAll() =>
      (_db.select(_db.sshKeys)
            ..orderBy([(k) => OrderingTerm(expression: k.label)]))
          .watch()
          .map((rows) => rows.map(_toKey).toList());

  Future<List<StoredKey>> all() async => [
    for (final r in await (_db.select(
      _db.sshKeys,
    )..orderBy([(k) => OrderingTerm(expression: k.label)])).get())
      _toKey(r),
  ];

  Stream<StoredKey?> watch(String id) =>
      (_db.select(_db.sshKeys)..where((k) => k.id.equals(id)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _toKey(r));

  Future<StoredKey?> get(String id) async {
    final row = await (_db.select(
      _db.sshKeys,
    )..where((k) => k.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toKey(row);
  }

  /// Encrypts the private key into the vault and stores the public parts.
  Future<StoredKey> add(
    Vault vault,
    SshKey key, {
    required String label,
  }) => _db.transaction(() async {
    final existing = await (_db.select(
      _db.sshKeys,
    )..where((k) => k.fingerprint.equals(key.fingerprint))).getSingleOrNull();
    if (existing != null) throw DuplicateKeyException(existing.label);
    await _requireFreeLabel(label);
    final recordId = await vault.put(VaultRecordKind.sshKey, key.privateKeyPem);
    final row = SshKeysCompanion.insert(
      id: newId(),
      label: label.trim(),
      keyType: key.type.wireName,
      bits: key.bits,
      publicLine: key.publicLine,
      fingerprint: key.fingerprint,
      vaultRecordId: recordId,
      createdAt: DateTime.now(),
    );
    return _toKey(await _db.into(_db.sshKeys).insertReturning(row));
  });

  /// Throws [DuplicateLabelException] when another key has the label.
  Future<void> rename(String id, String label) => _db.transaction(() async {
    await _requireFreeLabel(label, except: id);
    await (_db.update(_db.sshKeys)..where((k) => k.id.equals(id))).write(
      SshKeysCompanion(label: Value(label.trim())),
    );
  });

  Future<void> _requireFreeLabel(String label, {String? except}) async {
    for (final k in await _db.select(_db.sshKeys).get()) {
      if (k.id != except && sameLabel(k.label, label)) {
        throw DuplicateLabelException('A key', label.trim());
      }
    }
  }

  /// Throws [InUseException] when hosts use the key; deletes its vault record too.
  Future<void> delete(Vault vault, String id) => _db.transaction(() async {
    final key = await get(id);
    if (key == null) return;
    final users = await _hosts.namesUsingKey(id);
    if (users.isNotEmpty) throw InUseException('Key', key.label, users);
    await (_db.delete(_db.sshKeys)..where((k) => k.id.equals(id))).go();
    await vault.delete(key.vaultRecordId);
  });

  /// Unencrypted OpenSSH private key; the caller zeroes it when done.
  Future<Uint8List> privateKeyPem(Vault vault, String id) async {
    final key = await get(id);
    if (key == null) throw const NotFoundException('The SSH key was deleted.');
    return vault.get(key.vaultRecordId);
  }

  static StoredKey _toKey(SshKeyRow r) => StoredKey(
    id: r.id,
    label: r.label,
    typeName: r.keyType,
    bits: r.bits,
    publicLine: r.publicLine,
    fingerprint: r.fingerprint,
    vaultRecordId: r.vaultRecordId,
    createdAt: r.createdAt,
  );
}
