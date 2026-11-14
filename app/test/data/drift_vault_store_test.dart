import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/database.dart';
import 'package:luks_remote_unlocker/data/drift_vault_store.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/key_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/harness.dart';

void main() {
  late AppDatabase db;
  late DriftVaultStore store;

  setUp(() {
    db = memoryDatabase();
    store = DriftVaultStore(db);
  });

  tearDown(() => db.close());

  Future<Vault> newVault() async {
    final vault = await Vault.create(store, kdf: fakeKdf);
    await vault.setPassword(bytesOf(fakeMasterPassword), params: fastParams);
    return vault;
  }

  test('empty store has no vault', () async {
    expect(await Vault.exists(store), isFalse);
    expect(await store.readMetadata(), isNull);
    expect(await store.readPasswordSlot(), isNull);
    expect(await store.listRecordIds(), isEmpty);
  });

  test('create refuses a store that already holds a vault', () async {
    await newVault();
    await expectLater(
      Vault.create(store, kdf: fakeKdf),
      throwsA(isA<VaultAlreadyExistsException>()),
    );
  });

  test('metadata, password slot and records round-trip', () async {
    final vault = await newVault();
    final metadata = (await store.readMetadata())!;
    expect(metadata.vaultId, vault.id);
    expect(metadata.biometricSlotEnrolled, isFalse);
    final slot = (await store.readPasswordSlot())!;
    expect(slot.params, fastParams);

    final a = await vault.put(VaultRecordKind.passphrase, bytesOf('FAKE-a'));
    final b = await vault.put(VaultRecordKind.sshKey, bytesOf('FAKE-b'));
    expect((await store.listRecordIds()).toSet(), {a, b});
    expect((await store.readRecord(b))!.kind, VaultRecordKind.sshKey);
    expect(await vault.get(a), bytesOf('FAKE-a'));

    await vault.replace(a, bytesOf('FAKE-a2'));
    expect(await vault.get(a), bytesOf('FAKE-a2'));
    expect(await store.listRecordIds(), hasLength(2));

    await vault.delete(b);
    expect(await store.listRecordIds(), [a]);
    expect(await store.readRecord(b), isNull);
  });

  test('biometric flag and slot removal persist', () async {
    final vault = await newVault();
    final keyStore = InMemoryVaultKeyStore();
    await vault.enrollKeyStore(keyStore);
    expect((await store.readMetadata())!.biometricSlotEnrolled, isTrue);
    await vault.removePasswordSlot(keyStore);
    expect(await store.readPasswordSlot(), isNull);

    final reopened = await Vault.open(store, kdf: fakeKdf);
    expect(reopened.hasPasswordSlot, isFalse);
    expect(reopened.biometricSlotEnrolled, isTrue);
    await reopened.unlockWithKeyStore(keyStore);
    expect(reopened.isUnlocked, isTrue);
  });

  test('reopen: same records, password change re-wraps only', () async {
    final vault = await newVault();
    final id = await vault.put(
      VaultRecordKind.passphrase,
      bytesOf(fakePassphraseText),
    );
    await vault.changePassword(
      bytesOf('FAKE-second-password'),
      params: fastParams,
    );
    vault.lock();

    final reopened = await Vault.open(store, kdf: fakeKdf);
    await expectLater(
      reopened.unlockWithPassword(bytesOf(fakeMasterPassword)),
      throwsA(isA<VaultWrongPasswordException>()),
    );
    await reopened.unlockWithPassword(bytesOf('FAKE-second-password'));
    expect(await reopened.get(id), bytesOf(fakePassphraseText));
  });

  test('reset wipes the vault, keys and secrets and unassigns hosts', () async {
    final vault = await newVault();
    final hosts = HostRepository(db);
    final key = await KeyRepository(
      db,
      hosts,
    ).add(vault, const SshKeyService().generateEd25519(), label: 'k');
    final secret = await SecretRepository(
      db,
      hosts,
    ).add(vault, label: 's', passphrase: bytesOf('FAKE-x'));
    await hosts.save(
      Host(
        id: 'h',
        name: 'h',
        preboot: [const Endpoint('h', 2222)],
        keyId: key.id,
        secretId: secret.id,
        diskOverrides: {'sdb': secret.id},
      ),
    );
    await store.reset();
    final host = (await hosts.get('h'))!;
    expect(host.keyId, isNull);
    expect(host.secretId, isNull);
    expect(host.diskOverrides, isEmpty);
    expect(await db.select(db.sshKeys).get(), isEmpty);
    expect(await db.select(db.secrets).get(), isEmpty);
    expect(await Vault.exists(store), isFalse);
    expect(await store.readPasswordSlot(), isNull);
    expect(await store.listRecordIds(), isEmpty);
    await newVault();
    expect(await Vault.exists(store), isTrue);
  });
}
