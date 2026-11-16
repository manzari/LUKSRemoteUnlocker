import 'dart:typed_data';

import 'vault_crypto.dart';
import 'vault_exceptions.dart';
import 'vault_key_store.dart';
import 'vault_models.dart';
import 'vault_store.dart';

enum VaultState { locked, unlocked }

/// Secrets encrypted under one random vault key, released by a password slot and/or a biometric slot.
final class Vault {
  Vault._(this._store, this._kdf, this._metadata, this._hasPasswordSlot);

  static const int formatVersion = 1;

  final VaultStore _store;
  final PasswordKdf _kdf;
  VaultMetadata _metadata;
  bool _hasPasswordSlot;
  Uint8List? _key;
  int _lockCount = 0;

  static Future<bool> exists(VaultStore store) async =>
      await store.readMetadata() != null;

  /// Creates an unlocked vault with a new random key and no slots; the store must be empty.
  static Future<Vault> create(
    VaultStore store, {
    PasswordKdf kdf = argon2idInIsolate,
  }) async {
    if (await store.readMetadata() != null ||
        await store.readPasswordSlot() != null ||
        (await store.listRecordIds()).isNotEmpty) {
      throw const VaultAlreadyExistsException();
    }
    final key = randomBytes(vaultKeyLength);
    try {
      final vaultId = randomId();
      final check = await sealBox(
        key,
        Uint8List(0),
        keyCheckAad(formatVersion: formatVersion, vaultId: vaultId),
      );
      final metadata = VaultMetadata(
        formatVersion: formatVersion,
        vaultId: vaultId,
        keyCheckNonce: check.nonce,
        keyCheck: check.ciphertext,
        biometricSlotEnrolled: false,
      );
      await store.writeMetadata(metadata);
      return Vault._(store, kdf, metadata, false).._key = key;
    } catch (_) {
      zeroBytes(key);
      rethrow;
    }
  }

  /// Opens an existing vault, locked.
  static Future<Vault> open(
    VaultStore store, {
    PasswordKdf kdf = argon2idInIsolate,
  }) async {
    final metadata = await store.readMetadata();
    if (metadata == null) {
      throw const VaultNotInitializedException();
    }
    if (metadata.formatVersion != formatVersion) {
      throw VaultUnsupportedVersionException(metadata.formatVersion);
    }
    if (!isValidId(metadata.vaultId) ||
        metadata.keyCheckNonce.length != nonceLength ||
        metadata.keyCheck.length != tagLength) {
      throw const VaultCorruptException('malformed vault metadata');
    }
    final hasSlot = await store.readPasswordSlot() != null;
    return Vault._(store, kdf, metadata, hasSlot);
  }

  String get id => _metadata.vaultId;

  VaultState get state =>
      _key == null ? VaultState.locked : VaultState.unlocked;

  bool get isUnlocked => _key != null;

  bool get hasPasswordSlot => _hasPasswordSlot;

  /// True once a biometric slot was enrolled, even if the platform has since invalidated it.
  bool get biometricSlotEnrolled => _metadata.biometricSlotEnrolled;

  Future<void> unlockWithPassword(Uint8List password) async {
    final lockCount = _lockCount;
    final slot = await _store.readPasswordSlot();
    if (slot == null) {
      throw const VaultNoSlotException('no password slot');
    }
    if (slot.salt.length != saltLength ||
        slot.nonce.length != nonceLength ||
        slot.wrappedKey.length != vaultKeyLength + tagLength ||
        !slot.params.isWithinBounds) {
      throw const VaultCorruptException('malformed password slot');
    }
    final kek = await _kdf(password, slot.salt, slot.params);
    final Uint8List? key;
    try {
      key = await openBox(
        kek,
        slot.nonce,
        slot.wrappedKey,
        _passwordSlotAad(slot.params, slot.salt),
      );
    } finally {
      zeroBytes(kek);
    }
    if (key == null) {
      throw const VaultWrongPasswordException();
    }
    await _adopt(
      key,
      lockCount,
      const VaultCorruptException('password slot does not match this vault'),
    );
  }

