import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unlock_core/src/vault/vault_crypto.dart';
import 'package:unlock_core/vault.dart';

import 'support.dart';

Uint8List _hex(String text) {
  final clean = text.replaceAll(RegExp(r'\s'), '');
  return Uint8List.fromList([
    for (var i = 0; i < clean.length; i += 2)
      int.parse(clean.substring(i, i + 2), radix: 16),
  ]);
}

Uint8List _lp(List<int> bytes) =>
    Uint8List.fromList([..._u32(bytes.length), ...bytes]);

Uint8List _u32(int value) =>
    (ByteData(4)..setUint32(0, value)).buffer.asUint8List();

void main() {
  group('XChaCha20-Poly1305', () {
    // draft-irtf-cfrg-xchacha-03, appendix A.3.1.
    final plaintext = utf8.encode(
      "Ladies and Gentlemen of the class of '99: If I could offer you only one "
      'tip for the future, sunscreen would be it.',
    );
    final aad = _hex('50515253c0c1c2c3c4c5c6c7');
    final key = _hex(
      '808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f',
    );
    final nonce = _hex('404142434445464748494a4b4c4d4e4f5051525354555657');
    final expected = _hex('''
      bd6d179d3e83d43b9576579493c0e939572a1700252bfaccbed2902c21396cbb
      731c7f1b0b4aa6440bf3a82f4eda7e39ae64c6708c54c216cb96b72e1213b452
      2f8c9ba40db5d945b11b69b982c1bb9e3f3fac2bc369488f76b2383565d3fff9
      21f9664c97637da9768812f615c68b13b52e
      c0875924c1c7987947deafd8780acf49
    ''');

    test('matches the draft test vector (ciphertext || tag)', () async {
      final box = await sealBoxWithNonce(
        key,
        nonce,
        Uint8List.fromList(plaintext),
        aad,
      );
      expect(box.ciphertext, expected);
      expect(await openBox(key, nonce, expected, aad), plaintext);
    });

    test('fails closed on wrong key, nonce, aad or bytes', () async {
      expect(await openBox(flipBit(key), nonce, expected, aad), isNull);
      expect(await openBox(key, flipBit(nonce), expected, aad), isNull);
      expect(await openBox(key, nonce, expected, flipBit(aad)), isNull);
      expect(await openBox(key, nonce, flipBit(expected, 10), aad), isNull);
      expect(await openBox(key, nonce, expected.sublist(0, 15), aad), isNull);
    });

    test('random nonces are 24 bytes and fresh', () async {
      final a = await sealBox(key, Uint8List(0), aad);
      final b = await sealBox(key, Uint8List(0), aad);
      expect(a.nonce, hasLength(24));
      expect(a.nonce, isNot(b.nonce));
    });
  });

  group('AAD layout', () {
    const vaultId = '0123456789abcdef0123456789abcdef';
    const recordId = 'fedcba9876543210fedcba9876543210';

    test('record AAD is pinned', () {
      expect(
        recordAad(
          formatVersion: 1,
          vaultId: vaultId,
          kind: VaultRecordKind.sshKey,
          recordId: recordId,
        ),
        [
          ..._lp(utf8.encode('luks-remote-unlocker/vault/record')),
          ..._u32(1),
          ..._lp(utf8.encode(vaultId)),
          ..._lp(utf8.encode('ssh-key')),
          ..._lp(utf8.encode(recordId)),
        ],
      );
    });

    test('password slot AAD is pinned', () {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      expect(
        passwordSlotAad(
          formatVersion: 1,
          vaultId: vaultId,
          params: const Argon2Params(
            memoryKiB: 19456,
            iterations: 2,
            parallelism: 1,
          ),
          salt: salt,
        ),
        [
          ..._lp(utf8.encode('luks-remote-unlocker/vault/password-slot')),
          ..._u32(1),
          ..._lp(utf8.encode(vaultId)),
          ..._u32(19456),
          ..._u32(2),
          ..._u32(1),
          ..._lp(salt),
        ],
      );
    });

    test('key check AAD is pinned', () {
      expect(keyCheckAad(formatVersion: 1, vaultId: vaultId), [
        ..._lp(utf8.encode('luks-remote-unlocker/vault/key-check')),
        ..._u32(1),
        ..._lp(utf8.encode(vaultId)),
      ]);
    });

    test('every field changes the record AAD', () {
      Uint8List aad({
        int version = 1,
        String vault = vaultId,
        VaultRecordKind kind = VaultRecordKind.passphrase,
        String id = recordId,
      }) => recordAad(
        formatVersion: version,
        vaultId: vault,
        kind: kind,
        recordId: id,
      );
      final base = aad();
      for (final other in [
        aad(version: 2),
        aad(vault: recordId),
        aad(kind: VaultRecordKind.sshKey),
        aad(id: vaultId),
      ]) {
        expect(other, isNot(base));
      }
    });

    test('same key, other vault id: record does not open', () async {
      final key = randomBytes(32);
      Uint8List aadFor(String vault) => recordAad(
        formatVersion: 1,
        vaultId: vault,
        kind: VaultRecordKind.passphrase,
        recordId: recordId,
      );
      final box = await sealBox(key, fakePassphrase(), aadFor(vaultId));
      expect(
        await openBox(key, box.nonce, box.ciphertext, aadFor(recordId)),
        isNull,
      );
      expect(
        await openBox(key, box.nonce, box.ciphertext, aadFor(vaultId)),
        fakePassphrase(),
      );
    });
  });

  group('Argon2id', () {
    test('isolate and inline give the same 32-byte key', () async {
      final salt = Uint8List(16);
      final inline = await argon2idInline(fakePassword(), salt, fastParams);
      final isolated = await argon2idInIsolate(
        fakePassword(),
        salt,
        fastParams,
      );
      expect(inline, hasLength(32));
      expect(isolated, inline);
      expect(
        await argon2idInline(bytesOf('FAKE-other'), salt, fastParams),
        isNot(inline),
      );
      expect(
        await argon2idInline(fakePassword(), flipBit(salt), fastParams),
        isNot(inline),
      );
    });

    test('refuses out-of-bounds params', () async {
      await expectLater(
        argon2idInline(
          fakePassword(),
          Uint8List(16),
          const Argon2Params(memoryKiB: 64, iterations: 0, parallelism: 1),
        ),
        throwsArgumentError,
      );
    });

    test('default params through the isolate, timed', () async {
      final store = InMemoryVaultStore();
      final vault = await Vault.create(store);
      final watch = Stopwatch()..start();
      await vault.setPassword(fakePassword());
      final setMs = watch.elapsedMilliseconds;
      vault.lock();
      watch.reset();
      await vault.unlockWithPassword(fakePassword());
      final unlockMs = watch.elapsedMilliseconds;
      expect(vault.isUnlocked, isTrue);
      expect((await store.readPasswordSlot())!.params, Argon2Params.defaults);
      // ignore: avoid_print
      print(
        'Argon2id ${Argon2Params.defaults}: '
        'setPassword $setMs ms, unlockWithPassword $unlockMs ms',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
