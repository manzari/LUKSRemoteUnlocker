import 'database.dart';

abstract interface class VaultSettings {
  Future<bool> allowDeviceCredential();
  Future<void> setAllowDeviceCredential(bool value);
}

final class SettingsRepository implements VaultSettings {
  SettingsRepository(this._db);

  static const _deviceCredential = 'vault.allowDeviceCredential';

  final AppDatabase _db;

  @override
  Future<bool> allowDeviceCredential() async =>
      await _read(_deviceCredential) == 'true';

  @override
  Future<void> setAllowDeviceCredential(bool value) =>
      _write(_deviceCredential, '$value');

  Future<String?> _read(String key) async => (await (_db.select(
    _db.appSettings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _write(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );
}
