import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:unlock_core/vault.dart';

import 'database.dart';
import 'errors.dart';
import 'host_repository.dart';
import 'ids.dart';

/// A named passphrase; the bytes live in its vault record.
@immutable
final class StoredSecret {
  const StoredSecret({
    required this.id,
    required this.label,
    required this.vaultRecordId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String label;
  final String vaultRecordId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class SecretRepository {
  SecretRepository(this._db, this._hosts);

  final AppDatabase _db;
  final HostRepository _hosts;

  Stream<List<StoredSecret>> watchAll() =>
      (_db.select(_db.secrets)
            ..orderBy([(s) => OrderingTerm(expression: s.label)]))
          .watch()
          .map((rows) => rows.map(_toSecret).toList());

  Future<List<StoredSecret>> all() async => [
    for (final r in await (_db.select(
      _db.secrets,
    )..orderBy([(s) => OrderingTerm(expression: s.label)])).get())
      _toSecret(r),
  ];

  Stream<StoredSecret?> watch(String id) =>
      (_db.select(_db.secrets)..where((s) => s.id.equals(id)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _toSecret(r));

  Future<StoredSecret?> get(String id) async {
    final row = await (_db.select(
      _db.secrets,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toSecret(row);
  }

  /// Stores [passphrase] exactly as given (no trimming, no newline).
  Future<StoredSecret> add(
    Vault vault, {
    required String label,
    required Uint8List passphrase,
  }) => _db.transaction(() async {
    await _requireFreeLabel(label);
    final recordId = await vault.put(VaultRecordKind.passphrase, passphrase);
    final now = DateTime.now();
    final row = await _db
        .into(_db.secrets)
        .insertReturning(
          SecretsCompanion.insert(
            id: newId(),
            label: label.trim(),
            vaultRecordId: recordId,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return _toSecret(row);
  });

  Future<void> replace(Vault vault, String id, Uint8List passphrase) =>
      _db.transaction(() async {
        final secret = await _require(id);
        await vault.replace(secret.vaultRecordId, passphrase);
        await (_db.update(_db.secrets)..where((s) => s.id.equals(id))).write(
          SecretsCompanion(updatedAt: Value(DateTime.now())),
        );
      });

  /// Throws [DuplicateLabelException] when another passphrase has the label.
  Future<void> rename(String id, String label) => _db.transaction(() async {
    await _requireFreeLabel(label, except: id);
    await (_db.update(_db.secrets)..where((s) => s.id.equals(id))).write(
      SecretsCompanion(label: Value(label.trim())),
    );
  });

  Future<void> _requireFreeLabel(String label, {String? except}) async {
    for (final s in await _db.select(_db.secrets).get()) {
      if (s.id != except && sameLabel(s.label, label)) {
        throw DuplicateLabelException('A passphrase', label.trim());
      }
    }
  }

  /// Throws [InUseException] when hosts use the secret; deletes its vault record too.
  Future<void> delete(Vault vault, String id) => _db.transaction(() async {
    final secret = await get(id);
    if (secret == null) return;
    final users = await _hosts.namesUsingSecret(id);
    if (users.isNotEmpty) {
      throw InUseException('Passphrase', secret.label, users);
    }
    await (_db.delete(_db.secrets)..where((s) => s.id.equals(id))).go();
    await vault.delete(secret.vaultRecordId);
  });

  /// Plaintext passphrase; the caller zeroes it when done.
  Future<Uint8List> reveal(Vault vault, String id) async =>
      vault.get((await _require(id)).vaultRecordId);

  Future<StoredSecret> _require(String id) async =>
      await get(id) ??
      (throw const NotFoundException('The passphrase was deleted.'));

  static StoredSecret _toSecret(SecretRow r) => StoredSecret(
    id: r.id,
    label: r.label,
    vaultRecordId: r.vaultRecordId,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );
}
