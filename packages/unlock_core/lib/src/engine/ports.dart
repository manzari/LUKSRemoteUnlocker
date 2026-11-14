import 'dart:async';
import 'dart:typed_data';

import '../model/endpoint.dart';
import '../model/host.dart';
import '../model/host_key.dart';

abstract interface class Reachability {
  Future<bool> tcpOpen(String host, int port, Duration timeout);
}

/// Decides on the host key during key exchange; the connection waits for it.
final class HostKeyPolicy {
  const HostKeyPolicy({required this.verify, this.offerOnlyType});

  /// When set, only host-key algorithms of this key type are offered.
  final String? offerOnlyType;

  /// Returns true to continue to authentication. Must not throw.
  final FutureOr<bool> Function(HostKey presented) verify;
}

abstract interface class SshConnector {
  /// Connects, verifies the host key through [policy] and logs in with the key.
  ///
  /// Throws an [SshFailure]. The timeout does not run while [policy] is deciding.
  Future<SshConnection> connect(
    Endpoint endpoint, {
    required String user,
    required Uint8List privateKeyPem,
    required HostKeyPolicy policy,
    required bool legacyAlgorithms,
    required Duration timeout,
  });

  /// Reads the server's host key without logging in. Throws an [SshFailure].
  Future<HostKey> probeHostKey(
    Endpoint endpoint, {
    required Duration timeout,
    required bool legacyAlgorithms,
    String? preferType,
  });
}

abstract interface class SshConnection {
  /// Opens an exec channel without a pty. Throws [SshConnectionLost].
  Future<ExecSession> exec(String command);

  bool get isClosed;

  Future<void> close();
}

abstract interface class ExecSession {
  Stream<Uint8List> get stdout;
  Stream<Uint8List> get stderr;

  void write(Uint8List data);

  /// Sends end-of-file on stdin.
  Future<void> closeStdin();

  /// Exit status; null when the channel closed without one.
  Future<int?> get exitCode;

  void close();
}

abstract interface class HostKeyPrompt {
  /// Asks the user to accept an unpinned pre-boot key.
  Future<bool> confirm(Host host, HostKey key);
}

/// Passphrase bytes for a host's disks.
abstract interface class SecretResolver {
  Uint8List passphraseFor(String disk);

  /// Every secret, for redacting server output.
  List<Uint8List> get allSecrets;
}

/// One passphrase per host with optional per-disk overrides.
final class DiskPassphrases implements SecretResolver {
  DiskPassphrases(this._default, {Map<String, Uint8List> perDisk = const {}})
    : _perDisk = Map.of(perDisk);

  final Uint8List _default;
  final Map<String, Uint8List> _perDisk;

  @override
  Uint8List passphraseFor(String disk) => _perDisk[disk] ?? _default;

  @override
  List<Uint8List> get allSecrets => [_default, ..._perDisk.values];

  /// Overwrites the bytes; Dart cannot guarantee no other copies exist.
  void wipe() {
    for (final s in allSecrets) {
      s.fillRange(0, s.length, 0);
    }
  }
}

sealed class SshFailure implements Exception {
  const SshFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// TCP connect refused, timed out or reset before the key exchange.
final class SshUnreachable extends SshFailure {
  const SshUnreachable(super.message);
}

/// Key exchange or login did not finish in time.
final class SshTimedOut extends SshFailure {
  const SshTimedOut(super.message);
}

/// The policy refused the key, or the server lacks the offered key type ([presented] is null).
final class SshHostKeyRejected extends SshFailure {
  const SshHostKeyRejected(super.message, this.presented);

  final HostKey? presented;
}

final class SshAuthFailed extends SshFailure {
  const SshAuthFailed(super.message);
}

/// The connection closed after it was established.
final class SshConnectionLost extends SshFailure {
  const SshConnectionLost(super.message);
}

/// Anything else: algorithm negotiation, malformed packets, unusable key.
final class SshProtocolFailure extends SshFailure {
  const SshProtocolFailure(super.message);
}
