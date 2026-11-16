import '../vault/biometric_slot.dart';
import 'database.dart';

abstract interface class VaultSettings {
  /// The biometric store that holds the vault key (or will, once enrolled).
  Future<BiometricStoreRef> biometricStore();

  /// Points at [ref]; both fields are written in one transaction.
  Future<void> setBiometricStore(BiometricStoreRef ref);
}

final class SettingsRepository implements VaultSettings {
  SettingsRepository(this._db);

  static const _deviceCredential = 'vault.allowDeviceCredential';
  static const _alternate = 'vault.biometricAlternate';

  final AppDatabase _db;

  @override
  Future<BiometricStoreRef> biometricStore() async => BiometricStoreRef(
    allowDeviceCredential: await _read(_deviceCredential) == 'true',
    alternate: await _read(_alternate) == 'true',
  );

  @override
  Future<void> setBiometricStore(BiometricStoreRef ref) =>
      _db.transaction(() async {
        await _write(_deviceCredential, '${ref.allowDeviceCredential}');
        await _write(_alternate, '${ref.alternate}');
      });

  Future<String?> _read(String key) async => (await (_db.select(
    _db.appSettings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _write(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );
}