  Future<void> unlockWithKeyStore(VaultKeyStore keyStore) async {
    if (!_metadata.biometricSlotEnrolled) {
      throw const VaultNoSlotException('no biometric slot enrolled');
    }
    final lockCount = _lockCount;
    final key = await keyStore.read();
    if (key == null) {
      throw const VaultKeyInvalidatedException('biometric slot is empty');
    }
    await _adopt(
      key,
      lockCount,
      const VaultKeyInvalidatedException(
        'biometric slot does not open this vault',
      ),
    );
  }

  /// Zeroes the in-memory vault key (best effort: Dart may have copied it).
  void lock() {
    _lockCount++;
    _replaceKey(null);
  }

  /// Adds or replaces the password slot.
  Future<void> setPassword(
    Uint8List password, {
    Argon2Params params = Argon2Params.defaults,
  }) async {
    final key = _keyCopy();
    try {
      if (password.isEmpty) {
        throw ArgumentError('must not be empty', 'password');
      }
      if (!params.isWithinBounds) {
        throw ArgumentError.value(params, 'params', 'out of bounds');
      }
      final salt = randomBytes(saltLength);
      final kek = await _kdf(password, salt, params);
      final SealedBox wrapped;
      try {
        wrapped = await sealBox(kek, key, _passwordSlotAad(params, salt));
      } finally {
        zeroBytes(kek);
      }
      await _store.writePasswordSlot(
        PasswordSlot(
          salt: salt,
          params: params,
          nonce: wrapped.nonce,
          wrappedKey: wrapped.ciphertext,
        ),
      );
      _hasPasswordSlot = true;
    } finally {
      zeroBytes(key);
    }
  }

  /// Re-wraps the vault key under a new password; records are untouched.
  Future<void> changePassword(
    Uint8List newPassword, {
    Argon2Params params = Argon2Params.defaults,
  }) async {
    _requireKey();
    if (!_hasPasswordSlot) {
      throw const VaultNoSlotException('no password slot');
    }
    await setPassword(newPassword, params: params);
  }

  /// Needs the key store to prove the biometric slot still opens this vault.
  Future<void> removePasswordSlot(VaultKeyStore keyStore) async {
    final key = _keyCopy();
    try {
      if (!_hasPasswordSlot) {
        throw const VaultNoSlotException('no password slot');
      }
      if (!_metadata.biometricSlotEnrolled) {
        throw const VaultNoSlotException('refusing to remove the last slot');
      }
      final stored = await keyStore.read();
      var diff = stored == null || stored.length != key.length ? 1 : 0;
      if (stored != null) {
        for (var i = 0; i < stored.length && i < key.length; i++) {
          diff |= stored[i] ^ key[i];
        }
        zeroBytes(stored);
      }
      if (diff != 0) {
        throw const VaultKeyInvalidatedException(
          'biometric slot does not open this vault',
        );
      }
    } finally {
      zeroBytes(key);
    }
    await _store.deletePasswordSlot();
    _hasPasswordSlot = false;
  }

  Future<void> enrollKeyStore(VaultKeyStore keyStore) async {
    final key = _keyCopy();
    try {
      await keyStore.write(key);
    } finally {
      zeroBytes(key);
    }
    await _setBiometricSlotEnrolled(true);
  }

  Future<void> removeKeyStoreSlot(VaultKeyStore keyStore) async {
    _requireKey();
    if (!_hasPasswordSlot) {
      throw const VaultNoSlotException('refusing to remove the last slot');
    }
    await keyStore.delete();
    await _setBiometricSlotEnrolled(false);
  }

  Future<String> put(VaultRecordKind kind, Uint8List plaintext) async {
    _requireKey();
    if (!_hasPasswordSlot && !_metadata.biometricSlotEnrolled) {
      throw const VaultNoSlotException('add a slot before storing records');
    }
    final id = randomId();
    await _sealRecord(id, kind, plaintext);
    return id;
  }

