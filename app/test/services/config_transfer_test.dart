import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/database.dart';
import 'package:luks_remote_unlocker/data/drift_vault_store.dart';
import 'package:luks_remote_unlocker/data/errors.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/key_repository.dart';
import 'package:luks_remote_unlocker/data/profile_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:luks_remote_unlocker/services/config_file.dart';
import 'package:luks_remote_unlocker/services/config_transfer.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/harness.dart';

const _pin = 'SHA256:TEvtlX/GczN0Jf70vMKaeCELsAQ3MJIrRfoKEG+DgbM';
const _seen = 'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _fakeDataPassphrase = 'FAKE data disk passphrase';

final class Side {
  Side._(this.db, this.vault, this.hosts)
    : keys = KeyRepository(db, hosts),
      secrets = SecretRepository(db, hosts),
      profiles = ProfileRepository(db, hosts);

  static Future<Side> open() async {
    final db = memoryDatabase();
    final vault = await Vault.create(DriftVaultStore(db), kdf: fakeKdf);
    await vault.setPassword(bytesOf(fakeMasterPassword), params: fastParams);
    return Side._(db, vault, HostRepository(db));
  }

  final AppDatabase db;
  final Vault vault;
  final HostRepository hosts;
  final KeyRepository keys;
  final SecretRepository secrets;
  final ProfileRepository profiles;

  ConfigTransfer get transfer =>
      ConfigTransfer(db, hosts, keys, secrets, profiles);

  Future<Host> host(String name) async =>
      (await hosts.all()).singleWhere((h) => h.name == name);

  Future<List<UnlockProfile>> customProfiles() async => [
    for (final p in await profiles.all())
      if (!p.builtIn) p,
  ];

  /// Hosts without ids; references replaced by fingerprint, label or profile content.
  Future<List<Map<String, Object?>>> portableHosts() async {
    final keyFps = {for (final k in await keys.all()) k.id: k.fingerprint};
    final labels = {
      for (final s in await secrets.all()) s.id: s.label.toLowerCase(),
    };
    final profileText = {
      for (final p in await profiles.all()) p.id: '${p.name}|${p.command}',
    };
    return [
      for (final h in await hosts.all())
        {
          ...h.toJson(),
          'id': null,
          'keyId': keyFps[h.keyId],
          'secretId': labels[h.secretId],
          'diskOverrides': {
            for (final e in h.diskOverrides.entries) e.key: labels[e.value],
          },
          'profileId': profileText[h.profileId],
        },
    ];
  }
}

Map<String, Object?> _decoded(Uint8List bytes) =>
    jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;

Map<String, Object?> _hostJson(Map<String, Object?> root, String name) =>
    (root['hosts']! as List).cast<Map<String, Object?>>().singleWhere(
      (h) => h['name'] == name,
    );

/// Binary body of a PEM block.
Uint8List _pemBody(Uint8List pem) => base64.decode(
  utf8
      .decode(pem)
      .split('\n')
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join(),
);

typedef _Mutation = void Function(
  Map<String, Object?> root,
  Map<String, Object?> alpha,
);

Map<Object?, Object?> _field(Map<String, Object?> o, String name) =>
    o[name]! as Map<Object?, Object?>;

Map<Object?, Object?> _firstEndpoint(Map<String, Object?> alpha) =>
    (alpha['preboot']! as List).first as Map<Object?, Object?>;

Map<Object?, Object?> _firstProfile(Map<String, Object?> root) =>
    (root['profiles']! as List).first as Map<Object?, Object?>;

