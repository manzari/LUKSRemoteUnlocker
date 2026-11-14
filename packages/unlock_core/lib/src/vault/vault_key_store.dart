import 'dart:typed_data';

import 'vault_exceptions.dart';

/// Biometric slot adapter holding only the vault key. [read] may prompt; returns a buffer the caller owns, null if empty.
/// Throws [VaultKeyInvalidatedException] or [VaultKeyUnavailableException]. [write] must copy what it keeps.
abstract interface class VaultKeyStore {
  Future<Uint8List?> read();
  Future<void> write(Uint8List key);
  Future<void> delete();
}

/// Test double; [invalidate] simulates a new fingerprint or face enrollment.
final class InMemoryVaultKeyStore implements VaultKeyStore {
  Uint8List? _key;
  bool _invalidated = false;

  /// When set, [read] throws [VaultKeyUnavailableException] with this reason.
  VaultKeyUnavailableReason? unavailable;
  int readCount = 0;

  bool get hasKey => _key != null;

  void invalidate() => _invalidated = true;

  @override
  Future<Uint8List?> read() async {
    readCount++;
    final reason = unavailable;
    if (reason != null) {
      throw VaultKeyUnavailableException(reason);
    }
    if (_invalidated) {
      throw const VaultKeyInvalidatedException();
    }
    final key = _key;
    return key == null ? null : Uint8List.fromList(key);
  }

  @override
  Future<void> write(Uint8List key) async {
    _clear();
    _key = Uint8List.fromList(key);
  }

  @override
  Future<void> delete() async => _clear();

  void _clear() {
    final key = _key;
    key?.fillRange(0, key.length, 0);
    _key = null;
    _invalidated = false;
  }
}
