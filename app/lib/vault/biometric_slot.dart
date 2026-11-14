import 'dart:convert';

import 'package:biometric_vault/biometric_vault.dart';
import 'package:flutter/foundation.dart';
import 'package:unlock_core/vault.dart';

/// Where the biometric vault slot lives on this platform.
abstract interface class BiometricSlotPlatform {
  /// Whether a biometric slot can be offered right now (hardware present and enrolled).
  Future<bool> isAvailable();

  /// The key store for the given fallback option; each option is its own store.
  VaultKeyStore keyStore({required bool allowDeviceCredential});

  Future<void> deleteAll();
}

/// Platforms without a biometric gate (Linux, Windows): password slot only.
final class NoBiometricSlot implements BiometricSlotPlatform {
  const NoBiometricSlot();

  @override
  Future<bool> isAvailable() async => false;

  @override
  VaultKeyStore keyStore({required bool allowDeviceCredential}) =>
      throw UnsupportedError('No biometric slot on this platform');

  @override
  Future<void> deleteAll() async {}
}

/// biometric_vault on Android and iOS; anything else falls back to [NoBiometricSlot] behaviour.
final class BiometricVaultSlot implements BiometricSlotPlatform {
  BiometricVaultSlot([this._plugin]);

  final BiometricVault? _plugin;
  final Map<bool, BiometricVaultKeyStore> _stores = {};

  BiometricVault get _vault => _plugin ?? BiometricVault();

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> isAvailable() async {
    if (!_supported) return false;
    try {
      return await _vault.canAuthenticate() == CanAuthenticateResponse.success;
    } on Object {
      return false;
    }
  }

  @override
  VaultKeyStore keyStore({required bool allowDeviceCredential}) =>
      _stores[allowDeviceCredential] ??= BiometricVaultKeyStore(
        _vault,
        allowDeviceCredential: allowDeviceCredential,
      );

  @override
  Future<void> deleteAll() async {
    if (!_supported) return;
    for (final allow in [false, true]) {
      await keyStore(allowDeviceCredential: allow).delete();
    }
  }
}

/// [VaultKeyStore] holding the vault key as base64 in one biometric_vault store.
final class BiometricVaultKeyStore implements VaultKeyStore {
  BiometricVaultKeyStore(this._plugin, {required this.allowDeviceCredential});

  final BiometricVault _plugin;
  final bool allowDeviceCredential;
  BiometricVaultFile? _file;

  String get storeName => allowDeviceCredential
      ? 'luks_vault_key_with_credential'
      : 'luks_vault_key_biometric';

  StorageFileInitOptions get options => allowDeviceCredential
      ? const StorageFileInitOptions(
          androidBiometricOnly: false,
          androidAuthenticationValidityDuration: Duration(seconds: 10),
          darwinBiometricOnly: false,
        )
      : const StorageFileInitOptions();

  static const _prompt = PromptInfo(
    androidPromptInfo: AndroidPromptInfo(
      title: 'Unlock the vault',
      subtitle: 'LUKS Remote Unlocker',
    ),
    iosPromptInfo: DarwinPromptInfo(
      saveTitle: 'Protect the vault key',
      accessTitle: 'Unlock the vault',
    ),
  );

  Future<BiometricVaultFile> _open() async => _file ??= await _plugin
      .getStorage(storeName, options: options, promptInfo: _prompt);

  @override
  Future<Uint8List?> read() => _mapped(() async {
    final text = await (await _open()).read();
    if (text == null) return null;
    try {
      return base64.decode(text);
    } on FormatException {
      throw const VaultKeyInvalidatedException('biometric slot is damaged');
    }
  });

  /// Deletes first, so a store invalidated by a new enrollment gets a fresh platform key.
  @override
  Future<void> write(Uint8List key) => _mapped(() async {
    final file = await _open();
    await file.delete();
    await file.write(base64.encode(key));
  });

  @override
  Future<void> delete() => _mapped(() async => (await _open()).delete());

  static Future<T> _mapped<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on BiometricVaultException catch (e) {
      throw mapError(e);
    }
  }

  @visibleForTesting
  static VaultException mapError(BiometricVaultException e) => switch (e) {
    StorageInvalidatedException() => const VaultKeyInvalidatedException(),
    AuthException(
      code: AuthExceptionCode.userCanceled ||
          AuthExceptionCode.canceled ||
          AuthExceptionCode.timeout,
    ) =>
      VaultKeyUnavailableException(VaultKeyUnavailableReason.userCancelled),
    AuthException(
      code: AuthExceptionCode.lockedOut ||
          AuthExceptionCode.lockedOutPermanently,
    ) =>
      VaultKeyUnavailableException(VaultKeyUnavailableReason.lockedOut),
    AuthException() || BiometricVaultPluginException() =>
      VaultKeyUnavailableException(VaultKeyUnavailableReason.unavailable),
  };
}
