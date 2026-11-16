import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/database.dart';
import 'package:luks_remote_unlocker/data/drift_vault_store.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/key_repository.dart';
import 'package:luks_remote_unlocker/data/profile_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:luks_remote_unlocker/services/run_preparation.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/harness.dart';

void main() {
  late AppDatabase db;
  late DriftVaultStore store;
  late Vault vault;
  late HostRepository hosts;
  late KeyRepository keys;
  late SecretRepository secrets;
  late ProfileRepository profiles;

  setUp(() async {
    db = memoryDatabase();
    store = DriftVaultStore(db);
    vault = await Vault.create(store, kdf: fakeKdf);
    await vault.setPassword(bytesOf(fakeMasterPassword), params: fastParams);
    hosts = HostRepository(db);
    keys = KeyRepository(db, hosts);
    secrets = SecretRepository(db, hosts);
    profiles = ProfileRepository(db, hosts);
  });

  tearDown(() => db.close());

  test(
    'one unlocked vault yields plans with keys and per-disk passphrases',
    () async {
      final generated = const SshKeyService().generateEd25519();
      final pem = Uint8List.fromList(generated.privateKeyPem);
      final key = await keys.add(vault, generated, label: 'k');
      final main = await secrets.add(
        vault,
        label: 'm',
        passphrase: bytesOf('FAKE-main'),
      );
      final data = await secrets.add(
        vault,
        label: 'd',
        passphrase: bytesOf('FAKE-data'),
      );
      final custom = await profiles.copy(UnlockProfile.debian.id);
      final a = Host(
        id: 'a',
        name: 'a',
        preboot: [const Endpoint('a', 2222)],
        keyId: key.id,
        secretId: main.id,
        diskOverrides: {'sdb_crypt': data.id},
        profileId: custom.id,
      );
      final b = Host(
        id: 'b',
        name: 'b',
        preboot: [const Endpoint('b', 2222)],
        keyId: key.id,
        secretId: main.id,
      );
      final c = Host(id: 'c', name: 'c', preboot: [const Endpoint('c', 2222)]);

      final run = await RunPreparation(
        keys,
        secrets,
        profiles,
        store,
      ).prepare(vault, [a, b, c]);
      expect(run.plans.map((p) => p.host.id), ['a', 'b']);
      expect(run.skipped.single.host.id, 'c');
      expect(run.skipped.single.reason, contains('SSH key'));
      final planA = run.plans.first;
      expect(planA.privateKeyPem, pem);
      expect(planA.secrets.passphraseFor('sda3_crypt'), bytesOf('FAKE-main'));
      expect(planA.secrets.passphraseFor('sdb_crypt'), bytesOf('FAKE-data'));
      expect(planA.profile.id, custom.id);
      expect(run.plans.last.profile, UnlockProfile.debian);
      expect(
        identical(planA.privateKeyPem, run.plans.last.privateKeyPem),
        isTrue,
      );

      run.wipe();
      expect(planA.privateKeyPem.every((b) => b == 0), isTrue);
      expect(planA.secrets.passphraseFor('x').every((b) => b == 0), isTrue);
    },
  );

  test('a record of the wrong kind is never used', () async {
    final key = await keys.add(
      vault,
      const SshKeyService().generateEd25519(),
      label: 'k',
    );
    final s = await secrets.add(vault, label: 's', passphrase: bytesOf('FAKE'));
    final keyAsSecret = await secrets.add(
      vault,
      label: 'x',
      passphrase: bytesOf('FAKE-x'),
    );
    await (db.update(db.secrets)..where((r) => r.id.equals(keyAsSecret.id)))
        .write(SecretsCompanion(vaultRecordId: Value(key.vaultRecordId)));
    final secretAsKey = await keys.add(
      vault,
      const SshKeyService().generateEd25519(),
      label: 'y',
    );
    await (db.update(db.sshKeys)..where((r) => r.id.equals(secretAsKey.id)))
        .write(SshKeysCompanion(vaultRecordId: Value(s.vaultRecordId)));

    Host host(String id, String keyId, String secretId, [String? disk]) => Host(
      id: id,
      name: id,
      preboot: [Endpoint(id, 2222)],
      keyId: keyId,
      secretId: secretId,
      diskOverrides: {'sdb_crypt': ?disk},
    );

    final run = await RunPreparation(keys, secrets, profiles, store).prepare(
      vault,
      [
        host('a', key.id, keyAsSecret.id),
        host('b', secretAsKey.id, s.id),
        host('c', key.id, s.id, keyAsSecret.id),
        host('d', key.id, s.id),
      ],
    );
    expect(run.plans.map((p) => p.host.id), ['d']);
    expect(run.skipped.map((h) => h.host.id), ['a', 'b', 'c']);
    expect(run.skipped.map((h) => h.reason), [
      'The vault record of passphrase "x" is missing or of another kind',
      'The vault record of SSH key "y" is missing or of another kind',
      'The vault record of passphrase "x" is missing or of another kind',
    ]);
    run.wipe();
  });

  test('a locked vault is refused', () async {
    final key = await keys.add(
      vault,
      const SshKeyService().generateEd25519(),
      label: 'k',
    );
    final s = await secrets.add(vault, label: 's', passphrase: bytesOf('FAKE'));
    final host = Host(
      id: 'a',
      name: 'a',
      preboot: [const Endpoint('a', 2222)],
      keyId: key.id,
      secretId: s.id,
    );
    vault.lock();
    await expectLater(
      RunPreparation(keys, secrets, profiles, store).prepare(vault, [host]),
      throwsA(isA<VaultLockedException>()),
    );
  });
}