final List<(String, _Mutation, String)> _invalidFiles = [
  (
    'another format',
    (r, a) => r['format'] = 'something-else',
    'not a configuration export of this app',
  ),
  (
    'a newer version',
    (r, a) => r['version'] = 2,
    'made by a newer version of the app (format 2)',
  ),
  (
    'version 0',
    (r, a) => r['version'] = 0,
    'format version 0 is not supported',
  ),
  (
    'version as text',
    (r, a) => r['version'] = '1',
    'format version is not a whole number',
  ),
  (
    'version as a fraction',
    (r, a) => r['version'] = 1.0,
    'format version is not a whole number',
  ),
  (
    'an unknown top-level field',
    (r, a) => r['secrets'] = <Object?>[],
    'has an unknown field "secrets"',
  ),
  ('a missing field', (r, a) => r.remove('hosts'), 'lacks the field "hosts"'),
  (
    'hosts not a list',
    (r, a) => r['hosts'] = <String, Object?>{},
    'hosts must be a list',
  ),
  ('a name that is a number', (r, a) => a['name'] = 42, 'name must be text'),
  ('a blank name', (r, a) => a['name'] = '  ', 'name needs a value'),
  (
    'a control character',
    (r, a) => a['name'] = 'al\u0000pha',
    'contains control characters',
  ),
  ('an overlong name', (r, a) => a['name'] = 'a' * 5000, 'is too long'),
  (
    'port 0',
    (r, a) => _firstEndpoint(a)['port'] = 0,
    'preboot[0], port must be a port from 1 to 65535',
  ),
  (
    'port 65536',
    (r, a) => _firstEndpoint(a)['port'] = 65536,
    'preboot[0], port must be a port from 1 to 65535',
  ),
  (
    'a port as text',
    (r, a) => _firstEndpoint(a)['port'] = '2222',
    'preboot[0], port must be a port from 1 to 65535',
  ),
  (
    'a port as a fraction',
    (r, a) => _firstEndpoint(a)['port'] = 2222.5,
    'preboot[0], port must be a port from 1 to 65535',
  ),
  (
    'a negative post-boot port',
    (r, a) => a['postbootPort'] = -1,
    'postbootPort must be a port from 1 to 65535',
  ),
  (
    'the tcp check on a pre-boot port',
    (r, a) => a['postbootPort'] = 22,
    'host "alpha": the tcp check needs a post-boot port that differs from '
        'every pre-boot port',
  ),
  (
    'an unknown check',
    (r, a) => a['postbootCheck'] = 'icmp',
    'postbootCheck is not a known check',
  ),
  (
    'a zero timeout',
    (r, a) => a['waitTimeoutSeconds'] = 0,
    'waitTimeoutSeconds must be a positive number of seconds',
  ),
  (
    'no pre-boot address',
    (r, a) => a['preboot'] = <Object?>[],
    'preboot needs at least one address',
  ),
  (
    'a flag as text',
    (r, a) => a['enabled'] = 'yes',
    'enabled must be true or false',
  ),
  (
    'a pin that is no SHA-256 fingerprint',
    (r, a) => _field(a, 'prebootKey')['fingerprint'] = 'MD5:00',
    'prebootKey, fingerprint is not a SHA256 fingerprint',
  ),
  (
    'a key fingerprint unlike its public key',
    (r, a) => _field(a, 'sshKey')['fingerprint'] = _pin,
    'sshKey, fingerprint does not match the public key',
  ),
  (
    'a public key of another type',
    (r, a) => _field(a, 'sshKey')['type'] = 'ssh-rsa',
    'sshKey, publicKey is not a "ssh-rsa" public key line',
  ),
  (
    'a private key smuggled into the key reference',
    (r, a) => _field(a, 'sshKey')['privateKey'] = 'FAKE',
    'sshKey has an unknown field "privateKey"',
  ),
  (
    'a passphrase smuggled into its reference',
    (r, a) => _field(a, 'passphrase')['value'] = 'FAKE',
    'passphrase has an unknown field "value"',
  ),
  (
    'a disk listed twice',
    (r, a) => _field(a, 'diskPassphrases')[' sdb_crypt'] = {'label': 'x'},
    'diskPassphrases lists "sdb_crypt" twice',
  ),
  (
    'a profile reusing a built-in id',
    (r, a) => _firstProfile(r)['ref'] = UnlockProfile.debian.id,
    'ref names a built-in profile',
  ),
  (
    'an unknown driver',
    (r, a) => _firstProfile(r)['driver'] = 'expect',
    'driver is not a known driver',
  ),
  (
    'too many hosts',
    (r, a) => r['hosts'] = List.filled(maxConfigHosts + 1, {
      ...a,
      'sshKey': null,
      'passphrase': null,
      'diskPassphrases': <String, Object?>{},
    }),
    'hosts has more than $maxConfigHosts entries',
  ),
];