  /// Returns a fresh plaintext buffer; the caller should zero it when done.
  Future<Uint8List> get(String id) async => (await _openRecord(id)).$2;

  /// Keeps the record's kind, which must first authenticate; a tampered record is not overwritten.
  Future<void> replace(String id, Uint8List plaintext) async {
    final (record, old) = await _openRecord(id);
    zeroBytes(old);
    await _sealRecord(id, record.kind, plaintext);
  }

  Future<void> delete(String id) async {
    _requireKey();
    await _readRecord(id);
    await _store.deleteRecord(id);
  }

  Future<List<String>> recordIds() async {
    _requireKey();
    return _store.listRecordIds();
  }

  @override
  String toString() => 'Vault($id, ${state.name})';

  Uint8List _requireKey() => _key ?? (throw const VaultLockedException());

  // Each operation works on its own copy, so a concurrent lock() cannot zero a key in use.
  Uint8List _keyCopy() => Uint8List.fromList(_requireKey());

  void _replaceKey(Uint8List? key) {
    final old = _key;
    if (old != null) {
      zeroBytes(old);
    }
    _key = key;
  }

  // Takes ownership of key; a lock() issued while unlocking wins.
  Future<void> _adopt(
    Uint8List key,
    int lockCount,
    VaultException mismatch,
  ) async {
    final matches =
        key.length == vaultKeyLength &&
        await openBox(
              key,
              _metadata.keyCheckNonce,
              _metadata.keyCheck,
              keyCheckAad(
                formatVersion: _metadata.formatVersion,
                vaultId: _metadata.vaultId,
              ),
            ) !=
            null;
    if (!matches) {
      zeroBytes(key);
      throw mismatch;
    }
    if (lockCount != _lockCount) {
      zeroBytes(key);
      throw const VaultLockedException();
    }
    _replaceKey(key);
  }

  Future<void> _setBiometricSlotEnrolled(bool value) async {
    if (_metadata.biometricSlotEnrolled == value) {
      return;
    }
    final next = _metadata.copyWith(biometricSlotEnrolled: value);
    await _store.writeMetadata(next);
    _metadata = next;
  }

  Future<VaultRecord> _readRecord(String id) async {
    final record = await _store.readRecord(id);
    if (record == null) {
      throw VaultRecordNotFoundException(id);
    }
    if (record.id != id ||
        record.nonce.length != nonceLength ||
        record.ciphertext.length < tagLength) {
      throw VaultCorruptException('malformed record $id');
    }
    return record;
  }

  Future<(VaultRecord, Uint8List)> _openRecord(String id) async {
    final key = _keyCopy();
    try {
      final record = await _readRecord(id);
      final plaintext = await openBox(
        key,
        record.nonce,
        record.ciphertext,
        _recordAad(record.kind, id),
      );
      if (plaintext == null) {
        throw VaultCorruptException('record $id failed authentication');
      }
      return (record, plaintext);
    } finally {
      zeroBytes(key);
    }
  }

  Future<void> _sealRecord(
    String id,
    VaultRecordKind kind,
    Uint8List plaintext,
  ) async {
    final key = _keyCopy();
    try {
      final box = await sealBox(key, plaintext, _recordAad(kind, id));
      await _store.writeRecord(
        VaultRecord(
          id: id,
          kind: kind,
          nonce: box.nonce,
          ciphertext: box.ciphertext,
        ),
      );
    } finally {
      zeroBytes(key);
    }
  }

  Uint8List _recordAad(VaultRecordKind kind, String id) => recordAad(
    formatVersion: _metadata.formatVersion,
    vaultId: _metadata.vaultId,
    kind: kind,
    recordId: id,
  );

  Uint8List _passwordSlotAad(Argon2Params params, Uint8List salt) =>
      passwordSlotAad(
        formatVersion: _metadata.formatVersion,
        vaultId: _metadata.vaultId,
        params: params,
        salt: salt,
      );
}
