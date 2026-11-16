import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/tweetnacl.dart';

import 'ssh_key.dart';
import 'ssh_key_errors.dart';

const _convertHint =
    'Convert it with "ssh-keygen -p -f <keyfile>" and import it again.';
const _minRsaBits = 2048;
const _maxRsaBits = 16384;
const _pemCiphers = {
  'AES-128-CBC',
  'AES-192-CBC',
  'AES-256-CBC',
  'AES-128-CTR',
  'AES-192-CTR',
  'AES-256-CTR',
};

final _beginLine = RegExp(
  r'^-----BEGIN ([A-Z0-9 ]+)-----[ \t\r]*$',
  multiLine: true,
);
final _publicLine = RegExp(r'^\s*(ssh-|ecdsa-|sk-)\S*\s+AAAA');

/// Creates and imports SSH user keys; all results carry unencrypted OpenSSH PEM.
final class SshKeyService {
  const SshKeyService();

  SshKey generateEd25519({String comment = ''}) {
    final seed = TweetNaCl.randombytes(32);
    final secret = Uint8List(64);
    final public = Uint8List(32);
    try {
      TweetNaCl.crypto_sign_keypair(public, secret, seed);
      return _record(
        OpenSSHEd25519KeyPair(public, secret, cleanKeyComment(comment)),
      );
    } finally {
      seed.fillRange(0, seed.length, 0);
      secret.fillRange(0, secret.length, 0);
    }
  }

  /// Imports an OpenSSH, PKCS#1 RSA or SEC1 EC private key file.
  ///
  /// Throws a [SshKeyException] subtype when the file cannot be used.
  SshKey importOpenSsh(Uint8List keyFile, {Uint8List? passphrase}) =>
      _record(_decode(keyFile, passphrase));

  /// dartssh2 identity for a stored [SshKey.privateKeyPem].
  SSHKeyPair identityFromPem(Uint8List privateKeyPem) =>
      _decode(privateKeyPem, null);

  SshKey _record(OpenSSHKeyPair pair) {
    final blob = pair.toPublicKey().encode();
    final type = SshKeyType.fromWireName(SSHHostKey.getType(blob))!;
    final comment = cleanKeyComment(pair.comment ?? '');
    return SshKey(
      type: type,
      bits: _bits(pair),
      comment: comment,
      publicLine: sshPublicLine(blob, comment: comment),
      fingerprint: sshFingerprint(blob),
      privateKeyPem: ascii.encode(pair.toPem()),
    );
  }

  OpenSSHKeyPair _decode(Uint8List keyFile, Uint8List? passphrase) {
    final text = latin1.decode(keyFile);
    if (_publicLine.hasMatch(text) || text.contains('BEGIN SSH2 PUBLIC KEY')) {
      throw const NotAPrivateKeyException();
    }
    if (text.trimLeft().startsWith('PuTTY-User-Key-File-')) {
      throw const UnsupportedKeyException(
        'PuTTY keys are not supported. In PuTTYgen use '
        '"Conversions > Export OpenSSH key" and import that file.',
      );
    }
    final begin = _beginLine.firstMatch(text);
    if (begin == null) throw const MalformedKeyException();
    final label = begin.group(1)!;
    final footer = '-----END $label-----';
    final end = text.indexOf(footer, begin.end);
    if (end < 0) {
      throw const MalformedKeyException('The key file is incomplete.');
    }
    final block = text.substring(begin.start, end + footer.length);

    final pair = switch (label) {
      'OPENSSH PRIVATE KEY' => _openSsh(block, passphrase),
      'RSA PRIVATE KEY' => _pkcs1(block, passphrase),
      'EC PRIVATE KEY' => _sec1(block),
      'PRIVATE KEY' ||
      'ENCRYPTED PRIVATE KEY' => throw const UnsupportedKeyException(
        'PKCS#8 key files are not supported. $_convertHint',
      ),
      'DSA PRIVATE KEY' => throw const UnsupportedKeyException(
        'DSA keys are not supported. Use an Ed25519, RSA or ECDSA key.',
      ),
      'PUBLIC KEY' || 'RSA PUBLIC KEY' => throw const NotAPrivateKeyException(),
      _ => throw UnsupportedKeyException(
        'Unsupported key file type "$label". $_convertHint',
      ),
    };
    _checkConsistent(pair);
    return pair;
  }