void main() {
  late SshKey laptop;
  late Side source;
  late Side target;

  setUpAll(() => laptop = const SshKeyService().generateEd25519(comment: 'f'));

  setUp(() async {
    source = await Side.open();
    target = await Side.open();
    final key = await source.keys.add(source.vault, laptop, label: 'laptop');
    final root = await source.secrets.add(
      source.vault,
      label: 'root disk',
      passphrase: bytesOf(fakePassphraseText),
    );
    final data = await source.secrets.add(
      source.vault,
      label: 'data disk',
      passphrase: bytesOf(_fakeDataPassphrase),
    );
    final custom = (await source.profiles.copy(UnlockProfile.debian.id))
        .copyWith(name: 'Custom unlock', command: '/usr/bin/cryptroot-unlock');
    await source.profiles.save(custom);
    await source.hosts.save(
      Host(
        id: 'src-alpha',
        name: 'alpha',
        group: 'rack',
        preboot: [
          const Endpoint('10.0.0.1', 2222),
          const Endpoint('fe80::1', 22),
        ],
        user: 'unlock',
        keyId: key.id,
        secretId: root.id,
        diskOverrides: {'sdb_crypt': data.id},
        profileId: custom.id,
        postbootHost: 'alpha.lan',
        postbootPort: 2200,
        postbootCheck: PostBootCheck.tcp,
        waitTimeout: const Duration(minutes: 3),
        bootTimeout: const Duration(minutes: 7),
        prebootKey: HostKey('ssh-ed25519', _pin),
        postbootKey: HostKey(null, _seen),
        legacyAlgorithms: true,
        enabled: false,
      ),
    );
    await source.hosts.save(
      Host(
        id: 'src-beta',
        name: 'beta',
        preboot: [const Endpoint('192.0.2.7', 2222)],
        profileId: UnlockProfile.debian.id,
      ),
    );
  });

  tearDown(() async {
    await source.db.close();
    await target.db.close();
  });

  Future<Uint8List> exported() async => (await source.transfer.export()).bytes;

  group('export', () {
    test('holds only whitelisted, non-secret fields', () async {
      final export = await source.transfer.export();
      expect(export.hosts, 2);
      expect(export.profiles, 1);
      expect(export.unreadable, 0);
      final root = _decoded(export.bytes);
      expect(root.keys.toSet(), {
        'format',
        'version',
        'exportedAt',
        'profiles',
        'hosts',
      });
      expect(root['format'], configFormat);
      expect(root['version'], 1);
      final profiles = (root['profiles']! as List).cast<Map<String, Object?>>();
      expect(profiles.single.keys.toSet(), {
        'ref',
        'name',
        'driver',
        'command',
        'promptRegex',
        'successRegex',
        'failureRegex',
      });
      final alpha = _hostJson(root, 'alpha');
      expect(alpha.keys.toSet(), {
        'name',
        'group',
        'preboot',
        'user',
        'sshKey',
        'passphrase',
        'diskPassphrases',
        'profile',
        'postbootHost',
        'postbootPort',
        'postbootCheck',
        'waitTimeoutSeconds',
        'bootTimeoutSeconds',
        'prebootKey',
        'postbootKey',
        'legacyAlgorithms',
        'enabled',
      });
      expect(alpha['sshKey'], {
        'label': 'laptop',
        'type': 'ssh-ed25519',
        'publicKey': laptop.publicLine,
        'fingerprint': laptop.fingerprint,
      });
      expect(alpha['passphrase'], {'label': 'root disk'});
      expect(alpha['diskPassphrases'], {
        'sdb_crypt': {'label': 'data disk'},
      });
      expect(alpha['profile'], profiles.single['ref']);
      expect(alpha['prebootKey'], {'type': 'ssh-ed25519', 'fingerprint': _pin});
      expect(_hostJson(root, 'beta')['profile'], UnlockProfile.debian.id);
    });

    test('contains no passphrase, private key or vault data', () async {
      final bytes = await exported();
      expectNotInBytes(bytes, bytesOf(fakePassphraseText), 'passphrase');
      expectNotInBytes(bytes, bytesOf(_fakeDataPassphrase), 'data passphrase');
      expectNotInBytes(bytes, bytesOf(fakeMasterPassword), 'master password');
      final pem = laptop.privateKeyPem;
      expect(utf8.decode(pem), startsWith('-----BEGIN OPENSSH PRIVATE KEY'));
      expectNotInBytes(
        bytes,
        Uint8List.sublistView(pem, 40, pem.length - 40),
        'private key PEM',
      );
      final body = _pemBody(pem);
      expectNotInBytes(
        bytes,
        Uint8List.sublistView(body, body.length - 100),
        'private key',
      );
      final db = source.db;
      final records = await db.select(db.vaultRecords).get();
      expect(records, hasLength(3));
      for (final r in records) {
        expect(indexOfBytes(bytes, utf8.encode(r.id)), -1, reason: 'id');
        expectNotInBytes(bytes, r.nonce, 'record nonce');
        expectNotInBytes(bytes, r.ciphertext, 'record ciphertext');
      }
      final slot = (await db.select(db.vaultPasswordSlot).get()).single;
      expectNotInBytes(bytes, slot.salt, 'slot salt');
      expectNotInBytes(bytes, slot.wrappedKey, 'wrapped vault key');
      final meta = (await db.select(db.vaultMetadataTable).get()).single;
      expect(indexOfBytes(bytes, utf8.encode(meta.vaultId)), -1);
      expectNotInBytes(bytes, meta.keyCheck, 'key check');
      for (final id in [
        for (final k in await source.keys.all()) k.id,
        for (final s in await source.secrets.all()) s.id,
        'src-alpha',
        'src-beta',
      ]) {
        expect(indexOfBytes(bytes, utf8.encode(id)), -1, reason: 'local id');
      }
    });

    test('decodes to the same configuration it encodes', () async {
      final bytes = await exported();
      final file = ConfigFile.decode(bytes);
      expect(file.hosts.map((h) => h.host.name), ['beta', 'alpha']);
      expect(_decoded(file.encode()), _decoded(bytes));
    });
  });

  group('import', () {
    test('round trip into an empty database reproduces hosts and profiles; '
        'secrets stay unassigned and are reported', () async {
      final plan = await target.transfer.preview(await exported());
      expect(plan.hosts.map((h) => h.name), ['beta', 'alpha']);
      expect(plan.clashes, isEmpty);
      expect(plan.pinned, 1);
      expect(plan.newProfiles.single.name, 'Custom unlock');
      expect(plan.keys, isEmpty);
      expect(plan.passphrases, isEmpty);
      expect(
        [
          for (final u in plan.unlinked)
            (u.kind, u.label, u.fingerprint, u.usedBy.join(', ')),
        ],
        [
          (ReferenceKind.sshKey, 'laptop', laptop.fingerprint, 'alpha'),
          (ReferenceKind.passphrase, 'root disk', null, 'alpha'),
          (
            ReferenceKind.passphrase,
            'data disk',
            null,
            'alpha (disk sdb_crypt)',
          ),
        ],
      );
      expect(await target.hosts.all(), isEmpty, reason: 'preview writes');

      expect(await target.transfer.apply(plan, trustPins: true), 2);
      final expected = [
        for (final h in await source.portableHosts())
          {
            ...h,
            'keyId': null,
            'secretId': null,
            'diskOverrides': <String, Object?>{},
          },
      ];
      expect(await target.portableHosts(), expected);
      expect(
        [for (final p in await target.customProfiles()) p.copyWith(id: '')],
        [for (final p in await source.customProfiles()) p.copyWith(id: '')],
      );
    });

    test(
      'keys relink by fingerprint, passphrases by label in any case',
      () async {
        final key = await target.keys.add(
          target.vault,
          laptop,
          label: 'Work laptop',
        );
        final root = await target.secrets.add(
          target.vault,
          label: 'ROOT DISK',
          passphrase: bytesOf('FAKE-other-1'),
        );
        final data = await target.secrets.add(
          target.vault,
          label: 'Data Disk',
          passphrase: bytesOf('FAKE-other-2'),
        );
        final plan = await target.transfer.preview(await exported());
        expect(plan.unlinked, isEmpty);
        expect(
          [
            for (final k in plan.keys)
              (k.fileLabel, k.localLabel, k.fingerprint, k.usedBy.join(', ')),
          ],
          [('laptop', 'Work laptop', laptop.fingerprint, 'alpha')],
        );
        expect(
          [
            for (final p in plan.passphrases)
              (p.fileLabel, p.localLabel, p.usedBy.join(', ')),
          ],
          [
            ('root disk', 'ROOT DISK', 'alpha'),
            ('data disk', 'Data Disk', 'alpha (disk sdb_crypt)'),
          ],
        );

        await target.transfer.apply(plan, trustPins: true);
        expect(await target.portableHosts(), await source.portableHosts());
        final alpha = await target.host('alpha');
        expect(alpha.keyId, key.id);
        expect(alpha.secretId, root.id);
        expect(alpha.diskOverrides, {'sdb_crypt': data.id});
        expect(alpha.id, isNot('src-alpha'));
      },
    );

    test('unresolvable references are left unassigned and reported', () async {
      await target.keys.add(
        target.vault,
        const SshKeyService().generateEd25519(),
        label: 'laptop',
      );
      final root = await target.secrets.add(
        target.vault,
        label: 'root disk',
        passphrase: bytesOf('FAKE-other'),
      );
      final json = _decoded(await exported());
      _hostJson(json, 'beta')['profile'] = 'fedora-dracut';
      final plan = await target.transfer.preview(utf8.encode(jsonEncode(json)));
      expect(
        [for (final u in plan.unlinked) (u.kind, u.label, u.usedBy.join(', '))],
        [
          (ReferenceKind.profile, 'fedora-dracut', 'beta'),
          (ReferenceKind.sshKey, 'laptop', 'alpha'),
          (ReferenceKind.passphrase, 'data disk', 'alpha (disk sdb_crypt)'),
        ],
      );
      expect(plan.keys, isEmpty, reason: 'same label, other key');

      await target.transfer.apply(plan, trustPins: true);
      final alpha = await target.host('alpha');
      expect(alpha.keyId, isNull);
      expect(alpha.secretId, root.id);
      expect(alpha.diskOverrides, isEmpty);
      expect((await target.host('beta')).profileId, isNull);
    });

    test(
      'a name clash skips the file host and keeps the existing one',
      () async {
        final existing = Host(
          id: 'mine',
          name: 'ALPHA ',
          preboot: [const Endpoint('203.0.113.5', 2222)],
        );
        await target.hosts.save(existing);
        final plan = await target.transfer.preview(await exported());
        expect(plan.clashes, ['alpha']);
        expect(plan.hosts.map((h) => h.name), ['beta']);
        expect(plan.unlinked, isEmpty);
        expect(plan.pinned, 0);

        await target.transfer.apply(plan, trustPins: true);
        expect((await target.hosts.all()).map((h) => h.name), [
          'ALPHA',
          'beta',
        ]);
        expect(
          await target.hosts.get('mine'),
          existing.copyWith(name: 'ALPHA'),
        );

        final again = await target.transfer.preview(await exported());
        expect(again.clashes, ['beta', 'alpha']);
        expect(again.existingProfiles, ['Custom unlock']);
        expect(again.isEmpty, isTrue);
      },
    );

    test('profiles: identical ones are reused, taken names renamed', () async {
      final mine = (await target.profiles.copy(UnlockProfile.debian.id))
          .copyWith(name: 'custom UNLOCK', command: 'other-command');
      await target.profiles.save(mine);
      final plan = await target.transfer.preview(await exported());
      expect(plan.renamedProfiles, [
        (from: 'Custom unlock', to: 'Custom unlock (imported)'),
      ]);
      await target.transfer.apply(plan, trustPins: false);
      final custom = await target.customProfiles();
      expect(custom.map((p) => p.name), [
        'custom UNLOCK',
        'Custom unlock (imported)',
      ]);
      final imported = custom.last;
      expect(imported.command, '/usr/bin/cryptroot-unlock');
      expect((await target.host('alpha')).profileId, imported.id);
      expect((await target.profiles.get(mine.id))!.command, 'other-command');
    });

    test('pinned keys are imported only when trusted', () async {
      final plan = await target.transfer.preview(await exported());
      expect(plan.pinned, 1);
      await target.transfer.apply(plan, trustPins: false);
      final alpha = await target.host('alpha');
      expect(alpha.prebootKey, isNull);
      expect(alpha.postbootKey, HostKey(null, _seen));
    });

    test(
      'nothing is written when the data changed after the preview',
      () async {
        final plan = await target.transfer.preview(await exported());
        await target.hosts.save(
          Host(id: 'late', name: 'Beta', preboot: [const Endpoint('b', 2222)]),
        );
        await expectLater(
          target.transfer.apply(plan, trustPins: true),
          throwsA(isA<ImportChangedException>()),
        );
        expect((await target.hosts.all()).map((h) => h.name), ['Beta']);
        expect(await target.customProfiles(), isEmpty);
      },
    );
  });

  group('invalid files are refused with a clear message', () {
    for (final (what, mutate, message) in _invalidFiles) {
      test(what, () async {
        final root = _decoded(await exported());
        mutate(root, _hostJson(root, 'alpha'));
        final bytes = utf8.encode(jsonEncode(root));
        expect(
          () => ConfigFile.decode(bytes),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(message),
            ),
          ),
        );
      });
    }

    final raw = <(String, Uint8List, String)>[
      ('an empty file', Uint8List(0), 'it is not JSON'),
      ('plain text', bytesOf('hello'), 'it is not JSON'),
      (
        'invalid UTF-8',
        Uint8List.fromList([0xff, 0xfe, 0xfd]),
        'it is not JSON',
      ),
      ('a JSON list', bytesOf('[]'), 'not a configuration export of this app'),
      ('JSON null', bytesOf('null'), 'not a configuration export of this app'),
      (
        'deep nesting',
        bytesOf('${'[' * 200000}${']' * 200000}'),
        'not a configuration export',
      ),
      ('an oversized file', Uint8List(maxConfigFileBytes + 1), 'too large'),
    ];
    for (final (what, bytes, message) in raw) {
      test(what, () {
        expect(
          () => ConfigFile.decode(bytes),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(message),
            ),
          ),
        );
      });
    }

    test('the preview refuses them without writing anything', () async {
      final root = _decoded(await exported());
      _hostJson(root, 'alpha')['postbootPort'] = 2222;
      await expectLater(
        target.transfer.preview(utf8.encode(jsonEncode(root))),
        throwsFormatException,
      );
      expect(await target.hosts.all(), isEmpty);
      expect(await target.customProfiles(), isEmpty);
    });
  });
}
