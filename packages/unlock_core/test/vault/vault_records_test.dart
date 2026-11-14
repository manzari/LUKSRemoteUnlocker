import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unlock_core/vault.dart';

import 'support.dart';

void main() {
  late InMemoryVaultStore store;
  late Vault vault;

  setUp(() async {
    store = InMemoryVaultStore();
    vault = await newVault(store: store);
  });

  Future<void> tamper(
    String id, {
    String? newId,
    VaultRecordKind? kind,
    Uint8List? nonce,
    Uint8List? ciphertext,
  }) async {
    final record = (await store.readRecord(id))!;
    await store.writeRecord(
      VaultRecord(
        id: newId ?? record.id,
        kind: kind ?? record.kind,
        nonce: nonce ?? record.nonce,
        ciphertext: ciphertext ?? record.ciphertext,
      ),
    );
  }

  Matcher corruptButNotWrongPassword() => isA<VaultCorruptException>().having(
    (e) => e is VaultWrongPasswordException,
    'is wrong password',
    isFalse,
  );

  group('round trip', () {
    final payloads = <String, Uint8List Function()>{
      'small': fakePassphrase,
      'empty': () => Uint8List(0),
      '1 MiB': () => patternBytes(1 << 20),
    };
    for (final kind in VaultRecordKind.values) {
      for (final MapEntry(key: name, value: payload) in payloads.entries) {
        test('${kind.wireName}, $name payload', () async {
          final id = await vault.put(kind, payload());
          expect(await vault.get(id), payload());
          expect((await store.readRecord(id))!.kind, kind);
          expect(
            (await store.readRecord(id))!.ciphertext.length,
            payload().length + 16,
          );
        });
      }
    }

    test('ssh key survives lock and password unlock', () async {
      final id = await vault.put(VaultRecordKind.sshKey, fakeSshKey());
      vault.lock();
      await vault.unlockWithPassword(fakePassword());
      expect(await vault.get(id), fakeSshKey());
    });

    test('get returns a fresh buffer each time', () async {
      final id = await vault.put(VaultRecordKind.passphrase, fakePassphrase());
      final first = await vault.get(id);
      first.fillRange(0, first.length, 0);
      expect(await vault.get(id), fakePassphrase());
    });

    test('put does not modify the caller plaintext', () async {
      final plaintext = fakePassphrase();
      await vault.put(VaultRecordKind.passphrase, plaintext);
      expect(plaintext, fakePassphrase());
    });
  });

  group('replace and delete', () {
    test('replace keeps id and kind with a fresh nonce', () async {
      final id = await vault.put(VaultRecordKind.sshKey, fakeSshKey());
      final before = (await store.readRecord(id))!;
      await vault.replace(id, bytesOf('FAKE-replacement-key'));
      final after = (await store.readRecord(id))!;
      expect(after.kind, VaultRecordKind.sshKey);
      expect(after.nonce, isNot(before.nonce));
      expect(await vault.get(id), bytesOf('FAKE-replacement-key'));
    });

    test('delete removes the record', () async {
      final id = await vault.put(VaultRecordKind.passphrase, fakePassphrase());
      expect(await vault.recordIds(), [id]);
      await vault.delete(id);
      expect(await vault.recordIds(), isEmpty);
      await expectLater(
        vault.get(id),
        throwsA(isA<VaultRecordNotFoundException>()),
      );
    });

    test('unknown ids are not found', () async {
      const id = '00000000000000000000000000000000';
      for (final op in [
        () => vault.get(id),
        () => vault.replace(id, fakePassphrase()),
        () => vault.delete(id),
      ]) {
        await expectLater(op(), throwsA(isA<VaultRecordNotFoundException>()));
      }
    });
  });

  group('tampering', () {
    late String id;

    setUp(() async {
      id = await vault.put(VaultRecordKind.passphrase, fakePassphrase());
    });

    test('flipped ciphertext byte fails', () async {
      await tamper(
        id,
        ciphertext: flipBit((await store.readRecord(id))!.ciphertext),
      );
      await expectLater(vault.get(id), throwsA(corruptButNotWrongPassword()));
    });

    test('flipped tag byte fails', () async {
      final ct = (await store.readRecord(id))!.ciphertext;
      await tamper(id, ciphertext: flipBit(ct, ct.length - 1));
      await expectLater(vault.get(id), throwsA(corruptButNotWrongPassword()));
    });

    test('flipped nonce byte fails', () async {
      await tamper(id, nonce: flipBit((await store.readRecord(id))!.nonce, 23));
      await expectLater(vault.get(id), throwsA(corruptButNotWrongPassword()));
    });

    test('changed kind fails (kind is in the AAD)', () async {
      await tamper(id, kind: VaultRecordKind.sshKey);
      await expectLater(vault.get(id), throwsA(corruptButNotWrongPassword()));
    });

    test('truncated ciphertext and short nonce fail', () async {
      await tamper(id, ciphertext: Uint8List(15));
      await expectLater(vault.get(id), throwsA(corruptButNotWrongPassword()));
      await tamper(id, nonce: Uint8List(12));
      await expectLater(vault.get(id), throwsA(corruptButNotWrongPassword()));
    });

    test('swapping two records ciphertexts fails (id is in the AAD)', () async {
      final other = await vault.put(
        VaultRecordKind.passphrase,
        bytesOf('FAKE-other-passphrase'),
      );
      final a = (await store.readRecord(id))!;
      final b = (await store.readRecord(other))!;
      await tamper(id, nonce: b.nonce, ciphertext: b.ciphertext);
      await tamper(other, nonce: a.nonce, ciphertext: a.ciphertext);
      await expectLater(vault.get(id), throwsA(corruptButNotWrongPassword()));
      await expectLater(
        vault.get(other),
        throwsA(corruptButNotWrongPassword()),
      );
    });

    test('moving a record to another id fails', () async {
      const newId = 'ffffffffffffffffffffffffffffffff';
      await tamper(id, newId: newId);
      await expectLater(
        vault.get(newId),
        throwsA(corruptButNotWrongPassword()),
      );
    });

    test('record from another vault fails', () async {
      final otherStore = InMemoryVaultStore();
      final otherVault = await newVault(store: otherStore);
      final foreignId = await otherVault.put(
        VaultRecordKind.passphrase,
        fakePassphrase(),
      );
      await store.writeRecord((await otherStore.readRecord(foreignId))!);
      await expectLater(
        vault.get(foreignId),
        throwsA(corruptButNotWrongPassword()),
      );
    });
  });

  group('nonces', () {
    test('are unique across many writes of the same plaintext', () async {
      final nonces = <String>{};
      final ciphertexts = <String>{};
      for (var i = 0; i < 500; i++) {
        final id = await vault.put(
          VaultRecordKind.passphrase,
          fakePassphrase(),
        );
        final record = (await store.readRecord(id))!;
        nonces.add(record.nonce.join(','));
        ciphertexts.add(record.ciphertext.join(','));
      }
      final id = (await vault.recordIds()).first;
      for (var i = 0; i < 200; i++) {
        await vault.replace(id, fakePassphrase());
        nonces.add((await store.readRecord(id))!.nonce.join(','));
      }
      expect(nonces, hasLength(700));
      expect(ciphertexts, hasLength(500));
    });

    test('record ids are unique', () async {
      final ids = <String>{};
      for (var i = 0; i < 200; i++) {
        ids.add(await vault.put(VaultRecordKind.sshKey, fakeSshKey()));
      }
      expect(ids, hasLength(200));
      expect(ids.every(RegExp(r'^[0-9a-f]{32}$').hasMatch), isTrue);
    });
  });

  group('locked', () {
    late String id;

    setUp(() async {
      id = await vault.put(VaultRecordKind.passphrase, fakePassphrase());
      vault.lock();
    });

    test('state reports locked', () {
      expect(vault.state, VaultState.locked);
      expect(vault.isUnlocked, isFalse);
    });

    test('every key-dependent operation throws', () async {
      final ks = InMemoryVaultKeyStore();
      final ops = <String, Future<Object?> Function()>{
        'put': () => vault.put(VaultRecordKind.passphrase, fakePassphrase()),
        'get': () => vault.get(id),
        'replace': () => vault.replace(id, fakePassphrase()),
        'delete': () => vault.delete(id),
        'recordIds': vault.recordIds,
        'setPassword': () =>
            vault.setPassword(fakePassword(), params: fastParams),
        'changePassword': () =>
            vault.changePassword(fakePassword(), params: fastParams),
        'removePasswordSlot': () => vault.removePasswordSlot(ks),
        'enrollKeyStore': () => vault.enrollKeyStore(ks),
        'removeKeyStoreSlot': () => vault.removeKeyStoreSlot(ks),
      };
      for (final MapEntry(key: name, value: op) in ops.entries) {
        await expectLater(
          op(),
          throwsA(isA<VaultLockedException>()),
          reason: name,
        );
      }
      expect(ks.hasKey, isFalse);
      expect(await store.readRecord(id), isNotNull);
    });

    test('a freshly opened vault is locked', () async {
      final reopened = await Vault.open(store, kdf: argon2idInline);
      expect(reopened.state, VaultState.locked);
      await expectLater(reopened.get(id), throwsA(isA<VaultLockedException>()));
    });

    test('lock during an unlock wins', () async {
      final pending = vault.unlockWithPassword(fakePassword());
      vault.lock();
      await expectLater(pending, throwsA(isA<VaultLockedException>()));
      expect(vault.isUnlocked, isFalse);
    });

    test('lock during a put still encrypts under the real key', () async {
      await vault.unlockWithPassword(fakePassword());
      final pending = vault.put(VaultRecordKind.sshKey, fakeSshKey());
      vault.lock();
      final newId = await pending;
      await vault.unlockWithPassword(fakePassword());
      expect(await vault.get(newId), fakeSshKey());
    });
  });

  test('put is refused while the vault has no slot', () async {
    final bare = await Vault.create(InMemoryVaultStore(), kdf: argon2idInline);
    await expectLater(
      bare.put(VaultRecordKind.passphrase, fakePassphrase()),
      throwsA(isA<VaultNoSlotException>()),
    );
  });
}
