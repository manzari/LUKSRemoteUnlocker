import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/database.dart';
import 'package:luks_remote_unlocker/data/drift_vault_store.dart';
import 'package:luks_remote_unlocker/data/errors.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/key_repository.dart';
import 'package:luks_remote_unlocker/data/profile_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
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
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
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

  Host host(
    String name, {
    String? keyId,
    String? secretId,
    Map<String, String> disks = const {},
    String? profileId,
    String? group,
  }) => Host(
    id: 'id-$name',
    name: name,
    group: group,
    preboot: [
      const Endpoint('10.0.0.1', 2222),
      const Endpoint('vpn.example', 2223),
    ],
    keyId: keyId,
    secretId: secretId,
    diskOverrides: disks,
    profileId: profileId,
    prebootKey: HostKey(
      'ssh-ed25519',
      'SHA256:TEvtlX/GczN0Jf70vMKaeCELsAQ3MJIrRfoKEG+DgbM',
    ),
  );

  group('hosts', () {
    test('save, read back every field, update, toggle, delete', () async {
      final key = await keys.add(
        vault,
        const SshKeyService().generateEd25519(comment: 'c'),
        label: 'laptop',
      );
      final secret = await secrets.add(
        vault,
        label: 'root disk',
        passphrase: bytesOf(fakePassphraseText),
      );
      final full = Host(
        id: 'h1',
        name: 'alpha',
        group: 'rack',
        preboot: [
          const Endpoint('10.0.0.1', 2222),
          const Endpoint('fe80::1', 22),
        ],
        user: 'unlock',
        keyId: key.id,
        secretId: secret.id,
        diskOverrides: {'sdb_crypt': secret.id},
        profileId: UnlockProfile.debian.id,
        postbootHost: 'alpha.lan',
        postbootPort: 2200,
        postbootCheck: PostBootCheck.tcp,
        waitTimeout: const Duration(minutes: 3),
        bootTimeout: const Duration(minutes: 7),
        prebootKey: HostKey.parse(
          'ssh-ed25519 SHA256:TEvtlX/GczN0Jf70vMKaeCELsAQ3MJIrRfoKEG+DgbM',
        ),
        postbootKey: HostKey(
          null,
          'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        ),
        legacyAlgorithms: true,
        enabled: false,
      );
      await hosts.save(full);
      expect(await hosts.get('h1'), full);

      await hosts.save(full.copyWith(name: 'alpha2', enabled: true));
      expect((await hosts.get('h1'))!.name, 'alpha2');
      expect(await hosts.all(), hasLength(1));

      await hosts.setEnabled('h1', false);
      expect((await hosts.get('h1'))!.enabled, isFalse);
      await hosts.setPostbootKey('h1', null);
      expect((await hosts.get('h1'))!.postbootKey, isNull);
      await hosts.setPrebootKey('h1', null);
      expect((await hosts.get('h1'))!.prebootKey, isNull);

      await hosts.delete('h1');
      expect(await hosts.get('h1'), isNull);
    });

    test('stream is sorted by group then name', () async {
      await hosts.save(host('zeta', group: 'b'));
      await hosts.save(host('beta'));
      await hosts.save(host('alpha', group: 'b'));
      final list = await hosts.watchAll().first;
      expect(list.map((h) => h.name), ['beta', 'alpha', 'zeta']);
    });

    test(
      'an unreadable row is left out instead of breaking the list',
      () async {
        final key = await keys.add(
          vault,
          const SshKeyService().generateEd25519(),
          label: 'k',
        );
        final secret = await secrets.add(
          vault,
          label: 's',
          passphrase: bytesOf('FAKE'),
        );
        await hosts.save(host('good'));
        await hosts.save(host('bad', keyId: key.id, secretId: secret.id));
        await hosts.save(host('bad-disks', disks: {'sdb': secret.id}));
        await (db.update(db.hosts)..where((h) => h.id.equals('id-bad'))).write(
          const HostsCompanion(prebootJson: Value('{not json')),
        );
        await (db.update(
          db.hosts,
        )..where((h) => h.id.equals('id-bad-disks'))).write(
          const HostsCompanion(diskOverridesJson: Value('{"sdb": 1}')),
        );

        expect((await hosts.watchAll().first).map((h) => h.name), ['good']);
        expect((await hosts.all()).map((h) => h.name), ['good']);
        expect(await hosts.get('id-bad'), isNull);
        expect(await hosts.namesUsingKey(key.id), ['bad']);
        expect(await hosts.namesUsingSecret(secret.id), ['bad']);
        await expectLater(
          keys.delete(vault, key.id),
          throwsA(isA<InUseException>()),
        );
      },
    );

    test('invalid hosts are refused', () async {
      await expectLater(
        hosts.save(
          host('x')
              .copyWith(postbootCheck: PostBootCheck.tcp, postbootPort: 2222),
        ),
        throwsArgumentError,
      );
    });
  });

  group('keys', () {
    test('add stores the private key in the vault only', () async {
      final generated = const SshKeyService().generateEd25519(comment: 'test');
      final stored = await keys.add(vault, generated, label: ' laptop ');
      expect(stored.label, 'laptop');
      expect(stored.publicLine, generated.publicLine);
      expect(stored.fingerprint, generated.fingerprint);
      expect(stored.typeLabel, 'Ed25519');
      expect(
        await keys.privateKeyPem(vault, stored.id),
        generated.privateKeyPem,
      );
      expect(await store.listRecordIds(), [stored.vaultRecordId]);
      final list = await keys.watchAll().first;
      expect(list.single.id, stored.id);
    });

    test('the same key cannot be added twice', () async {
      final generated = const SshKeyService().generateEd25519();
      await keys.add(vault, generated, label: 'one');
      await expectLater(
        keys.add(vault, generated, label: 'two'),
        throwsA(
          isA<DuplicateKeyException>().having(
            (e) => e.existingLabel,
            'label',
            'one',
          ),
        ),
      );
      expect(await store.listRecordIds(), hasLength(1));
    });

    test('delete is refused while hosts use the key, naming them', () async {
      final stored = await keys.add(
        vault,
        const SshKeyService().generateEd25519(),
        label: 'laptop',
      );
      await hosts.save(host('alpha', keyId: stored.id));
      await hosts.save(host('beta', keyId: stored.id));
      await expectLater(
        keys.delete(vault, stored.id),
        throwsA(
          isA<InUseException>()
              .having((e) => e.hostNames, 'hosts', ['alpha', 'beta'])
              .having((e) => e.message, 'message', contains('alpha, beta')),
        ),
      );
      expect(await keys.get(stored.id), isNotNull);
      expect(await store.listRecordIds(), [stored.vaultRecordId]);

      await hosts.delete('id-alpha');
      await hosts.delete('id-beta');
      await keys.delete(vault, stored.id);
      expect(await keys.get(stored.id), isNull);
      expect(await store.listRecordIds(), isEmpty);
    });

    test('labels are unique, trimmed and in any case', () async {
      await keys.add(
        vault,
        const SshKeyService().generateEd25519(),
        label: 'Laptop',
      );
      await expectLater(
        keys.add(
          vault,
          const SshKeyService().generateEd25519(),
          label: ' laptop ',
        ),
        throwsA(
          isA<DuplicateLabelException>().having(
            (e) => e.message,
            'message',
            'A key labelled "laptop" already exists. Choose another label.',
          ),
        ),
      );
      expect(await store.listRecordIds(), hasLength(1));
      final other = await keys.add(
        vault,
        const SshKeyService().generateEd25519(),
        label: 'desktop',
      );
      await expectLater(
        keys.rename(other.id, 'LAPTOP'),
        throwsA(isA<DuplicateLabelException>()),
      );
      await keys.rename(other.id, 'Desktop');
      expect((await keys.get(other.id))!.label, 'Desktop');
    });

    test('rename keeps the vault record', () async {
      final stored = await keys.add(
        vault,
        const SshKeyService().generateEd25519(),
        label: 'old',
      );
      await keys.rename(stored.id, 'new');
      expect((await keys.get(stored.id))!.label, 'new');
      expect((await keys.get(stored.id))!.vaultRecordId, stored.vaultRecordId);
    });

    test('adding needs an unlocked vault and leaves nothing behind', () async {
      vault.lock();
      await expectLater(
        keys.add(vault, const SshKeyService().generateEd25519(), label: 'x'),
        throwsA(isA<VaultLockedException>()),
      );
      expect(await keys.watchAll().first, isEmpty);
      expect(await store.listRecordIds(), isEmpty);
    });
  });

  group('secrets', () {
    test('add keeps the bytes exactly, replace and reveal', () async {
      final s = await secrets.add(
        vault,
        label: 'disk',
        passphrase: bytesOf(fakePassphraseText),
      );
      expect(await secrets.reveal(vault, s.id), bytesOf(fakePassphraseText));
      await secrets.replace(vault, s.id, bytesOf('FAKE-new'));
      expect(await secrets.reveal(vault, s.id), bytesOf('FAKE-new'));
      expect(await store.listRecordIds(), [s.vaultRecordId]);
    });

    test('labels are unique', () async {
      final a = await secrets.add(
        vault,
        label: 'root',
        passphrase: bytesOf('FAKE-1'),
      );
      await expectLater(
        secrets.add(vault, label: 'ROOT', passphrase: bytesOf('FAKE-2')),
        throwsA(isA<DuplicateLabelException>()),
      );
      expect(await store.listRecordIds(), [a.vaultRecordId]);
      final b = await secrets.add(
        vault,
        label: 'data',
        passphrase: bytesOf('FAKE-3'),
      );
      await expectLater(
        secrets.rename(b.id, 'root'),
        throwsA(isA<DuplicateLabelException>()),
      );
      await secrets.rename(a.id, 'Root');
    });

    test(
      'delete refused for default and per-disk use, then cleans up',
      () async {
        final a = await secrets.add(
          vault,
          label: 'a',
          passphrase: bytesOf('FAKE-1'),
        );
        final b = await secrets.add(
          vault,
          label: 'b',
          passphrase: bytesOf('FAKE-2'),
        );
        await hosts.save(host('alpha', secretId: a.id, disks: {'sdb': b.id}));
        await expectLater(
          secrets.delete(vault, a.id),
          throwsA(isA<InUseException>()),
        );
        await expectLater(
          secrets.delete(vault, b.id),
          throwsA(
            isA<InUseException>().having((e) => e.hostNames, 'hosts', [
              'alpha',
            ]),
          ),
        );
        await hosts.delete('id-alpha');
        await secrets.delete(vault, b.id);
        expect(await secrets.get(b.id), isNull);
        expect(await store.listRecordIds(), [a.vaultRecordId]);
      },
    );
  });

  group('profiles', () {
    test('the Debian profile is seeded and read-only', () async {
      final all = await profiles.all();
      expect(all.single, UnlockProfile.debian);
      await expectLater(
        profiles.save(UnlockProfile.debian.copyWith(command: 'x')),
        throwsA(isA<ReadOnlyProfileException>()),
      );
      await expectLater(
        profiles.save(
          UnlockProfile.debian.copyWith(command: 'x', builtIn: false),
        ),
        throwsA(isA<ReadOnlyProfileException>()),
      );
      await expectLater(
        profiles.delete(UnlockProfile.debian.id),
        throwsA(isA<ReadOnlyProfileException>()),
      );
    });

    test('copy, edit, refuse delete in use, delete', () async {
      final copy = await profiles.copy(UnlockProfile.debian.id);
      expect(copy.builtIn, isFalse);
      expect(copy.command, 'cryptroot-unlock');
      await profiles.save(copy.copyWith(command: '/usr/bin/cryptroot-unlock'));
      expect(
        (await profiles.get(copy.id))!.command,
        '/usr/bin/cryptroot-unlock',
      );
      final list = await profiles.watchAll().first;
      expect(list.first.builtIn, isTrue);
      expect(list, hasLength(2));

      await hosts.save(host('alpha', profileId: copy.id));
      await expectLater(
        profiles.delete(copy.id),
        throwsA(isA<InUseException>()),
      );
      await hosts.delete('id-alpha');
      await profiles.delete(copy.id);
      expect(await profiles.get(copy.id), isNull);
    });
  });
}
