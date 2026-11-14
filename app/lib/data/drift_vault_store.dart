import 'package:drift/drift.dart';
import 'package:unlock_core/vault.dart';

import 'database.dart';

/// A vault store that can wipe everything the vault encrypts.
abstract interface class ResettableVaultStore implements VaultStore {
  Future<void> reset();
}

/// [VaultStore] in the app database; holds ciphertext and public parameters only.
final class DriftVaultStore implements ResettableVaultStore {
  DriftVaultStore(this._db);

  final AppDatabase _db;

  @override
  Future<VaultMetadata?> readMetadata() async {
    final row = await _db.select(_db.vaultMetadataTable).getSingleOrNull();
    if (row == null) return null;
    return VaultMetadata(
      formatVersion: row.formatVersion,
      vaultId: row.vaultId,
      keyCheckNonce: row.keyCheckNonce,
      keyCheck: row.keyCheck,
      biometricSlotEnrolled: row.biometricSlotEnrolled,
    );
  }

  @override
  Future<void> writeMetadata(VaultMetadata metadata) => _db
      .into(_db.vaultMetadataTable)
      .insertOnConflictUpdate(
        VaultMetadataTableCompanion.insert(
          id: const Value(1),
          formatVersion: metadata.formatVersion,
          vaultId: metadata.vaultId,
          keyCheckNonce: metadata.keyCheckNonce,
          keyCheck: metadata.keyCheck,
          biometricSlotEnrolled: metadata.biometricSlotEnrolled,
        ),
      );

  @override
  Future<PasswordSlot?> readPasswordSlot() async {
    final row = await _db.select(_db.vaultPasswordSlot).getSingleOrNull();
    if (row == null) return null;
    return PasswordSlot(
      salt: row.salt,
      params: Argon2Params(
        memoryKiB: row.memoryKib,
        iterations: row.iterations,
        parallelism: row.parallelism,
      ),
      nonce: row.nonce,
      wrappedKey: row.wrappedKey,
    );
  }

  @override
  Future<void> writePasswordSlot(PasswordSlot slot) => _db
      .into(_db.vaultPasswordSlot)
      .insertOnConflictUpdate(
        VaultPasswordSlotCompanion.insert(
          id: const Value(1),
          salt: slot.salt,
          memoryKib: slot.params.memoryKiB,
          iterations: slot.params.iterations,
          parallelism: slot.params.parallelism,
          nonce: slot.nonce,
          wrappedKey: slot.wrappedKey,
        ),
      );

  @override
  Future<void> deletePasswordSlot() => _db.delete(_db.vaultPasswordSlot).go();

  @override
  Future<VaultRecord?> readRecord(String id) async {
    final row = await (_db.select(
      _db.vaultRecords,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return VaultRecord(
      id: row.id,
      kind: VaultRecordKind.fromWireName(row.kind),
      nonce: row.nonce,
      ciphertext: row.ciphertext,
    );
  }

  @override
  Future<List<String>> listRecordIds() async {
    final query = _db.selectOnly(_db.vaultRecords)
      ..addColumns([_db.vaultRecords.id]);
    return [
      for (final row in await query.get()) row.read(_db.vaultRecords.id)!,
    ];
  }

  @override
  Future<void> writeRecord(VaultRecord record) => _db
      .into(_db.vaultRecords)
      .insertOnConflictUpdate(
        VaultRecordsCompanion.insert(
          id: record.id,
          kind: record.kind.wireName,
          nonce: record.nonce,
          ciphertext: record.ciphertext,
        ),
      );

  @override
  Future<void> deleteRecord(String id) =>
      (_db.delete(_db.vaultRecords)..where((r) => r.id.equals(id))).go();

  /// Also deletes keys and secrets and unassigns them from hosts.
  @override
  Future<void> reset() => _db.transaction(() async {
    await _db
        .update(_db.hosts)
        .write(
          const HostsCompanion(
            keyId: Value(null),
            secretId: Value(null),
            diskOverridesJson: Value('{}'),
          ),
        );
    await _db.delete(_db.sshKeys).go();
    await _db.delete(_db.secrets).go();
    await _db.delete(_db.vaultRecords).go();
    await _db.delete(_db.vaultPasswordSlot).go();
    await _db.delete(_db.vaultMetadataTable).go();
  });
}
