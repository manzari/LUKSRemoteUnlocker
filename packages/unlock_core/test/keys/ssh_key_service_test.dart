@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:test/test.dart';
import 'package:unlock_core/keys.dart';

import 'keygen.dart';

const service = SshKeyService();

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

final fakePass = bytes(fakeKeyPass);

typedef Spec = ({String name, String type, int? bits, SshKeyType expected});

const specs = <Spec>[
  (name: 'ed25519', type: 'ed25519', bits: null, expected: SshKeyType.ed25519),
  (name: 'rsa 2048', type: 'rsa', bits: 2048, expected: SshKeyType.rsa),
  (name: 'rsa 4096', type: 'rsa', bits: 4096, expected: SshKeyType.rsa),
  (name: 'ecdsa 256', type: 'ecdsa', bits: 256, expected: SshKeyType.ecdsaP256),
  (name: 'ecdsa 384', type: 'ecdsa', bits: 384, expected: SshKeyType.ecdsaP384),
  (name: 'ecdsa 521', type: 'ecdsa', bits: 521, expected: SshKeyType.ecdsaP521),
];

void main() {
  late Keygen kg;
  setUpAll(() => kg = Keygen.create());
  tearDownAll(() => kg.dispose());

  /// Checks [key] against ssh-keygen's view of [file] and of the stored PEM.
  Future<void> expectMatchesKeygen(
    SshKey key,
    String file, {
    String passphrase = '',
  }) async {
    expect(key.publicLine, await kg.publicLine(file, passphrase: passphrase));
    expect(key.fingerprint, await kg.fingerprint(file));
    await expectStoredPemSound(kg, key);
  }

  group('generateEd25519', () {
    test('public line and fingerprint match ssh-keygen', () async {
      final key = service.generateEd25519(comment: 'phone@luks');
      expect(key.type, SshKeyType.ed25519);
      expect(key.bits, 256);
      expect(key.comment, 'phone@luks');
      expect(key.publicLine, startsWith('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5'));
      expect(key.publicLine, endsWith(' phone@luks'));

      final file = await kg.writePrivate(key.privateKeyPem);
      expect(await kg.publicLine(file), key.publicLine);
      expect(await kg.fingerprint(file), key.fingerprint);
      await expectStoredPemSound(kg, key);
    });

    test('each call makes a new key', () {
      final a = service.generateEd25519();
      final b = service.generateEd25519();
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('empty comment gives a two-field line', () async {
      final key = service.generateEd25519();
      expect(key.publicLine.split(' '), hasLength(2));
      final file = await kg.writePrivate(key.privateKeyPem);
      expect(await kg.publicLine(file), key.publicLine);
    });

    test('line breaks in the comment are dropped', () {
      final key = service.generateEd25519(comment: 'a\nb\r\n');
      expect(key.comment, 'a b');
      expect(key.publicLine, endsWith(' a b'));
    });

    test('toString does not include the private key', () {
      final key = service.generateEd25519();
      expect(key.toString(), isNot(contains('PRIVATE')));
      expect(key.toString(), contains(key.fingerprint));
    });
  });

  group('importOpenSsh', () {
    for (final spec in specs) {
      group(spec.name, () {
        test('unencrypted', () async {
          final file = await kg.newKey(spec.type, bits: spec.bits);
          final key = service.importOpenSsh(kg.read(file));
          expect(key.type, spec.expected);
          expect(key.bits, spec.bits ?? 256);
          expect(key.comment, 'test-key');
          await expectMatchesKeygen(key, file);
        });

        test('unencrypted, passphrase given anyway', () async {
          final file = await kg.newKey(spec.type, bits: spec.bits);
          final key = service.importOpenSsh(
            kg.read(file),
            passphrase: fakePass,
          );
          await expectMatchesKeygen(key, file);
        });

        test('encrypted', () async {
          final file = await kg.newKey(
            spec.type,
            bits: spec.bits,
            passphrase: fakeKeyPass,
          );
          final pem = kg.read(file);
          expect(
            () => service.importOpenSsh(pem),
            throwsA(isA<KeyPassphraseRequiredException>()),
          );
          expect(
            () => service.importOpenSsh(pem, passphrase: bytes('wrong-pass')),
            throwsA(isA<WrongKeyPassphraseException>()),
          );
          final key = service.importOpenSsh(pem, passphrase: fakePass);
          expect(key.type, spec.expected);
          await expectMatchesKeygen(key, file, passphrase: fakeKeyPass);
        });

        if (spec.type != 'ed25519') {
          test('legacy PEM, unencrypted', () async {
            final file = await kg.newKey(
              spec.type,
              bits: spec.bits,
              format: 'PEM',
            );
            final key = service.importOpenSsh(kg.read(file));
            expect(key.type, spec.expected);
            expect(key.comment, isEmpty);
            await expectMatchesKeygen(key, file);
          });
        }
      });
    }

    test('legacy RSA PEM, encrypted', () async {
      final file = await kg.newKey(
        'rsa',
        bits: 2048,
        format: 'PEM',
        passphrase: fakeKeyPass,
      );
      final pem = kg.read(file);
      expect(latin1.decode(pem), contains('DEK-Info: AES-128-CBC'));
      expect(
        () => service.importOpenSsh(pem),
        throwsA(isA<KeyPassphraseRequiredException>()),
      );
      for (final wrong in ['wrong-pass', 'x', '']) {
        expect(
          () => service.importOpenSsh(pem, passphrase: bytes(wrong)),
          throwsA(isA<WrongKeyPassphraseException>()),
        );
      }
      final key = service.importOpenSsh(pem, passphrase: fakePass);
      await expectMatchesKeygen(key, file, passphrase: fakeKeyPass);
    });

    test('legacy EC PEM, encrypted, is rejected with a hint', () async {
      final file = await kg.newKey(
        'ecdsa',
        bits: 256,
        format: 'PEM',
        passphrase: fakeKeyPass,
      );
      expect(
        () => service.importOpenSsh(kg.read(file), passphrase: fakePass),
        throwsA(
          isA<UnsupportedKeyException>().having(
            (e) => e.message,
            'message',
            contains('ssh-keygen -p'),
          ),
        ),
      );
    });

    test('Windows line endings and surrounding text are accepted', () async {
      final file = await kg.newKey('ed25519');
      final text = File(file).readAsStringSync().replaceAll('\n', '\r\n');
      final key = service.importOpenSsh(bytes('\r\n\r\n$text\r\n'));
      await expectMatchesKeygen(key, file);
    });
  });

  group('import errors', () {
    void expectThrows<T extends SshKeyException>(
      Uint8List file, {
      Uint8List? passphrase,
    }) {
      expect(
        () => service.importOpenSsh(file, passphrase: passphrase),
        throwsA(isA<T>()),
      );
    }

    test('garbage', () {
      final random = Random(7);
      expectThrows<MalformedKeyException>(
        Uint8List.fromList(List.generate(512, (_) => random.nextInt(256))),
      );
      expectThrows<MalformedKeyException>(Uint8List(0));
      expectThrows<MalformedKeyException>(bytes('hello world'));
      expectThrows<MalformedKeyException>(
        bytes(
          '-----BEGIN OPENSSH PRIVATE KEY-----\n'
          'not base64 at all!\n'
          '-----END OPENSSH PRIVATE KEY-----\n',
        ),
      );
      expectThrows<MalformedKeyException>(
        bytes(
          '-----BEGIN OPENSSH PRIVATE KEY-----\n'
          '${base64.encode(List.filled(90, 1))}\n'
          '-----END OPENSSH PRIVATE KEY-----\n',
        ),
      );
    });

    test('truncated file', () async {
      final text = File(await kg.newKey('ed25519')).readAsStringSync();
      expectThrows<MalformedKeyException>(
        bytes(text.substring(0, text.length ~/ 2)),
      );
      final lines = text.trim().split('\n');
      lines.removeAt(2);
      expectThrows<MalformedKeyException>(bytes(lines.join('\n')));
    });

    test('public key files', () async {
      final file = await kg.newKey('ed25519');
      final pub = '$file.pub';
      expectThrows<NotAPrivateKeyException>(kg.read(pub));
      expectThrows<NotAPrivateKeyException>(
        bytes(await kg.run(['-e', '-f', pub])),
      );
      final rsa = await kg.newKey('rsa', bits: 2048);
      expectThrows<NotAPrivateKeyException>(kg.read('$rsa.pub'));
      for (final format in ['PEM', 'PKCS8']) {
        expectThrows<NotAPrivateKeyException>(
          bytes(await kg.run(['-e', '-m', format, '-f', '$rsa.pub'])),
        );
      }
      final ec = await kg.newKey('ecdsa', bits: 256);
      expectThrows<NotAPrivateKeyException>(kg.read('$ec.pub'));
    });

    test('PKCS#8 private key', () async {
      final file = await kg.newKey('ecdsa', bits: 256, format: 'PKCS8');
      expect(latin1.decode(kg.read(file)), contains('BEGIN PRIVATE KEY'));
      expectThrows<UnsupportedKeyException>(kg.read(file));
    });

    test('RSA shorter than 2048 bits', () async {
      final file = await kg.newKey('rsa', bits: 1024);
      expectThrows<UnsupportedKeyException>(kg.read(file));
      final pem = await kg.newKey('rsa', bits: 1024, format: 'PEM');
      expectThrows<UnsupportedKeyException>(kg.read(pem));
    });

    test('AEAD key encryption', () async {
      final file = await kg.newKey(
        'ed25519',
        passphrase: fakeKeyPass,
        extra: ['-Z', 'chacha20-poly1305@openssh.com'],
      );
      expectThrows<UnsupportedKeyException>(
        kg.read(file),
        passphrase: fakePass,
      );
    });

    test('unknown key type in an OpenSSH container', () {
      final text = latin1.decode(service.generateEd25519().privateKeyPem);
      final raw = latin1.decode(
        base64.decode(text.split('\n').where(_body).join()),
      );
      final patched = latin1.encode(
        raw.replaceAll('ssh-ed25519', 'ssh-xx25519'),
      );
      final pem = SSHPem('OPENSSH PRIVATE KEY', {}, patched).encode(70);
      expectThrows<UnsupportedKeyException>(bytes(pem));
    });

    test('mismatched private and public parts', () {
      Uint8List raw() => base64.decode(
        latin1
            .decode(service.generateEd25519().privateKeyPem)
            .split('\n')
            .where(_body)
            .join(),
      );
      Uint8List pem(Uint8List raw) =>
          bytes(SSHPem('OPENSSH PRIVATE KEY', {}, raw).encode(70));
      final name = utf8.encode('ssh-ed25519');

      // Outer public key taken from another key.
      final a = raw();
      final b = raw();
      final outerA = _indexOf(a, name, 0) + name.length + 4;
      final outerB = _indexOf(b, name, 0) + name.length + 4;
      a.setRange(outerA, outerA + 32, b.sublist(outerB, outerB + 32));
      expectThrows<MalformedKeyException>(pem(a));

      // Seed that does not belong to the stored public key.
      final c = raw();
      final inner = _indexOf(c, name, _indexOf(c, name, 0) + 1);
      final seed = inner + name.length + 4 + 32 + 4;
      c.fillRange(seed, seed + 32, 9);
      expectThrows<MalformedKeyException>(pem(c));
    });

    test('ECDSA public point that does not belong to the scalar', () async {
      Future<OpenSSHEcdsaKeyPair> ecdsa(int bits) async {
        final text = latin1.decode(kg.read(await kg.newKey('ecdsa', bits: bits)));
        return OpenSSHKeyPairs.decode(
              SSHPem.decode(text).content,
            ).getPrivateKeys(null).single
            as OpenSSHEcdsaKeyPair;
      }

      Uint8List pem(OpenSSHEcdsaKeyPair p) => bytes(p.toPem());

      for (final bits in [256, 384, 521]) {
        final a = await ecdsa(bits);
        final b = await ecdsa(bits);
        final good = OpenSSHEcdsaKeyPair(a.curveId, a.q, a.d, 'good');
        expect(service.importOpenSsh(pem(good)).type.wireName, a.name);
        expectThrows<MalformedKeyException>(
          pem(OpenSSHEcdsaKeyPair(a.curveId, b.q, a.d, 'mixed')),
        );
        expectThrows<MalformedKeyException>(
          pem(OpenSSHEcdsaKeyPair(a.curveId, a.q, a.d + BigInt.one, 'off')),
        );
      }
    });

    test('PuTTY key', () {
      expectThrows<UnsupportedKeyException>(
        bytes('PuTTY-User-Key-File-3: ssh-ed25519\nEncryption: none\n'),
      );
    });

    test('identityFromPem rejects garbage', () {
      expect(
        () => service.identityFromPem(bytes('nope')),
        throwsA(isA<MalformedKeyException>()),
      );
    });
  });

  group('helpers', () {
    test('sshFingerprint and sshPublicLine match ssh-keygen', () async {
      final file = await kg.newKey('ecdsa', bits: 384, comment: 'two words');
      final identity = service.identityFromPem(kg.read(file));
      final blob = identity.toPublicKey().encode();
      expect(sshFingerprint(blob), await kg.fingerprint(file));
      expect(
        sshPublicLine(blob, comment: 'two words'),
        await kg.publicLine(file),
      );
    });

    test('identityFromPem signs with the expected algorithm', () {
      final ed = service.generateEd25519();
      expect(service.identityFromPem(ed.privateKeyPem).type, 'ssh-ed25519');
    });
  });
}

bool _body(String line) => line.isNotEmpty && !line.startsWith('-----');

int _indexOf(List<int> haystack, List<int> needle, int start) {
  for (var i = start; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length && match; j++) {
      match = haystack[i + j] == needle[j];
    }
    if (match) return i;
  }
  return -1;
}

/// Stored PEM is unencrypted OpenSSH, re-imports identically and ssh-keygen reads it.
Future<void> expectStoredPemSound(Keygen kg, SshKey key) async {
  final text = latin1.decode(key.privateKeyPem);
  expect(text, startsWith('-----BEGIN OPENSSH PRIVATE KEY-----\n'));
  final container = OpenSSHKeyPairs.decode(SSHPem.decode(text).content);
  expect(container.cipherName, 'none');
  expect(container.kdfName, 'none');
  expect(container.isEncrypted, isFalse);

  final again = service.importOpenSsh(key.privateKeyPem);
  expect(again.publicLine, key.publicLine);
  expect(again.fingerprint, key.fingerprint);
  expect(again.type, key.type);
  expect(again.bits, key.bits);

  final identity = service.identityFromPem(key.privateKeyPem);
  expect(sshFingerprint(identity.toPublicKey().encode()), key.fingerprint);

  final file = await kg.writePrivate(key.privateKeyPem);
  expect(await kg.publicLine(file), key.publicLine);
}