  OpenSSHKeyPair _openSsh(String block, Uint8List? passphrase) {
    final OpenSSHKeyPairs file;
    final String keyType;
    try {
      file = OpenSSHKeyPairs.decode(SSHPem.decode(block).content);
      keyType = SSHHostKey.getType(file.publicKeys.single);
    } on UnsupportedError {
      throw const UnsupportedKeyException(
        'Unsupported key encryption. $_convertHint',
      );
    } catch (_) {
      throw const MalformedKeyException();
    }
    if (SshKeyType.fromWireName(keyType) == null) {
      throw UnsupportedKeyException(
        'Unsupported key type "$keyType". Use an Ed25519, RSA or ECDSA key.',
      );
    }
    final encrypted = file.isEncrypted;
    if (encrypted) {
      final cipher = SSHCipherType.fromName(file.cipherName);
      if (cipher == null || cipher.isAead || file.kdfName != 'bcrypt') {
        throw UnsupportedKeyException(
          'Unsupported key encryption "${file.cipherName}". $_convertHint',
        );
      }
      if (passphrase == null) throw const KeyPassphraseRequiredException();
    }

    final List<SSHKeyPair> pairs;
    try {
      pairs = file.getPrivateKeys(encrypted ? _utf8(passphrase!) : null);
    } on SSHKeyDecryptError {
      if (encrypted) throw const WrongKeyPassphraseException();
      throw const MalformedKeyException();
    } on SshKeyException {
      rethrow;
    } catch (_) {
      throw const MalformedKeyException();
    }
    final pair = pairs.single;
    if (pair is! OpenSSHKeyPair ||
        !pair.toPublicKey().encode().equals(file.publicKeys.single)) {
      throw const MalformedKeyException(
        'The private and public parts of the key do not match.',
      );
    }
    return pair;
  }

  OpenSSHKeyPair _pkcs1(String block, Uint8List? passphrase) {
    final RsaKeyPair file;
    try {
      file = RsaKeyPair.decode(SSHPem.decode(block));
    } catch (_) {
      throw const MalformedKeyException();
    }
    final encrypted = file.isEncrypted;
    if (encrypted) {
      if (!_pemCiphers.contains(file.dekInfo!.algorithm.toUpperCase())) {
        throw UnsupportedKeyException(
          'Unsupported key encryption "${file.dekInfo!.algorithm}". '
          '$_convertHint',
        );
      }
      if (passphrase == null) throw const KeyPassphraseRequiredException();
    }
    final secret = encrypted ? _utf8(passphrase!) : null;
    final RsaPrivateKey key;
    try {
      key = file.getPrivateKeys(secret);
    } catch (_) {
      throw encrypted
          ? const WrongKeyPassphraseException()
          : const MalformedKeyException();
    }
    // Legacy PEM has no check bytes; a wrong passphrase shows up as bad numbers.
    if (encrypted && key.p * key.q != key.n) {
      throw const WrongKeyPassphraseException();
    }
    return OpenSSHRsaKeyPair(
      key.n,
      key.e,
      key.d,
      key.coefficient,
      key.p,
      key.q,
      '',
    );
  }

  OpenSSHKeyPair _sec1(String block) {
    final EcKeyPair file;
    try {
      file = EcKeyPair.decode(SSHPem.decode(block));
    } catch (_) {
      throw const MalformedKeyException();
    }
    if (file.isEncrypted) {
      throw const UnsupportedKeyException(
        'Encrypted "EC PRIVATE KEY" files are not supported. $_convertHint',
      );
    }
    try {
      return file.getPrivateKeys();
    } on UnsupportedError {
      throw const UnsupportedKeyException(
        'Unsupported ECDSA curve. Use nistp256, nistp384 or nistp521.',
      );
    } catch (_) {
      throw const MalformedKeyException();
    }
  }

