import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unlock_core/vault.dart';

const Argon2Params fastParams = Argon2Params(
  memoryKiB: 64,
  iterations: 1,
  parallelism: 1,
);

Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

Uint8List fakePassword() => bytesOf('FAKE-test-password-not-real');

Uint8List fakePassphrase() => bytesOf('FAKE-luks-passphrase-correct-horse');

Uint8List fakeSshKey() => bytesOf(
  '-----BEGIN OPENSSH PRIVATE KEY-----\n'
  'FAKE-KEY-MATERIAL-for-tests-only-0123456789abcdef\n'
  '-----END OPENSSH PRIVATE KEY-----\n',
);

Uint8List patternBytes(int length, {int seed = 1}) {
  final random = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

Uint8List flipBit(Uint8List bytes, [int index = 0]) =>
    Uint8List.fromList(bytes)..[index] ^= 0x01;

/// Unlocked vault with a password slot, using inline Argon2id at tiny parameters.
Future<Vault> newVault({VaultStore? store, Uint8List? password}) async {
  final vault = await Vault.create(
    store ?? InMemoryVaultStore(),
    kdf: argon2idInline,
  );
  await vault.setPassword(password ?? fakePassword(), params: fastParams);
  return vault;
}

/// Fails if [secret] occurs in [haystack] raw, as hex, or as base64 at any byte alignment.
void expectNoLeak(Uint8List haystack, Uint8List secret, String what) {
  expect(_indexOf(haystack, secret), -1, reason: '$what found raw');
  final hex = secret.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  for (final form in [hex, hex.toUpperCase()]) {
    expect(_indexOf(haystack, bytesOf(form)), -1, reason: '$what found as hex');
  }
  for (var offset = 0; offset < 3; offset++) {
    final part = secret.sublist(offset);
    final stable = base64.encode(part).substring(0, (part.length ~/ 3) * 4);
    for (final form in [
      stable,
      stable.replaceAll('+', '-').replaceAll('/', '_'),
    ]) {
      expect(
        _indexOf(haystack, bytesOf(form)),
        -1,
        reason: '$what found as base64 (offset $offset)',
      );
    }
  }
}

int _indexOf(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty) {
    return 0;
  }
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        continue outer;
      }
    }
    return i;
  }
  return -1;
}
