import 'package:meta/meta.dart';

/// An SSH server host key, identified by key type and SHA-256 fingerprint.
@immutable
final class HostKey {
  /// [type] is a key type such as `ssh-ed25519`; null when only the fingerprint is known.
  HostKey(String? type, this.fingerprint)
    : type = type == null ? null : normalizeType(type) {
    if (!_fingerprint.hasMatch(fingerprint)) {
      throw FormatException('Not a SHA256 fingerprint', fingerprint);
    }
  }

  static final _fingerprint = RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$');

  final String? type;

  /// `SHA256:<base64 without padding>`, as printed by `ssh-keygen -l`.
  final String fingerprint;

  /// Parses `SHA256:...` or `<type> SHA256:...`.
  factory HostKey.parse(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    return switch (parts) {
      [final fp] => HostKey(null, fp),
      [final type, final fp] => HostKey(type, fp),
      _ => throw FormatException('Expected "[type] SHA256:..."', text),
    };
  }

  factory HostKey.fromJson(Map<String, Object?> json) =>
      HostKey(json['type'] as String?, json['fingerprint']! as String);

  Map<String, Object?> toJson() => {'type': type, 'fingerprint': fingerprint};

  /// Maps signature algorithm names to the key type they belong to.
  static String normalizeType(String algorithm) => switch (algorithm) {
    'rsa-sha2-256' || 'rsa-sha2-512' => 'ssh-rsa',
    _ => algorithm,
  };

  /// Same key; a missing type on either side matches any type.
  bool matches(HostKey other) =>
      fingerprint == other.fingerprint &&
      (type == null || other.type == null || type == other.type);

  @override
  bool operator ==(Object other) =>
      other is HostKey &&
      other.type == type &&
      other.fingerprint == fingerprint;

  @override
  int get hashCode => Object.hash(type, fingerprint);

  @override
  String toString() => type == null ? fingerprint : '$type $fingerprint';
}
