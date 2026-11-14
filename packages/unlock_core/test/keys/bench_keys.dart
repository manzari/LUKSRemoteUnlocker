// Writes the keys for bench_auth_test.dart; run by tool/keys_bench_test.sh.
import 'dart:io';

import 'package:unlock_core/keys.dart';

import 'keygen.dart';

/// Key files named `<name>.key` with `<name>.key.pub`; `_enc` means encrypted.
Future<void> main(List<String> args) async {
  final dir = Directory(args.single)..createSync(recursive: true);
  final kg = Keygen(dir);

  final generated = const SshKeyService().generateEd25519(
    comment: 'keys-bench-generated',
  );
  File(kg.path('generated_ed25519.key'))
      .writeAsBytesSync(generated.privateKeyPem);
  File(kg.path('generated_ed25519.key.pub'))
      .writeAsStringSync('${generated.publicLine}\n');

  const types = [
    ('ed25519', 'ed25519', null),
    ('rsa2048', 'rsa', 2048),
    ('rsa4096', 'rsa', 4096),
    ('ecdsa256', 'ecdsa', 256),
    ('ecdsa384', 'ecdsa', 384),
    ('ecdsa521', 'ecdsa', 521),
  ];
  for (final (name, type, bits) in types) {
    for (final encrypted in [false, true]) {
      final file = '$name${encrypted ? '_enc' : ''}';
      await kg.newKey(
        type,
        bits: bits,
        passphrase: encrypted ? fakeKeyPass : '',
        comment: 'keys-bench-$file',
        name: '$file.key',
      );
    }
  }
  await kg.newKey(
    'rsa',
    bits: 3072,
    format: 'PEM',
    passphrase: fakeKeyPass,
    name: 'rsa3072_pem_enc.key',
  );
  await kg.newKey('ecdsa', bits: 256, format: 'PEM', name: 'ecdsa256_pem.key');
  stdout.writeln('Wrote bench keys to ${dir.path}');
}
