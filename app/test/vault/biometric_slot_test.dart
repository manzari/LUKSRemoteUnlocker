import 'dart:convert';

import 'package:biometric_vault/biometric_vault.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/vault/biometric_slot.dart';
import 'package:unlock_core/vault.dart';

import '../support/harness.dart';

final class _FakePlugin extends BiometricVault {
  _FakePlugin() : super.create();

  CanAuthenticateResponse can = CanAuthenticateResponse.success;
  int canCalls = 0;
  final values = <String, String>{};
  final options = <String, StorageFileInitOptions?>{};
  BiometricVaultException? nextError;

  void _maybeThrow() {
    final e = nextError;
    nextError = null;
    if (e != null) throw e;
  }

  @override
  Future<CanAuthenticateResponse> canAuthenticate({
    StorageFileInitOptions? options,
  }) async {
    canCalls++;
    return can;
  }

  @override
  Future<bool> linuxCheckAppArmorError() async => false;

  @override
  Future<BiometricVaultFile> getStorage(
    String name, {
    StorageFileInitOptions? options,
    bool forceInit = false,
    PromptInfo promptInfo = PromptInfo.defaultValues,
  }) async {
    this.options[name] = options;
    return BiometricVaultFile(this, name, promptInfo);
  }

  @override
  Future<String?> read(String name, PromptInfo promptInfo) async {
    _maybeThrow();
    return values[name];
  }

  @override
  Future<bool?> delete(String name, PromptInfo promptInfo) async =>
      values.remove(name) != null;

  @override
  Future<void> write(String name, String content, PromptInfo promptInfo) async {
    _maybeThrow();
    values[name] = content;
  }
}

void main() {
  late _FakePlugin plugin;
  late BiometricVaultSlot slot;

  setUp(() {
    plugin = _FakePlugin();
    slot = BiometricVaultSlot(plugin);
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('offered on Android only when biometrics are enrolled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await slot.isAvailable(), isTrue);
    plugin.can = CanAuthenticateResponse.errorNoBiometricEnrolled;
    expect(await slot.isAvailable(), isFalse);
  });

  test('never offered on Linux, without asking the plugin', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(await slot.isAvailable(), isFalse);
    expect(plugin.canCalls, 0);
  });

  test('stores the vault key as base64 and reads it back', () async {
    final store = slot.keyStore(allowDeviceCredential: false);
    final key = Uint8List.fromList(List.generate(32, (i) => i));
    await store.write(key);
    final stored = plugin.values['luks_vault_key_biometric']!;
    expect(base64.decode(stored), key);
    expect(await store.read(), key);
    await store.delete();
    expect(await store.read(), isNull);
  });

  test(
    'each PIN-fallback option is its own store with matching options',
    () async {
      await slot.keyStore(allowDeviceCredential: false).write(Uint8List(32));
      await slot.keyStore(allowDeviceCredential: true).write(Uint8List(32));
      final strict = plugin.options['luks_vault_key_biometric']!;
      expect(strict.androidBiometricOnly, isTrue);
      expect(strict.darwinBiometricOnly, isTrue);
      expect(strict.androidAuthenticationValidityDuration, isNull);
      final lenient = plugin.options['luks_vault_key_with_credential']!;
      expect(lenient.androidBiometricOnly, isFalse);
      expect(lenient.darwinBiometricOnly, isFalse);
      expect(lenient.androidAuthenticationValidityDuration, isNotNull);

      await slot.deleteAll();
      expect(plugin.values, isEmpty);
    },
  );

  test('platform errors map to the core vault exceptions', () async {
    final store = slot.keyStore(allowDeviceCredential: false);
    Future<Object?> readError(BiometricVaultException e) async {
      plugin.nextError = e;
      try {
        await store.read();
        return null;
      } on Object catch (e) {
        return e;
      }
    }

    expect(
      await readError(
        const StorageInvalidatedException(
          StorageInvalidatedReason.keyInvalidated,
          'x',
        ),
      ),
      isA<VaultKeyInvalidatedException>(),
    );
    for (final (code, reason) in [
      (AuthExceptionCode.userCanceled, VaultKeyUnavailableReason.userCancelled),
      (AuthExceptionCode.canceled, VaultKeyUnavailableReason.userCancelled),
      (AuthExceptionCode.lockedOut, VaultKeyUnavailableReason.lockedOut),
      (
        AuthExceptionCode.lockedOutPermanently,
        VaultKeyUnavailableReason.lockedOut,
      ),
      (AuthExceptionCode.failedToStart, VaultKeyUnavailableReason.unavailable),
    ]) {
      expect(
        await readError(AuthException(code, 'x')),
        isA<VaultKeyUnavailableException>().having(
          (e) => e.reason,
          '$code',
          reason,
        ),
      );
    }
    expect(
      await readError(const BiometricVaultPluginException('E', 'x', null)),
      isA<VaultKeyUnavailableException>(),
    );
  });

  test('works as the vault biometric slot end to end', () async {
    final vault = await Vault.create(MemoryVaultStore(), kdf: fakeKdf);
    final store = slot.keyStore(allowDeviceCredential: false);
    await vault.enrollKeyStore(store);
    final id = await vault.put(VaultRecordKind.passphrase, bytesOf('FAKE-p'));
    vault.lock();
    await vault.unlockWithKeyStore(store);
    expect(await vault.get(id), bytesOf('FAKE-p'));
  });
}
