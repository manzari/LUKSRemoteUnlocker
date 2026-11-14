import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unlock_core/vault.dart';

import 'support.dart';

/// Fake KDF that ignores salt and params, so only the AAD can catch their tampering.
Future<Uint8List> _blindKdf(
  Uint8List password,
  Uint8List salt,
  Argon2Params params,
) async =>
    Uint8List.fromList(List.generate(32, (i) => password[i % password.length]));

void main() {
  late InMemoryVaultStore store;
  late Vault vault;

  setUp(() async {
    store = InMemoryVaultStore();
    vault = await newVault(store: store);
  });

  Future<void> tamperSlot({
    Uint8List? salt,
    Argon2Params? params,
    Uint8List? nonce,
    Uint8List? wrappedKey,
  }) async {
    final slot = (await store.readPasswordSlot())!;
    await store.writePasswordSlot(
      PasswordSlot(
        salt: salt ?? slot.salt,
        params: params ?? slot.params,
        nonce: nonce ?? slot.nonce,
        wrappedKey: wrappedKey ?? slot.wrappedKey,
      ),
    );
  }

  Matcher malformedNotWrongPassword() => isA<VaultCorruptException>().having(
    (e) => e is VaultWrongPasswordException,
    'is wrong password',
    isFalse,
  );

  group('password slot', () {
    test('unlocks a reopened vault', () async {
      final id = await vault.put(VaultRecordKind.passphrase, fakePassphrase());
      final reopened = await Vault.open(store, kdf: argon2idInline);
      expect(reopened.id, vault.id);
      expect(reopened.hasPasswordSlot, isTrue);
      await reopened.unlockWithPassword(fakePassword());
      expect(reopened.state, VaultState.unlocked);
      expect(await reopened.get(id), fakePassphrase());
    });

    test('wrong password fails and stays locked', () async {
      vault.lock();
      await expectLater(
        vault.unlockWithPassword(bytesOf('FAKE-wrong-password')),
        throwsA(isA<VaultWrongPasswordException>()),
      );
      expect(vault.isUnlocked, isFalse);
    });

    test('stores the params and a fresh salt and nonce each time', () async {
      final first = (await store.readPasswordSlot())!;
      expect(first.params, fastParams);
      expect(first.salt, hasLength(16));
      expect(first.nonce, hasLength(24));
      expect(first.wrappedKey, hasLength(48));
      await vault.setPassword(fakePassword(), params: fastParams);
      final second = (await store.readPasswordSlot())!;
      expect(second.salt, isNot(first.salt));
      expect(second.nonce, isNot(first.nonce));
      expect(second.wrappedKey, isNot(first.wrappedKey));
    });

    test('rejects an empty password and out-of-bounds params', () async {
      await expectLater(
        vault.setPassword(Uint8List(0), params: fastParams),
        throwsArgumentError,
      );
      await expectLater(
        vault.setPassword(
          fakePassword(),
          params: const Argon2Params(
            memoryKiB: 4,
            iterations: 1,
            parallelism: 1,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('default params are the OWASP minimum', () {
      const d = Argon2Params.defaults;
      expect([d.memoryKiB, d.iterations, d.parallelism], [19456, 2, 1]);
    });
  });

  group('password slot tampering', () {
    setUp(() => vault.lock());

    Future<void> expectWrongPassword() => expectLater(
      vault.unlockWithPassword(fakePassword()),
      throwsA(isA<VaultWrongPasswordException>()),
    );

    test('flipped wrappedKey byte', () async {
      await tamperSlot(
        wrappedKey: flipBit((await store.readPasswordSlot())!.wrappedKey, 3),
      );
      await expectWrongPassword();
    });

    test('flipped wrappedKey tag byte', () async {
      await tamperSlot(
        wrappedKey: flipBit((await store.readPasswordSlot())!.wrappedKey, 47),
      );
      await expectWrongPassword();
    });

    test('flipped nonce byte', () async {
      await tamperSlot(
        nonce: flipBit((await store.readPasswordSlot())!.nonce, 5),
      );
      await expectWrongPassword();
    });

    test('flipped salt byte', () async {
      await tamperSlot(salt: flipBit((await store.readPasswordSlot())!.salt));
      await expectWrongPassword();
    });

    for (final (name, params) in [
      (
        'memory',
        const Argon2Params(memoryKiB: 72, iterations: 1, parallelism: 1),
      ),
      (
        'iterations',
        const Argon2Params(memoryKiB: 64, iterations: 2, parallelism: 1),
      ),
      (
        'parallelism',
        const Argon2Params(memoryKiB: 64, iterations: 1, parallelism: 2),
      ),
    ]) {
      test('changed $name param', () async {
        await tamperSlot(params: params);
        await expectWrongPassword();
      });
    }

    test('salt and params are bound by the AAD, not only by the KDF', () async {
      final blindStore = InMemoryVaultStore();
      final blind = await Vault.create(blindStore, kdf: _blindKdf);
      await blind.setPassword(fakePassword(), params: fastParams);
      blind.lock();
      final slot = (await blindStore.readPasswordSlot())!;
      for (final tampered in [
        PasswordSlot(
          salt: flipBit(slot.salt),
          params: slot.params,
          nonce: slot.nonce,
          wrappedKey: slot.wrappedKey,
        ),
        PasswordSlot(
          salt: slot.salt,
          params: const Argon2Params(
            memoryKiB: 64,
            iterations: 2,
            parallelism: 1,
          ),
          nonce: slot.nonce,
          wrappedKey: slot.wrappedKey,
        ),
      ]) {
        await blindStore.writePasswordSlot(tampered);
        await expectLater(
          blind.unlockWithPassword(fakePassword()),
          throwsA(isA<VaultWrongPasswordException>()),
        );
      }
      await blindStore.writePasswordSlot(slot);
      await blind.unlockWithPassword(fakePassword());
    });

    test('out-of-bounds params are rejected before running the KDF', () async {
      var kdfCalls = 0;
      final counted = await Vault.open(
        store,
        kdf: (p, s, params) {
          kdfCalls++;
          return argon2idInline(p, s, params);
        },
      );
      for (final params in const [
        Argon2Params(memoryKiB: 1 << 30, iterations: 1, parallelism: 1),
        Argon2Params(memoryKiB: 64, iterations: 100000, parallelism: 1),
        Argon2Params(memoryKiB: 64, iterations: 1, parallelism: 0),
        Argon2Params(memoryKiB: 8, iterations: 1, parallelism: 4),
      ]) {
        await tamperSlot(params: params);
        await expectLater(
          counted.unlockWithPassword(fakePassword()),
          throwsA(malformedNotWrongPassword()),
        );
      }
      expect(kdfCalls, 0);
    });

    test('wrong field lengths are malformed', () async {
      final slot = (await store.readPasswordSlot())!;
      await tamperSlot(salt: Uint8List(8));
      await expectLater(
        vault.unlockWithPassword(fakePassword()),
        throwsA(malformedNotWrongPassword()),
      );
      await store.writePasswordSlot(slot);
      await tamperSlot(wrappedKey: slot.wrappedKey.sublist(0, 47));
      await expectLater(
        vault.unlockWithPassword(fakePassword()),
        throwsA(malformedNotWrongPassword()),
      );
    });

    test('slot from another vault fails', () async {
      final otherStore = InMemoryVaultStore();
      await newVault(store: otherStore);
      await store.writePasswordSlot((await otherStore.readPasswordSlot())!);
      await expectWrongPassword();
    });
  });

  group('change password', () {
    test(
      're-wraps only: records untouched, old password stops working',
      () async {
        final ids = [
          await vault.put(VaultRecordKind.passphrase, fakePassphrase()),
          await vault.put(VaultRecordKind.sshKey, fakeSshKey()),
        ];
        final before = {
          for (final id in ids) id: (await store.readRecord(id))!.ciphertext,
        };
        final newPassword = bytesOf('FAKE-new-test-password');
        await vault.changePassword(newPassword, params: fastParams);
        for (final id in ids) {
          expect((await store.readRecord(id))!.ciphertext, before[id]);
        }
        vault.lock();
        await expectLater(
          vault.unlockWithPassword(fakePassword()),
          throwsA(isA<VaultWrongPasswordException>()),
        );
        await vault.unlockWithPassword(newPassword);
        expect(await vault.get(ids[0]), fakePassphrase());
        expect(await vault.get(ids[1]), fakeSshKey());
      },
    );

    test('requires an existing password slot', () async {
      final bare = await Vault.create(
        InMemoryVaultStore(),
        kdf: argon2idInline,
      );
      await expectLater(
        bare.changePassword(fakePassword(), params: fastParams),
        throwsA(isA<VaultNoSlotException>()),
      );
    });
  });

  group('biometric slot', () {
    late InMemoryVaultKeyStore keyStore;

    setUp(() => keyStore = InMemoryVaultKeyStore());

    test('never enrolled is distinguishable from invalidated', () async {
      expect(vault.biometricSlotEnrolled, isFalse);
      vault.lock();
      await expectLater(
        vault.unlockWithKeyStore(keyStore),
        throwsA(isA<VaultNoSlotException>()),
      );
      expect(keyStore.readCount, 0);
    });

    test('enroll, then unlock with one read and no password', () async {
      final id = await vault.put(VaultRecordKind.sshKey, fakeSshKey());
      await vault.enrollKeyStore(keyStore);
      expect(vault.biometricSlotEnrolled, isTrue);
      final reopened = await Vault.open(store, kdf: argon2idInline);
      expect(reopened.biometricSlotEnrolled, isTrue);
      await reopened.unlockWithKeyStore(keyStore);
      expect(keyStore.readCount, 1);
      expect(await reopened.get(id), fakeSshKey());
    });

    test('recovery: invalidated -> password -> re-enroll -> works', () async {
      final id = await vault.put(VaultRecordKind.passphrase, fakePassphrase());
      await vault.enrollKeyStore(keyStore);
      vault.lock();

      keyStore.invalidate();
      await expectLater(
        vault.unlockWithKeyStore(keyStore),
        throwsA(isA<VaultKeyInvalidatedException>()),
      );
      expect(vault.isUnlocked, isFalse);
      expect(vault.biometricSlotEnrolled, isTrue);

      await vault.unlockWithPassword(fakePassword());
      await vault.enrollKeyStore(keyStore);
      vault.lock();

      await vault.unlockWithKeyStore(keyStore);
      expect(await vault.get(id), fakePassphrase());
    });

    test('an emptied key store counts as invalidated', () async {
      await vault.enrollKeyStore(keyStore);
      vault.lock();
      await keyStore.delete();
      await expectLater(
        vault.unlockWithKeyStore(keyStore),
        throwsA(isA<VaultKeyInvalidatedException>()),
      );
    });

    test('a key store holding a foreign key counts as invalidated', () async {
      await vault.enrollKeyStore(keyStore);
      vault.lock();
      final other = await newVault();
      await other.enrollKeyStore(keyStore);
      await expectLater(
        vault.unlockWithKeyStore(keyStore),
        throwsA(isA<VaultKeyInvalidatedException>()),
      );
      expect(vault.isUnlocked, isFalse);
    });

    test('cancel and lockout surface as unavailable', () async {
      await vault.enrollKeyStore(keyStore);
      vault.lock();
      for (final reason in VaultKeyUnavailableReason.values) {
        keyStore.unavailable = reason;
        await expectLater(
          vault.unlockWithKeyStore(keyStore),
          throwsA(
            isA<VaultKeyUnavailableException>().having(
              (e) => e.reason,
              'reason',
              reason,
            ),
          ),
        );
      }
      expect(vault.isUnlocked, isFalse);
    });

    test('removing the slot deletes the key and clears the flag', () async {
      await vault.enrollKeyStore(keyStore);
      await vault.removeKeyStoreSlot(keyStore);
      expect(keyStore.hasKey, isFalse);
      expect(vault.biometricSlotEnrolled, isFalse);
      expect((await store.readMetadata())!.biometricSlotEnrolled, isFalse);
    });
  });

  group('last slot', () {
    test('password slot cannot be removed without a biometric slot', () async {
      await expectLater(
        vault.removePasswordSlot(InMemoryVaultKeyStore()),
        throwsA(isA<VaultNoSlotException>()),
      );
      expect(vault.hasPasswordSlot, isTrue);
      expect(await store.readPasswordSlot(), isNotNull);
    });

    test(
      'password slot stays when the biometric slot is invalidated',
      () async {
        final keyStore = InMemoryVaultKeyStore();
        await vault.enrollKeyStore(keyStore);
        keyStore.invalidate();
        await expectLater(
          vault.removePasswordSlot(keyStore),
          throwsA(isA<VaultKeyInvalidatedException>()),
        );
        expect(await store.readPasswordSlot(), isNotNull);
      },
    );

    test('biometric slot cannot be removed without a password slot', () async {
      final keyStore = InMemoryVaultKeyStore();
      await vault.enrollKeyStore(keyStore);
      await vault.removePasswordSlot(keyStore);
      expect(vault.hasPasswordSlot, isFalse);
      await expectLater(
        vault.removeKeyStoreSlot(keyStore),
        throwsA(isA<VaultNoSlotException>()),
      );
      expect(keyStore.hasKey, isTrue);

      vault.lock();
      await expectLater(
        vault.unlockWithPassword(fakePassword()),
        throwsA(isA<VaultNoSlotException>()),
      );
      await vault.unlockWithKeyStore(keyStore);
      expect(vault.isUnlocked, isTrue);
    });
  });

  group('lifecycle', () {
    test('create refuses a store that already holds vault data', () async {
      await expectLater(
        Vault.create(store, kdf: argon2idInline),
        throwsA(isA<VaultAlreadyExistsException>()),
      );
      final leftover = InMemoryVaultStore();
      await leftover.writePasswordSlot((await store.readPasswordSlot())!);
      await expectLater(
        Vault.create(leftover, kdf: argon2idInline),
        throwsA(isA<VaultAlreadyExistsException>()),
      );
    });

    test('open needs an initialized store', () async {
      expect(await Vault.exists(InMemoryVaultStore()), isFalse);
      expect(await Vault.exists(store), isTrue);
      await expectLater(
        Vault.open(InMemoryVaultStore()),
        throwsA(isA<VaultNotInitializedException>()),
      );
    });

    test('unsupported format version is refused', () async {
      final metadata = (await store.readMetadata())!;
      await store.writeMetadata(
        VaultMetadata(
          formatVersion: 2,
          vaultId: metadata.vaultId,
          keyCheckNonce: metadata.keyCheckNonce,
          keyCheck: metadata.keyCheck,
          biometricSlotEnrolled: false,
        ),
      );
      await expectLater(
        Vault.open(store),
        throwsA(
          isA<VaultUnsupportedVersionException>().having(
            (e) => e.version,
            'version',
            2,
          ),
        ),
      );
    });

    test('tampered key check makes every slot fail', () async {
      final metadata = (await store.readMetadata())!;
      await store.writeMetadata(
        VaultMetadata(
          formatVersion: metadata.formatVersion,
          vaultId: metadata.vaultId,
          keyCheckNonce: metadata.keyCheckNonce,
          keyCheck: flipBit(metadata.keyCheck),
          biometricSlotEnrolled: metadata.biometricSlotEnrolled,
        ),
      );
      final reopened = await Vault.open(store, kdf: argon2idInline);
      await expectLater(
        reopened.unlockWithPassword(fakePassword()),
        throwsA(malformedNotWrongPassword()),
      );
    });
  });

  test('errors and toString never carry secret bytes', () async {
    final keyStore = InMemoryVaultKeyStore();
    await vault.enrollKeyStore(keyStore);
    final id = await vault.put(VaultRecordKind.passphrase, fakePassphrase());
    final record = (await store.readRecord(id))!;
    final slot = (await store.readPasswordSlot())!;
    final key = (await keyStore.read())!;
    final texts = <String>[
      vault.toString(),
      record.toString(),
      slot.toString(),
      (await store.readMetadata())!.toString(),
    ];
    vault.lock();
    try {
      await vault.unlockWithPassword(bytesOf('FAKE-wrong-password'));
    } on VaultException catch (e) {
      texts.add(e.toString());
    }
    await vault.unlockWithPassword(fakePassword());
    await store.writeRecord(
      VaultRecord(
        id: id,
        kind: record.kind,
        nonce: record.nonce,
        ciphertext: flipBit(record.ciphertext),
      ),
    );
    try {
      await vault.get(id);
    } on VaultException catch (e) {
      texts.add(e.toString());
    }
    expect(texts, hasLength(6));
    final joined = bytesOf(texts.join('\n'));
    for (final (what, secret) in [
      ('password', bytesOf('FAKE-wrong-password')),
      ('password', fakePassword()),
      ('passphrase', fakePassphrase()),
      ('vault key', key),
      ('wrapped key', slot.wrappedKey),
      ('ciphertext', record.ciphertext),
    ]) {
      expectNoLeak(joined, secret, what);
    }
    expect(texts.join(), isNot(contains(base64.encode(slot.salt))));
  });
}