  void _checkConsistent(OpenSSHKeyPair pair) {
    switch (pair) {
      case OpenSSHEd25519KeyPair(:final publicKey, :final privateKey):
        if (publicKey.length != 32 || privateKey.length != 64) {
          throw const MalformedKeyException();
        }
        final derivedPublic = Uint8List(32);
        final derivedSecret = Uint8List(64);
        TweetNaCl.crypto_sign_keypair(
          derivedPublic,
          derivedSecret,
          Uint8List.sublistView(privateKey, 0, 32),
        );
        derivedSecret.fillRange(0, 64, 0);
        if (!derivedPublic.equals(publicKey) ||
            !Uint8List.sublistView(privateKey, 32).equals(publicKey)) {
          throw const MalformedKeyException(
            'The private and public parts of the key do not match.',
          );
        }
      case OpenSSHRsaKeyPair(:final n, :final e, :final d, :final p, :final q):
        final bits = n.bitLength;
        if (bits < _minRsaBits || bits > _maxRsaBits) {
          throw UnsupportedKeyException(
            'RSA keys must have $_minRsaBits to $_maxRsaBits bits; '
            'this one has $bits.',
          );
        }
        if (p <= BigInt.one || q <= BigInt.one || p * q != n) {
          throw const MalformedKeyException();
        }
        final p1 = p - BigInt.one;
        final q1 = q - BigInt.one;
        if ((e * d) % (p1 * q1 ~/ p1.gcd(q1)) != BigInt.one) {
          throw const MalformedKeyException();
        }
      case OpenSSHEcdsaKeyPair(:final name, :final curveId, :final q, :final d):
        if (SshKeyType.fromWireName(name) == null) {
          throw UnsupportedKeyException('Unsupported key type "$name".');
        }
        if (!_ecdsaPublicPoint(curveId, d).equals(q)) {
          throw const MalformedKeyException(
            'The private and public parts of the key do not match.',
          );
        }
      default:
        throw const UnsupportedKeyException('Unsupported key type.');
    }
  }

  /// d·G, computed by dartssh2's SEC1 decoder from a key blob that carries no public point.
  Uint8List _ecdsaPublicPoint(String curveId, BigInt d) {
    final (oid, size) = switch (curveId) {
      'nistp256' => (const [0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07], 32),
      'nistp384' => (const [0x2b, 0x81, 0x04, 0x00, 0x22], 48),
      'nistp521' => (const [0x2b, 0x81, 0x04, 0x00, 0x23], 66),
      _ => throw UnsupportedKeyException('Unsupported ECDSA curve "$curveId".'),
    };
    if (d <= BigInt.zero || d.bitLength > size * 8) {
      throw const MalformedKeyException();
    }
    // SEQUENCE { INTEGER 1, OCTET STRING d, [0] { OID curve } }
    final bodyLength = 3 + 2 + size + 2 + 2 + oid.length;
    final der = Uint8List(2 + bodyLength);
    var at = 0;
    for (final b in [0x30, bodyLength, 0x02, 0x01, 0x01, 0x04, size]) {
      der[at++] = b;
    }
    for (var i = 0, v = d; i < size; i++, v >>= 8) {
      der[at + size - 1 - i] = (v & _byteMask).toInt();
    }
    at += size;
    for (final b in [0xa0, 2 + oid.length, 0x06, oid.length, ...oid]) {
      der[at++] = b;
    }
    try {
      return EcKeyPair(null, der).getPrivateKeys().q;
    } catch (_) {
      throw const MalformedKeyException();
    } finally {
      der.fillRange(0, der.length, 0);
    }
  }

  static final _byteMask = BigInt.from(0xff);

  int _bits(OpenSSHKeyPair pair) => switch (pair) {
    OpenSSHRsaKeyPair(:final n) => n.bitLength,
    OpenSSHEcdsaKeyPair(:final curveId) => switch (curveId) {
      'nistp384' => 384,
      'nistp521' => 521,
      _ => 256,
    },
    _ => 256,
  };

  // dartssh2 only takes passphrases as String.
  String _utf8(Uint8List passphrase) {
    try {
      return utf8.decode(passphrase);
    } on FormatException {
      throw const WrongKeyPassphraseException();
    }
  }
}
