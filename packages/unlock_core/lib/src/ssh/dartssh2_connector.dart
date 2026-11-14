import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../engine/ports.dart';
import '../model/endpoint.dart';
import '../model/host_key.dart';

/// [SshConnector] on dartssh2. Debug and trace printers stay unset.
final class DartSsh2Connector implements SshConnector {
  const DartSsh2Connector();

  /// Defaults, optionally narrowed to one key type or extended with legacy algorithms.
  static SSHAlgorithms algorithms({
    required bool legacy,
    String? offerOnlyType,
    String? preferType,
  }) {
    const d = SSHAlgorithms();
    var hostkey = [...d.hostkey, if (legacy) SSHHostkeyType.rsaSha1];
    bool ofType(SSHHostkeyType a, String type) =>
        HostKey.normalizeType(a.name) == HostKey.normalizeType(type);
    if (offerOnlyType != null) {
      final only = hostkey.where((a) => ofType(a, offerOnlyType)).toList();
      if (only.isNotEmpty) hostkey = only;
    } else if (preferType != null) {
      hostkey = [
        ...hostkey.where((a) => ofType(a, preferType)),
        ...hostkey.where((a) => !ofType(a, preferType)),
      ];
    }
    return SSHAlgorithms(
      kex: [
        ...d.kex,
        if (legacy) ...[SSHKexType.dh14Sha1, SSHKexType.dhGexSha1],
      ],
      hostkey: hostkey,
      cipher: [
        ...d.cipher,
        if (legacy) ...[
          SSHCipherType.aes256cbc,
          SSHCipherType.aes192cbc,
          SSHCipherType.aes128cbc,
        ],
      ],
      mac: d.mac,
    );
  }

  @override
  Future<SshConnection> connect(
    Endpoint endpoint, {
    required String user,
    required Uint8List privateKeyPem,
    required HostKeyPolicy policy,
    required bool legacyAlgorithms,
    required Duration timeout,
  }) async {
    final List<SSHKeyPair> identities;
    try {
      identities = SSHKeyPair.fromPem(utf8.decode(privateKeyPem));
    } catch (_) {
      throw const SshProtocolFailure(
        'the SSH private key cannot be used (unencrypted OpenSSH, PKCS#1 or SEC1 PEM expected)',
      );
    }
    final socket = await _open(endpoint, timeout);

    HostKey? presented;
    var rejected = false;
    Timer? timer;
    final timedOut = Completer<void>();
    void arm() {
      timer?.cancel();
      timer = Timer(timeout, () {
        if (!timedOut.isCompleted) timedOut.complete();
      });
    }

    final client = SSHClient(
      socket,
      username: user,
      identities: identities,
      keepAliveInterval: null,
      algorithms: algorithms(
        legacy: legacyAlgorithms,
        offerOnlyType: policy.offerOnlyType,
      ),
      onVerifyHostKey: (type, fingerprint) async {
        timer?.cancel();
        final key = presented = HostKey(type, utf8.decode(fingerprint));
        bool ok;
        try {
          ok = await policy.verify(key);
        } catch (_) {
          ok = false;
        }
        if (ok) {
          arm();
        } else {
          rejected = true;
        }
        return ok;
      },
    );
    arm();
    try {
      await Future.any([
        client.authenticated,
        timedOut.future.then<void>((_) => throw const _TimedOut()),
      ]);
    } catch (e) {
      unawaited(client.close());
      throw _map(
        e,
        endpoint,
        timeout: timeout,
        presented: presented,
        rejectedByPolicy: rejected,
        offerOnlyType: policy.offerOnlyType,
      );
    } finally {
      timer?.cancel();
    }
    return _Connection(client);
  }

  @override
  Future<HostKey> probeHostKey(
    Endpoint endpoint, {
    required Duration timeout,
    required bool legacyAlgorithms,
    String? preferType,
  }) async {
    final socket = await _open(endpoint, timeout);
    final got = Completer<HostKey>();
    final client = SSHClient(
      socket,
      username: 'probe',
      keepAliveInterval: null,
      algorithms: algorithms(legacy: legacyAlgorithms, preferType: preferType),
      onVerifyHostKey: (type, fingerprint) {
        if (!got.isCompleted) {
          got.complete(HostKey(type, utf8.decode(fingerprint)));
        }
        return false;
      },
    );
    final timer = Timer(timeout, () {
      if (!got.isCompleted) got.completeError(const _TimedOut());
    });
    try {
      return await Future.any([
        got.future,
        client.done.then<HostKey>(
          (_) => throw SshConnectionLost(
            '$endpoint closed before the key exchange',
          ),
        ),
      ]);
    } catch (e) {
      throw _map(e, endpoint, timeout: timeout);
    } finally {
      timer.cancel();
      unawaited(client.close());
    }
  }

