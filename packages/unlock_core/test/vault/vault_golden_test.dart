import 'dart:io';

import 'package:test/test.dart';
import 'package:unlock_core/vault.dart';

import 'support.dart';

/// Format v1 vault written once by this code; it must keep opening, or old vaults become unreadable.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vault_golden_');
    path = '${dir.path}/vault.json';
    await File('test/vault/fixtures/vault_v1.json').copy(path);
  });

  tearDown(() => dir.delete(recursive: true));

  test('v1 fixture opens and decrypts', () async {
    final vault = await Vault.open(
      await FileVaultStore.open(path),
      kdf: argon2idInline,
    );
    expect(vault.id, '843b327ad79e9c02b082e5bc5c3cb06f');
    expect(vault.hasPasswordSlot, isTrue);
    expect(vault.biometricSlotEnrolled, isFalse);
    await vault.unlockWithPassword(bytesOf('FAKE-golden-password'));
    expect(
      await vault.get('9b2ed62b3abf7d62c0258c2874fb6e44'),
      bytesOf('FAKE-golden-passphrase'),
    );
    expect(
      await vault.get('8f3579d099054d978f9f3fd478646bba'),
      bytesOf('FAKE-golden-ssh-key'),
    );
  });

  test('v1 fixture rejects a wrong password', () async {
    final vault = await Vault.open(
      await FileVaultStore.open(path),
      kdf: argon2idInline,
    );
    await expectLater(
      vault.unlockWithPassword(bytesOf('FAKE-not-the-golden-password')),
      throwsA(isA<VaultWrongPasswordException>()),
    );
  });
}
