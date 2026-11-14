@Tags(['bench'])
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:test/test.dart';
import 'package:unlock_core/keys.dart';

import 'keygen.dart';

final _env = Platform.environment;
final _enabled = _env['BENCH'] == '1';
final _host = _env['BENCH_HOST'] ?? 'target3';
final _port = int.parse(_env['BENCH_PORT'] ?? '2222');
final _dir = _env['KEYS_BENCH_DIR'] ?? '.dart_tool/keys_bench';

const service = SshKeyService();

/// Logs in as root and disconnects; returns the server's `server-sig-algs`.
Future<List<String>?> login(SSHKeyPair identity) async {
  final client = SSHClient(
    await SSHSocket.connect(_host, _port, timeout: const Duration(seconds: 10)),
    username: 'root',
    identities: [identity],
    onVerifyHostKey: (_, _) => true,
    authTimeout: const Duration(seconds: 20),
  );
  try {
    await client.authenticated;
    return client.serverSigAlgs;
  } finally {
    await client.close();
  }
}

String _keyPart(String line) => line.split(' ').take(2).join(' ');

List<File> _keyFiles() {
  final dir = Directory(_dir);
  if (!_enabled || !dir.existsSync()) return [];
  return dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.key'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

void main() {
  group(
    'bench login',
    () {
      final keys = _keyFiles();

      test('key files are present', () {
        expect(keys, hasLength(greaterThanOrEqualTo(15)), reason: _dir);
      });

      for (final file in keys) {
        final name = file.uri.pathSegments.last;
        test(name, () async {
          final passphrase = name.contains('_enc')
              ? Uint8List.fromList(utf8.encode(fakeKeyPass))
              : null;
          final key = service.importOpenSsh(
            file.readAsBytesSync(),
            passphrase: passphrase,
          );
          final authorized = File('${file.path}.pub').readAsStringSync();
          expect(_keyPart(key.publicLine), _keyPart(authorized.trim()));

          final identity = service.identityFromPem(key.privateKeyPem);
          final sigAlgs = await login(identity);
          if (key.type == SshKeyType.rsa) {
            expect(identity.type, 'rsa-sha2-256');
            if (sigAlgs != null) expect(sigAlgs, contains('rsa-sha2-256'));
          }
        }, timeout: const Timeout(Duration(minutes: 1)));
      }

      test('an unauthorized generated key is refused', () async {
        final key = service.generateEd25519(comment: 'not-authorized');
        await expectLater(
          login(service.identityFromPem(key.privateKeyPem)),
          throwsA(isA<SSHAuthFailError>()),
        );
      });
    },
    skip: _enabled
        ? false
        : 'needs the bench: run packages/unlock_core/tool/keys_bench_test.sh',
  );
}