  static Future<SSHSocket> _open(Endpoint e, Duration timeout) async {
    try {
      return await SSHSocket.connect(e.host, e.port, timeout: timeout);
    } on SocketException catch (err) {
      throw SshUnreachable('$e: ${err.osError?.message ?? err.message}');
    } on TimeoutException {
      throw SshUnreachable('$e: connect timed out');
    }
  }

  static SshFailure _map(
    Object e,
    Endpoint endpoint, {
    required Duration timeout,
    HostKey? presented,
    bool rejectedByPolicy = false,
    String? offerOnlyType,
  }) {
    if (e is SshFailure) return e;
    if (rejectedByPolicy) {
      return SshHostKeyRejected('$endpoint: host key rejected', presented);
    }
    final reason = e is SSHAuthAbortError ? e.reason ?? e : e;
    return switch (reason) {
      _TimedOut() || SSHHandshakeError() => SshTimedOut(
        '$endpoint: no SSH handshake and login within ${timeout.inSeconds} s',
      ),
      SSHAuthFailError() => SshAuthFailed('$endpoint: public key not accepted'),
      SSHAuthAbortError(:final message) =>
        presented == null
            ? SshUnreachable('$endpoint: $message')
            : SshConnectionLost('$endpoint: $message'),
      SSHInternalError(:final error)
          when '$error'.contains('No matching host key algorithm') =>
        offerOnlyType != null
            ? SshHostKeyRejected(
                '$endpoint: server offers no $offerOnlyType host key',
                null,
              )
            : SshProtocolFailure('$endpoint: no common host key algorithm'),
      SSHInternalError(:final error) when '$error'.contains('No matching') =>
        SshProtocolFailure(
          '$endpoint: ${'$error'.replaceFirst('Bad state: ', '')} (try legacy algorithms)',
        ),
      SSHSocketError() || SSHDisconnectError() || SocketException() =>
        presented == null
            ? SshUnreachable('$endpoint: connection closed during key exchange')
            : SshConnectionLost('$endpoint: connection closed'),
      SSHError() => SshProtocolFailure('$endpoint: $reason'),
      _ => SshProtocolFailure('$endpoint: ${reason.runtimeType}'),
    };
  }
}

final class _TimedOut implements Exception {
  const _TimedOut();
}

/// Dropbear closes the command's stdin when a channel or the TCP connection goes away,
/// which would submit an empty passphrase; so sessions still reading stdin are killed first.
final class _Connection implements SshConnection {
  _Connection(this._client);

  final SSHClient _client;
  final _sessions = <_Exec>[];
  final _opening = <Future<void>>[];
  var _closing = false;

  @override
  bool get isClosed => _closing || _client.isClosed;

  @override
  Future<ExecSession> exec(String command) async {
    if (isClosed) throw const SshConnectionLost('connection closed');
    final opening = _client.execute(command);
    final settled = opening.then((_) {}, onError: (Object _) {});
    _opening.add(settled);
    try {
      final session = _Exec(await opening);
      _sessions.add(session);
      if (_closing) session.close();
      return session;
    } catch (e) {
      throw SshConnectionLost('session could not be opened (${e.runtimeType})');
    } finally {
      _opening.remove(settled);
    }
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    await Future.wait(List.of(_opening))
        .timeout(const Duration(seconds: 2), onTimeout: () => const []);
    for (final s in _sessions) {
      s.abort();
    }
    unawaited(_client.close());
    await _client.done
        .catchError((Object _) {})
        .timeout(const Duration(seconds: 2), onTimeout: () {});
  }
}

final class _Exec implements ExecSession {
  _Exec(this._session);

  final SSHSession _session;
  var _stdinClosed = false;

  @override
  Stream<Uint8List> get stdout => _session.stdout;

  @override
  Stream<Uint8List> get stderr => _session.stderr;

  @override
  Future<int?> get exitCode => _session.waitForExit();

  @override
  void write(Uint8List data) {
    if (!_stdinClosed) _session.write(data);
  }

  @override
  Future<void> closeStdin() async {
    if (_stdinClosed) return;
    _stdinClosed = true;
    await _session.stdin.close().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
  }

  /// Kills the command while it may still read stdin.
  void abort() {
    if (_stdinClosed) return;
    _stdinClosed = true;
    try {
      _session.kill(SSHSignal.KILL);
    } catch (_) {}
  }

  @override
  void close() {
    abort();
    _session.close();
  }
}
