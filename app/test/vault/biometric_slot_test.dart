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

  int deletes = 0;

  @override
  Future<bool?> delete(String name, PromptInfo promptInfo) async {
    deletes++;
    return values.remove(name) != null;
  }

  @override
  Future<void> write(String name, String content, PromptInfo promptInfo) async {
    _maybeThrow();
    values[name] = content;
  }
}

const strict = BiometricStoreRef(allowDeviceCredential: false);

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
    final store = slot.keyStore(strict);
    final key = Uint8List.fromList(List.generate(32, (i) => i));
    await store.write(key);
    final stored = plugin.values['luks_vault_key_biometric']!;
    expect(base64.decode(stored), key);
    expect(await store.read(), key);
    await store.delete();
    expect(await store.read(), isNull);
  });

  test(
    'each PIN-fallback option has two stores with matching options',
    () async {
      for (final ref in BiometricStoreRef.all) {
        await slot.keyStore(ref).write(Uint8List(32));
      }
      expect(plugin.values.keys, {
        'luks_vault_key_biometric',
        'luks_vault_key_biometric_b',
        'luks_vault_key_with_credential',
        'luks_vault_key_with_credential_b',
      });
      for (final name in [
        'luks_vault_key_biometric',
        'luks_vault_key_biometric_b',
      ]) {
        final o = plugin.options[name]!;
        expect(o.androidBiometricOnly, isTrue);
        expect(o.darwinBiometricOnly, isTrue);
        expect(o.androidAuthenticationValidityDuration, isNull);
      }
      for (final name in [
        'luks_vault_key_with_credential',
        'luks_vault_key_with_credential_b',
      ]) {
        final o = plugin.options[name]!;
        expect(o.androidBiometricOnly, isFalse);
        expect(o.darwinBiometricOnly, isFalse);
        expect(o.androidAuthenticationValidityDuration, isNotNull);
      }

      await slot.deleteAll();
      expect(plugin.values, isEmpty);
    },
  );

  test('a write overwrites in place; a cancelled or failed write keeps the '
      'stored key', () async {
    final store = slot.keyStore(strict);
    final old = Uint8List.fromList(List.filled(32, 1));
    await store.write(old);
    for (final error in <BiometricVaultException>[
      const AuthException(AuthExceptionCode.userCanceled, 'x'),
      const BiometricVaultPluginException('E', 'x', null),
    ]) {
      plugin.nextError = error;
      await expectLater(
        store.write(Uint8List(32)),
        throwsA(isA<VaultKeyUnavailableException>()),
      );
      expect(await store.read(), old);
    }
    expect(plugin.deletes, 0);
    await store.write(Uint8List(32));
    expect(await store.read(), Uint8List(32));
    expect(plugin.deletes, 0);
  });

  test('platform errors map to the core vault exceptions', () async {
    final store = slot.keyStore(strict);
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
    final store = slot.keyStore(strict);
    await vault.enrollKeyStore(store);
    final id = await vault.put(VaultRecordKind.passphrase, bytesOf('FAKE-p'));
    vault.lock();
    await vault.unlockWithKeyStore(store);
    expect(await vault.get(id), bytesOf('FAKE-p'));
  });
}
