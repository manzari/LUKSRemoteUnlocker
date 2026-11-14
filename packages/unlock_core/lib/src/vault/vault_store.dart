import 'vault_models.dart';

/// Persistence for vault data. Holds only ciphertext and public parameters.
abstract interface class VaultStore {
  Future<VaultMetadata?> readMetadata();
  Future<void> writeMetadata(VaultMetadata metadata);

  Future<PasswordSlot?> readPasswordSlot();
  Future<void> writePasswordSlot(PasswordSlot slot);
  Future<void> deletePasswordSlot();

  Future<VaultRecord?> readRecord(String id);
  Future<List<String>> listRecordIds();

  /// Inserts the record, or replaces the one with the same id.
  Future<void> writeRecord(VaultRecord record);
  Future<void> deleteRecord(String id);
}

final class InMemoryVaultStore implements VaultStore {
  VaultMetadata? _metadata;
  PasswordSlot? _slot;
  final Map<String, VaultRecord> _records = {};

  @override
  Future<VaultMetadata?> readMetadata() async => _metadata;

  @override
  Future<void> writeMetadata(VaultMetadata metadata) async =>
      _metadata = metadata;

  @override
  Future<PasswordSlot?> readPasswordSlot() async => _slot;

  @override
  Future<void> writePasswordSlot(PasswordSlot slot) async => _slot = slot;

  @override
  Future<void> deletePasswordSlot() async => _slot = null;

  @override
  Future<VaultRecord?> readRecord(String id) async => _records[id];

  @override
  Future<List<String>> listRecordIds() async => List.of(_records.keys);

  @override
  Future<void> writeRecord(VaultRecord record) async =>
      _records[record.id] = record;

  @override
  Future<void> deleteRecord(String id) async => _records.remove(id);
}
