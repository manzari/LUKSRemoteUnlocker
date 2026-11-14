import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/digests.dart';

enum SshKeyType {
  ed25519('ssh-ed25519'),
  rsa('ssh-rsa'),
  ecdsaP256('ecdsa-sha2-nistp256'),
  ecdsaP384('ecdsa-sha2-nistp384'),
  ecdsaP521('ecdsa-sha2-nistp521');

  const SshKeyType(this.wireName);

  /// Algorithm name as written in a public key line.
  final String wireName;

  static SshKeyType? fromWireName(String name) {
    for (final type in values) {
      if (type.wireName == name) return type;
    }
    return null;
  }
}

/// A private key ready for the vault, with its public parts.
final class SshKey {
  const SshKey({
    required this.type,
    required this.bits,
    required this.comment,
    required this.publicLine,
    required this.fingerprint,
    required this.privateKeyPem,
  });

  final SshKeyType type;
  final int bits;
  final String comment;

  /// `authorized_keys` line, as printed by `ssh-keygen -y`.
  final String publicLine;

  /// `SHA256:...`, as printed by `ssh-keygen -lf`.
  final String fingerprint;

  /// Unencrypted OpenSSH private key; keep it only inside a vault record.
  final Uint8List privateKeyPem;

  @override
  String toString() => 'SshKey(${type.wireName}, $bits, $fingerprint)';
}

/// SHA-256 fingerprint of a public key blob in SSH wire format.
String sshFingerprint(Uint8List publicKeyBlob) =>
    'SHA256:${base64.encode(Hash.sha256(publicKeyBlob)).replaceAll('=', '')}';

/// `authorized_keys` line for a public key blob in SSH wire format.
String sshPublicLine(Uint8List publicKeyBlob, {String comment = ''}) {
  final type = SSHHostKey.getType(publicKeyBlob);
  final line = '$type ${base64.encode(publicKeyBlob)}';
  final clean = cleanKeyComment(comment);
  return clean.isEmpty ? line : '$line $clean';
}

/// Comment with line breaks removed, so a public line stays one line.
String cleanKeyComment(String comment) =>
    comment.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
