import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'vault_models.dart';

const int vaultKeyLength = 32;
const int nonceLength = 24;
const int tagLength = 16;
const int saltLength = 16;
const int idLength = 16;

const String _recordLabel = 'luks-remote-unlocker/vault/record';
const String _passwordSlotLabel = 'luks-remote-unlocker/vault/password-slot';
const String _keyCheckLabel = 'luks-remote-unlocker/vault/key-check';

final Random _random = Random.secure();
const DartXchacha20 _aead = DartXchacha20.poly1305Aead();
final RegExp _idPattern = RegExp(r'^[0-9a-f]{32}$');

/// Derives a 32-byte key-encryption key from a password.
typedef PasswordKdf = Future<Uint8List> Function(
  Uint8List password,
  Uint8List salt,
  Argon2Params params,
);

/// Argon2id on the calling isolate; blocks it for the whole derivation.
Future<Uint8List> argon2idInline(
  Uint8List password,
  Uint8List salt,
  Argon2Params params,
) async {
  if (!params.isWithinBounds) {
    throw ArgumentError.value(params, 'params', 'out of bounds');
  }
  final state = DartArgon2id(
    parallelism: params.parallelism,
    memory: params.memoryKiB,
    iterations: params.iterations,
    hashLength: vaultKeyLength,
    maxIsolates: 0,
  ).newState();
  try {
    final derived = await state.deriveKeyBytes(password: password, nonce: salt);
    final kek = Uint8List.fromList(derived);
    derived.fillRange(0, derived.length, 0);
    return kek;
  } finally {
    state.tryReleaseMemory();
  }
}

/// Argon2id in a short-lived isolate, so the calling (UI) isolate keeps running.
Future<Uint8List> argon2idInIsolate(
  Uint8List password,
  Uint8List salt,
  Argon2Params params,
) => Isolate.run(() => argon2idInline(password, salt, params));

Uint8List randomBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = _random.nextInt(256);
  }
  return bytes;
}

String randomId() {
  final bytes = randomBytes(idLength);
  final buffer = StringBuffer();
  for (final b in bytes) {
    buffer.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

bool isValidId(String id) => _idPattern.hasMatch(id);

void zeroBytes(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);

final class SealedBox {
  const SealedBox(this.nonce, this.ciphertext);

  final Uint8List nonce;

  /// Ciphertext followed by the 16-byte Poly1305 tag.
  final Uint8List ciphertext;
}

/// XChaCha20-Poly1305 with a fresh random 24-byte nonce.
Future<SealedBox> sealBox(Uint8List key, Uint8List plaintext, Uint8List aad) =>
    sealBoxWithNonce(key, randomBytes(nonceLength), plaintext, aad);

Future<SealedBox> sealBoxWithNonce(
  Uint8List key,
  Uint8List nonce,
  Uint8List plaintext,
  Uint8List aad,
) async {
  if (key.length != vaultKeyLength || nonce.length != nonceLength) {
    throw ArgumentError('bad key or nonce length');
  }
  final box = await _aead.encrypt(
    plaintext,
    secretKey: SecretKeyData(key),
    nonce: nonce,
    aad: aad,
  );
  final out = Uint8List(box.cipherText.length + tagLength)
    ..setAll(0, box.cipherText)
    ..setAll(box.cipherText.length, box.mac.bytes);
  return SealedBox(nonce, out);
}

/// Returns null when the box fails authentication (wrong key, nonce, AAD or tampered bytes).
Future<Uint8List?> openBox(
  Uint8List key,
  Uint8List nonce,
  Uint8List sealed,
  Uint8List aad,
) async {
  if (key.length != vaultKeyLength ||
      nonce.length != nonceLength ||
      sealed.length < tagLength) {
    return null;
  }
  final split = sealed.length - tagLength;
  final box = SecretBox(
    Uint8List.sublistView(sealed, 0, split),
    nonce: nonce,
    mac: Mac(Uint8List.sublistView(sealed, split)),
  );
  try {
    final plaintext = await _aead.decrypt(
      box,
      secretKey: SecretKeyData(key),
      aad: aad,
    );
    if (plaintext is Uint8List) {
      return plaintext;
    }
    final copy = Uint8List.fromList(plaintext);
    plaintext.fillRange(0, plaintext.length, 0);
    return copy;
  } on SecretBoxAuthenticationError {
    return null;
  }
}

Uint8List recordAad({
  required int formatVersion,
  required String vaultId,
  required VaultRecordKind kind,
  required String recordId,
}) =>
    (_AadBuilder(_recordLabel, formatVersion, vaultId)
          ..addString(kind.wireName)
          ..addString(recordId))
        .build();

Uint8List passwordSlotAad({
  required int formatVersion,
  required String vaultId,
  required Argon2Params params,
  required Uint8List salt,
}) =>
    (_AadBuilder(_passwordSlotLabel, formatVersion, vaultId)
          ..addUint32(params.memoryKiB)
          ..addUint32(params.iterations)
          ..addUint32(params.parallelism)
          ..addBytes(salt))
        .build();

Uint8List keyCheckAad({required int formatVersion, required String vaultId}) =>
    _AadBuilder(_keyCheckLabel, formatVersion, vaultId).build();

/// AAD = lp(label) || u32(version) || lp(vaultId) || fields; lp = u32 big-endian length prefix.
final class _AadBuilder {
  _AadBuilder(String label, int formatVersion, String vaultId) {
    addString(label);
    addUint32(formatVersion);
    addString(vaultId);
  }

  final BytesBuilder _out = BytesBuilder();

  void addUint32(int value) {
    RangeError.checkValueInInterval(value, 0, 0xFFFFFFFF);
    _out.add((ByteData(4)..setUint32(0, value)).buffer.asUint8List());
  }

  void addBytes(Uint8List bytes) {
    addUint32(bytes.length);
    _out.add(bytes);
  }

  void addString(String value) => addBytes(utf8.encode(value));

  Uint8List build() => _out.toBytes();
}
