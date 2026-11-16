import 'dart:convert';
import 'dart:typed_data';

import 'vault_exceptions.dart';

enum VaultRecordKind {
  sshKey('ssh-key'),
  passphrase('passphrase');

  const VaultRecordKind(this.wireName);

  final String wireName;

  static VaultRecordKind fromWireName(String name) {
    for (final kind in values) {
      if (kind.wireName == name) {
        return kind;
      }
    }
    throw const VaultCorruptException('malformed vault data: record.kind');
  }
}

final class VaultRecord {
  const VaultRecord({
    required this.id,
    required this.kind,
    required this.nonce,
    required this.ciphertext,
  });

  factory VaultRecord.fromJson(Object? json) {
    final map = _JsonMap(json, 'record');
    return VaultRecord(
      id: map.string('id'),
      kind: VaultRecordKind.fromWireName(map.string('kind')),
      nonce: map.bytes('nonce'),
      ciphertext: map.bytes('ciphertext'),
    );
  }

  final String id;
  final VaultRecordKind kind;
  final Uint8List nonce;

  /// XChaCha20 ciphertext followed by the 16-byte Poly1305 tag.
  final Uint8List ciphertext;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.wireName,
    'nonce': base64.encode(nonce),
    'ciphertext': base64.encode(ciphertext),
  };

  @override
  String toString() => 'VaultRecord($id, ${kind.wireName})';
}

final class Argon2Params {
  const Argon2Params({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  /// For new slots; existing slots keep the params stored with them.
  static const Argon2Params defaults = Argon2Params(
    memoryKiB: 65536,
    iterations: 3,
    parallelism: 1,
  );

  /// 256 MiB, which a phone can still allocate.
  static const int maxMemoryKiB = 1 << 18;
  static const int maxIterations = 64;
  static const int maxParallelism = 16;

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  /// Sanity bounds, so a tampered slot cannot exhaust memory or CPU before failing.
  bool get isWithinBounds =>
      parallelism >= 1 &&
      parallelism <= maxParallelism &&
      iterations >= 1 &&
      iterations <= maxIterations &&
      memoryKiB >= 8 * parallelism &&
      memoryKiB <= maxMemoryKiB;

  @override
  bool operator ==(Object other) =>
      other is Argon2Params &&
      other.memoryKiB == memoryKiB &&
      other.iterations == iterations &&
      other.parallelism == parallelism;

  @override
  int get hashCode => Object.hash(memoryKiB, iterations, parallelism);

  @override
  String toString() =>
      'Argon2Params(m=$memoryKiB KiB, t=$iterations, p=$parallelism)';
}

final class PasswordSlot {
  const PasswordSlot({
    required this.salt,
    required this.params,
    required this.nonce,
    required this.wrappedKey,
  });

  factory PasswordSlot.fromJson(Object? json) {
    final map = _JsonMap(json, 'passwordSlot');
    return PasswordSlot(
      salt: map.bytes('salt'),
      params: Argon2Params(
        memoryKiB: map.integer('memoryKiB'),
        iterations: map.integer('iterations'),
        parallelism: map.integer('parallelism'),
      ),
      nonce: map.bytes('nonce'),
      wrappedKey: map.bytes('wrappedKey'),
    );
  }

  final Uint8List salt;
  final Argon2Params params;
  final Uint8List nonce;

  /// Vault key encrypted under the Argon2id KEK, followed by the 16-byte tag.
  final Uint8List wrappedKey;

  Map<String, Object?> toJson() => {
    'salt': base64.encode(salt),
    'memoryKiB': params.memoryKiB,
    'iterations': params.iterations,
    'parallelism': params.parallelism,
    'nonce': base64.encode(nonce),
    'wrappedKey': base64.encode(wrappedKey),
  };

  @override
  String toString() => 'PasswordSlot($params)';
}

final class VaultMetadata {
  const VaultMetadata({
    required this.formatVersion,
    required this.vaultId,
    required this.keyCheckNonce,
    required this.keyCheck,
    required this.biometricSlotEnrolled,
  });

  factory VaultMetadata.fromJson(Object? json) {
    final map = _JsonMap(json, 'metadata');
    return VaultMetadata(
      formatVersion: map.integer('formatVersion'),
      vaultId: map.string('vaultId'),
      keyCheckNonce: map.bytes('keyCheckNonce'),
      keyCheck: map.bytes('keyCheck'),
      biometricSlotEnrolled: map.boolean('biometricSlotEnrolled'),
    );
  }

  final int formatVersion;
  final String vaultId;

  /// AEAD of an empty message under the vault key; proves a candidate key belongs to this vault.
  final Uint8List keyCheckNonce;
  final Uint8List keyCheck;

  /// Stays true after the platform invalidates the slot: tells "never enrolled" from "invalidated".
  final bool biometricSlotEnrolled;

  VaultMetadata copyWith({bool? biometricSlotEnrolled}) => VaultMetadata(
    formatVersion: formatVersion,
    vaultId: vaultId,
    keyCheckNonce: keyCheckNonce,
    keyCheck: keyCheck,
    biometricSlotEnrolled: biometricSlotEnrolled ?? this.biometricSlotEnrolled,
  );

  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'vaultId': vaultId,
    'keyCheckNonce': base64.encode(keyCheckNonce),
    'keyCheck': base64.encode(keyCheck),
    'biometricSlotEnrolled': biometricSlotEnrolled,
  };

  @override
  String toString() => 'VaultMetadata(v$formatVersion, $vaultId)';
}

final class _JsonMap {
  _JsonMap(Object? json, this._what)
    : _map = json is Map<String, Object?> ? json : null;

  final Map<String, Object?>? _map;
  final String _what;

  Object? _field(String key) {
    final map = _map;
    if (map == null) {
      throw VaultCorruptException('malformed vault data: $_what');
    }
    return map[key];
  }

  VaultCorruptException _malformed(String key) =>
      VaultCorruptException('malformed vault data: $_what.$key');

  String string(String key) {
    final value = _field(key);
    return value is String ? value : throw _malformed(key);
  }

  int integer(String key) {
    final value = _field(key);
    return value is int ? value : throw _malformed(key);
  }

  bool boolean(String key) {
    final value = _field(key);
    return value is bool ? value : throw _malformed(key);
  }

  Uint8List bytes(String key) {
    try {
      return base64.decode(string(key));
    } on FormatException {
      throw _malformed(key);
    }
  }
}
