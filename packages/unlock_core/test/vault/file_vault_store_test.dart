import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unlock_core/vault.dart';

import 'support.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vault_test_');
    path = '${dir.path}/vault.json';
  });

  tearDown(() => dir.delete(recursive: true));

  Future<Vault> reopen() async {
    final vault = await Vault.open(
      await FileVaultStore.open(path),
      kdf: argon2idInline,
    );
    await vault.unlockWithPassword(fakePassword());
    return vault;
  }

  test('missing file means no vault until the first write', () async {
    final store = await FileVaultStore.open(path);
    expect(await Vault.exists(store), isFalse);
    expect(File(path).existsSync(), isFalse);
  });

  test('survives reopen with both slots', () async {
    final vault = await newVault(store: await FileVaultStore.open(path));
    final keyStore = InMemoryVaultKeyStore();
    await vault.enrollKeyStore(keyStore);
    final passId = await vault.put(
      VaultRecordKind.passphrase,
      fakePassphrase(),
    );
    final keyId = await vault.put(VaultRecordKind.sshKey, fakeSshKey());
    vault.lock();

    final reopened = await Vault.open(
      await FileVaultStore.open(path),
      kdf: argon2idInline,
    );
    expect(reopened.id, vault.id);
    expect(reopened.hasPasswordSlot, isTrue);
    expect(reopened.biometricSlotEnrolled, isTrue);
    await reopened.unlockWithPassword(fakePassword());
    expect(await reopened.get(passId), fakePassphrase());
    expect(await reopened.get(keyId), fakeSshKey());
    reopened.lock();
    await reopened.unlockWithKeyStore(keyStore);
    expect(await reopened.get(keyId), fakeSshKey());
  });

  test('vault file holds no plaintext secret, password or vault key', () async {
    final vault = await newVault(store: await FileVaultStore.open(path));
    final keyStore = InMemoryVaultKeyStore();
    await vault.enrollKeyStore(keyStore);
    await vault.put(VaultRecordKind.passphrase, fakePassphrase());
    await vault.put(VaultRecordKind.sshKey, fakeSshKey());
    final id = await vault.put(
      VaultRecordKind.passphrase,
      bytesOf('FAKE-passphrase-before-replace'),
    );
    await vault.replace(id, bytesOf('FAKE-passphrase-after-replace'));
    final secondPassword = bytesOf('FAKE-second-test-password');
    await vault.changePassword(secondPassword, params: fastParams);

    final fileBytes = await File(path).readAsBytes();
    expect(utf8.decode(fileBytes), contains(id));
    for (final (what, secret) in [
      ('passphrase', fakePassphrase()),
      ('ssh key', fakeSshKey()),
      ('replaced passphrase', bytesOf('FAKE-passphrase-before-replace')),
      ('new passphrase', bytesOf('FAKE-passphrase-after-replace')),
      ('first password', fakePassword()),
      ('second password', secondPassword),
      ('vault key', (await keyStore.read())!),
    ]) {
      expectNoLeak(fileBytes, secret, what);
    }
  });

  test('leak search catches raw, hex and base64 occurrences', () {
    final secret = fakePassphrase();
    for (final haystack in [
      Uint8List.fromList([1, 2, ...secret, 3]),
      bytesOf(
        'x${secret.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
      ),
      for (var pad = 0; pad < 3; pad++)
        bytesOf('"${base64.encode([...List.filled(pad, 7), ...secret, 9])}"'),
    ]) {
      expect(
        () => expectNoLeak(haystack, secret, 'planted'),
        throwsA(isA<TestFailure>()),
      );
    }
  });

  test('file and created directory are owner-only', () async {
    final nested = '${dir.path}/config/vault.json';
    await newVault(store: await FileVaultStore.open(nested));
    expect(File(nested).statSync().mode & 0x1FF, int.parse('600', radix: 8));
    expect(
      Directory('${dir.path}/config').statSync().mode & 0x1FF,
      int.parse('700', radix: 8),
    );
  }, testOn: 'posix');

  test('the temp file is owner-only from creation; a loose file is replaced', () async {
    final modes = <int>[];
    final store = await FileVaultStore.open(
      path,
      onBeforeRename: () async =>
          modes.add(File('$path.tmp').statSync().mode & 0x1FF),
    );
    final vault = await newVault(store: store);
    final chmod = await Process.run('chmod', ['644', path]);
    expect(chmod.exitCode, 0);
    await vault.put(VaultRecordKind.passphrase, fakePassphrase());
    expect(modes, isNotEmpty);
    expect(modes.toSet(), {int.parse('600', radix: 8)});
    expect(File(path).statSync().mode & 0x1FF, int.parse('600', radix: 8));
  }, testOn: 'posix');

  test('withOwnerOnlyUmask restores the umask; syncDirectory is safe', () {
    final before = File('${dir.path}/before')..createSync();
    final (file, sub) = withOwnerOnlyUmask(() {
      final f = File('${dir.path}/inside')..createSync();
      final d = Directory('${dir.path}/a/b')..createSync(recursive: true);
      return (f, d);
    });
    final after = File('${dir.path}/after')..createSync();
    expect(file.statSync().mode & 0x1FF, int.parse('600', radix: 8));
    expect(sub.statSync().mode & 0x1FF, int.parse('700', radix: 8));
    expect(
      Directory('${dir.path}/a').statSync().mode & 0x1FF,
      int.parse('700', radix: 8),
    );
    expect(after.statSync().mode, before.statSync().mode);
    syncDirectory(dir.path);
    syncDirectory('${dir.path}/missing');
  }, testOn: 'posix');

  group('atomic writes', () {
    test(
      'a failed write keeps the old file, no temp file, old state',
      () async {
        var failing = false;
        final store = await FileVaultStore.open(
          path,
          onBeforeRename: () async {
            if (failing) {
              throw const FileSystemException('simulated crash');
            }
          },
        );
        final vault = await newVault(store: store);
        final id = await vault.put(
          VaultRecordKind.passphrase,
          fakePassphrase(),
        );
        final before = await File(path).readAsBytes();

        failing = true;
        await expectLater(
          vault.replace(id, bytesOf('FAKE-never-written')),
          throwsA(isA<FileSystemException>()),
        );
        await expectLater(
          vault.put(VaultRecordKind.sshKey, fakeSshKey()),
          throwsA(isA<FileSystemException>()),
        );
        expect(await File(path).readAsBytes(), before);
        expect(File(store.tempPath).existsSync(), isFalse);
        expect(dir.listSync().map((e) => e.path), [path]);
        expect(await vault.get(id), fakePassphrase());
        expect(await vault.recordIds(), [id]);

        failing = false;
        await vault.replace(id, bytesOf('FAKE-written-later'));
        expect(await (await reopen()).get(id), bytesOf('FAKE-written-later'));
      },
    );

    test('a stale temp file from a crash is replaced', () async {
      final store = await FileVaultStore.open(path);
      await File(store.tempPath).writeAsString('partial write from a crash');
      final vault = await newVault(store: store);
      final id = await vault.put(VaultRecordKind.passphrase, fakePassphrase());
      expect(File(store.tempPath).existsSync(), isFalse);
      expect(await (await reopen()).get(id), fakePassphrase());
    });

    test('concurrent writes are serialized, none lost', () async {
      final vault = await newVault(store: await FileVaultStore.open(path));
      final ids = await Future.wait([
        for (var i = 0; i < 20; i++)
          vault.put(VaultRecordKind.passphrase, bytesOf('FAKE-secret-$i')),
      ]);
      final reopened = await reopen();
      expect((await reopened.recordIds()).toSet(), ids.toSet());
      for (var i = 0; i < ids.length; i++) {
        expect(await reopened.get(ids[i]), bytesOf('FAKE-secret-$i'));
      }
    });
  });

  group('corrupt files', () {
    Future<Map<String, Object?>> validJson() async {
      final vault = await newVault(store: await FileVaultStore.open(path));
      await vault.put(VaultRecordKind.passphrase, fakePassphrase());
      return jsonDecode(await File(path).readAsString())
          as Map<String, Object?>;
    }

    Future<void> expectOpenFails(Matcher matcher) =>
        expectLater(FileVaultStore.open(path), throwsA(matcher));

    test('truncated file', () async {
      await validJson();
      final bytes = await File(path).readAsBytes();
      await File(path).writeAsBytes(bytes.sublist(0, bytes.length ~/ 2));
      await expectOpenFails(isA<VaultCorruptException>());
    });

    test('not UTF-8, not an object', () async {
      await File(path).writeAsBytes([0xff, 0xfe, 0x00]);
      await expectOpenFails(isA<VaultCorruptException>());
      await File(path).writeAsString('[]');
      await expectOpenFails(isA<VaultCorruptException>());
    });

    test('unknown file version', () async {
      final json = await validJson();
      json['fileVersion'] = 99;
      await File(path).writeAsString(jsonEncode(json));
      await expectOpenFails(isA<VaultUnsupportedVersionException>());
    });

    test('bad base64, wrong types, missing fields, duplicate ids', () async {
      final valid = jsonEncode(await validJson());
      final mutations = <void Function(Map<String, Object?>)>[
        (j) => _firstRecord(j)['nonce'] = '***not base64***',
        (j) => _firstRecord(j)['kind'] = 'unknown-kind',
        (j) => _firstRecord(j)['ciphertext'] = 42,
        (j) => (j['metadata']! as Map<String, Object?>).remove('vaultId'),
        (j) => (j['passwordSlot']! as Map<String, Object?>)['memoryKiB'] = '1',
        (j) => j['records'] = 'nope',
        (j) => (j['records']! as List<Object?>).add(_firstRecord(j)),
      ];
      for (final mutate in mutations) {
        final json = jsonDecode(valid) as Map<String, Object?>;
        mutate(json);
        await File(path).writeAsString(jsonEncode(json));
        await expectOpenFails(isA<VaultCorruptException>());
      }
    });
  });

  test('JSON helpers round-trip records, slots and metadata', () async {
    final store = InMemoryVaultStore();
    final vault = await newVault(store: store);
    final id = await vault.put(VaultRecordKind.sshKey, fakeSshKey());
    final record = (await store.readRecord(id))!;
    final slot = (await store.readPasswordSlot())!;
    final metadata = (await store.readMetadata())!;

    final record2 = VaultRecord.fromJson(jsonDecode(jsonEncode(record)));
    expect(
      [record2.id, record2.kind, record2.nonce, record2.ciphertext],
      [record.id, record.kind, record.nonce, record.ciphertext],
    );
    final slot2 = PasswordSlot.fromJson(jsonDecode(jsonEncode(slot)));
    expect(
      [slot2.salt, slot2.params, slot2.nonce, slot2.wrappedKey],
      [slot.salt, slot.params, slot.nonce, slot.wrappedKey],
    );
    final metadata2 = VaultMetadata.fromJson(jsonDecode(jsonEncode(metadata)));
    expect(
      [
        metadata2.formatVersion,
        metadata2.vaultId,
        metadata2.keyCheckNonce,
        metadata2.keyCheck,
        metadata2.biometricSlotEnrolled,
      ],
      [
        metadata.formatVersion,
        metadata.vaultId,
        metadata.keyCheckNonce,
        metadata.keyCheck,
        metadata.biometricSlotEnrolled,
      ],
    );
    expect(record.toJson()['kind'], 'ssh-key');
  });
}

Map<String, Object?> _firstRecord(Map<String, Object?> json) =>
    (json['records']! as List<Object?>).first! as Map<String, Object?>;
