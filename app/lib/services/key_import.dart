import 'dart:isolate';
import 'dart:typed_data';

import 'package:unlock_core/keys.dart';

/// Parses (and decrypts) an OpenSSH private key; throws an [SshKeyException] subtype.
typedef KeyImporter = Future<SshKey> Function(
  Uint8List keyFile,
  Uint8List? passphrase,
);

/// Runs the import in a short-lived isolate; bcrypt key decryption can take a second.
Future<SshKey> importKeyInIsolate(Uint8List keyFile, Uint8List? passphrase) =>
    Isolate.run(
      () =>
          const SshKeyService().importOpenSsh(keyFile, passphrase: passphrase),
    );

Future<SshKey> importKeyInline(
  Uint8List keyFile,
  Uint8List? passphrase,
) async => const SshKeyService().importOpenSsh(keyFile, passphrase: passphrase);

String describeKeyError(Object error) => switch (error) {
  SshKeyException(:final message) => message,
  _ => 'The key could not be imported.',
};
