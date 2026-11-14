import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/drift_vault_store.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/key_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/harness.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('app_db_'));
  tearDown(() => dir.delete(recursive: true));

  test(
    'data survives close and reopen; the file holds no plaintext secret',
    () async {
      final file = File('${dir.path}/app.sqlite');
      final passphrase = bytesOf(fakePassphraseText);
      final generated = const SshKeyService().generateEd25519(comment: 'fake');
      final privatePem = Uint8List.fromList(generated.privateKeyPem);

      var db = fileDatabase(file);
      var hosts = HostRepository(db);
      final vault = await Vault.create(DriftVaultStore(db), kdf: fakeKdf);
      await vault.setPassword(bytesOf(fakeMasterPassword), params: fastParams);
      final key = await KeyRepository(
        db,
        hosts,
      ).add(vault, generated, label: 'laptop');
      final secret = await SecretRepository(
        db,
        hosts,
      ).add(vault, label: 'root disk', passphrase: passphrase);
      final host = Host(
        id: 'h1',
        name: 'alpha',
        group: 'home',
        preboot: [const Endpoint('192.0.2.10', 2222)],
        keyId: key.id,
        secretId: secret.id,
        prebootKey: HostKey.parse(
          'SHA256:TEvtlX/GczN0Jf70vMKaeCELsAQ3MJIrRfoKEG+DgbM',
        ),
      );
      await hosts.save(host);
      vault.lock();
      await db.close();

      db = fileDatabase(file);
      hosts = HostRepository(db);
      expect(await hosts.get('h1'), host);
      final keys = KeyRepository(db, hosts);
      final secrets = SecretRepository(db, hosts);
      expect((await keys.get(key.id))!.publicLine, generated.publicLine);
      expect((await secrets.get(secret.id))!.label, 'root disk');

      final reopened = await Vault.open(DriftVaultStore(db), kdf: fakeKdf);
      expect(reopened.isUnlocked, isFalse);
      await reopened.unlockWithPassword(bytesOf(fakeMasterPassword));
      expect(await secrets.reveal(reopened, secret.id), passphrase);
      expect(await keys.privateKeyPem(reopened, key.id), privatePem);
      await db.close();

      final bytes = file.readAsBytesSync();
      expect(indexOfBytes(bytes, bytesOf('root disk')), isNot(-1));
      expectNotInBytes(bytes, passphrase, 'passphrase');
      expectNotInBytes(bytes, bytesOf(fakeMasterPassword), 'master password');
      expectNotInBytes(
        bytes,
        Uint8List.sublistView(privatePem, 40, privatePem.length - 40),
        'private key',
      );
      for (final f in dir.listSync()) {
        expect(f.path, file.path, reason: 'no journal or WAL left behind');
      }
    },
  );
}
