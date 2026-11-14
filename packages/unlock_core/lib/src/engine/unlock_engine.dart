import 'dart:async';
import 'dart:typed_data';

import '../log/sanitizer.dart';
import '../model/endpoint.dart';
import '../model/host.dart';
import '../model/host_event.dart';
import '../model/host_key.dart';
import '../model/unlock_profile.dart';
import 'clock.dart';
import 'ports.dart';
import 'stdin_driver.dart';
import 'unlock_driver.dart';

final class EngineTimings {
  const EngineTimings({
    this.upCheckTimeout = const Duration(seconds: 3),
    this.tcpTimeout = const Duration(seconds: 3),
    this.pollInitial = const Duration(seconds: 2),
    this.pollMax = const Duration(seconds: 5),
    this.sshTimeout = const Duration(seconds: 15),
    this.bootPollInterval = const Duration(seconds: 2),
    this.bootCheckTimeout = const Duration(seconds: 3),
    this.lostAfterPassphraseBootTimeout = const Duration(seconds: 60),
    this.driver = const DriverTimings(),
  });

  final Duration upCheckTimeout;
  final Duration tcpTimeout;
  final Duration pollInitial;
  final Duration pollMax;

  /// Key exchange plus login, not counting a host-key confirmation.
  final Duration sshTimeout;
  final Duration bootPollInterval;
  final Duration bootCheckTimeout;
  final Duration lostAfterPassphraseBootTimeout;
  final DriverTimings driver;
}

/// Everything one host's run needs; the caller owns and wipes the secrets.
final class HostPlan {
  const HostPlan({
    required this.host,
    required this.privateKeyPem,
    required this.secrets,
    this.profile = UnlockProfile.debian,
  });

  final Host host;

  /// Unencrypted OpenSSH private key.
  final Uint8List privateKeyPem;
  final SecretResolver secrets;
  final UnlockProfile profile;
}

/// Runs the unlock flow for several hosts in parallel. Does no persistence.
final class UnlockEngine {
  UnlockEngine({
    required this.reachability,
    required this.ssh,
    this.hostKeyPrompt,
    this.clock = const SystemClock(),
    this.timings = const EngineTimings(),
    Map<UnlockDriverKind, UnlockDriver>? drivers,
  }) : drivers = drivers ?? const {UnlockDriverKind.stdin: StdinDriver()};

  final Reachability reachability;
  final SshConnector ssh;

  /// Without a prompt, an unpinned pre-boot key ends in [FinalState.hostKeyMismatch].
  final HostKeyPrompt? hostKeyPrompt;
  final Clock clock;
  final EngineTimings timings;
  final Map<UnlockDriverKind, UnlockDriver> drivers;

  final _controls = <String, RunControl>{};

  /// Starts when listened to; closes after every host reached a final state.
  Stream<HostEvent> run(List<HostPlan> plans) {
    final ids = plans.map((p) => p.host.id).toSet();
    if (ids.length != plans.length) {
      throw ArgumentError('Host ids must be unique');
    }
    late final StreamController<HostEvent> events;
    events = StreamController<HostEvent>(
      onListen: () async {
        await Future.wait([
          for (final p in plans)
            _HostRun(
              this,
              p,
              _controls[p.host.id] = RunControl(clock),
              events.add,
            ).run(),
        ]);
        await events.close();
      },
    );
    return events.stream;
  }

  void cancel() {
    for (final c in _controls.values) {
      c.cancel();
    }
  }

  void cancelHost(String hostId) => _controls[hostId]?.cancel();
}

enum _Verdict { postbootKey, mismatch, unpinned, declined }

final class _Gate {
  _Verdict? verdict;
  HostKey? presented;
}

final class _Outcome {
  const _Outcome(this.state, this.message, {this.presented});

  final FinalState state;
  final String message;
  final HostKey? presented;
}

final class _HostRun implements RunLog {
  _HostRun(this.engine, this.plan, this.control, this.sink)
    : sanitizer = SecretSanitizer(plan.secrets.allSecrets),
      pinned = plan.host.prebootKey,
      knownPost = plan.host.postbootKey;

  final UnlockEngine engine;
  final HostPlan plan;
  final RunControl control;
  final void Function(HostEvent) sink;
  final SecretSanitizer sanitizer;

  HostKey? pinned;
  HostKey? knownPost;
  var _phase = HostPhase.checkingIfUp;
  var _finished = false;
  _Gate _gate = _Gate();
  String? _lastCheckNote;
  final _connections = <SshConnection>[];

  Host get host => plan.host;
  EngineTimings get timings => engine.timings;
  DateTime get now => engine.clock.now();

  void _emit(
    String message, {
    HostPhase? phase,
    FinalState? result,
    HostKey? newPrebootKey,
    HostKey? newPostbootKey,
    HostKey? presentedKey,
  }) {
    if (phase != null) _phase = phase;
    sink(
      HostEvent(
        hostId: host.id,
        time: now,
        phase: result == null ? _phase : HostPhase.finished,
        message: sanitizer.text(message),
        result: result,
        newPrebootKey: newPrebootKey,
        newPostbootKey: newPostbootKey,
        presentedKey: presentedKey,
      ),
    );
  }

  @override
  void log(String message) => _emit(message);

  Future<FinalState> run() async {
    _Outcome outcome;
    try {
      outcome = await _flow();
    } on RunCancelled {
      outcome = const _Outcome(FinalState.cancelled, 'cancelled');
    } catch (e) {
      outcome = _Outcome(FinalState.error, 'unexpected error: $e');
    } finally {
      _finished = true;
      await _closeConnections();
    }
    _emit(
      outcome.message,
      result: outcome.state,
      presentedKey: outcome.presented,
    );
    return outcome.state;
  }

  Future<_Outcome> _flow() async {
    if (host.postbootCheck != PostBootCheck.none) {
      _emit('checking ${host.postboot}', phase: HostPhase.checkingIfUp);
      if (await _postbootCheck(timings.upCheckTimeout)) {
        return const _Outcome(FinalState.alreadyUp, 'the server is already up');
      }
    }

    final deadline = now.add(host.waitTimeout);
    _emit(
      'waiting for pre-boot SSH at ${host.preboot.join(', ')}',
      phase: HostPhase.waitingForPreboot,
    );
    SshConnection? conn;
    Endpoint? endpoint;
    while (conn == null || endpoint == null) {
      final e = await _waitForPreboot(deadline);
      if (e == null) return _prebootTimeout();
      _emit('connecting to $e', phase: HostPhase.verifyingHostKey);
      try {
        conn = await _connect(e);
        endpoint = e;
        continue;
      } on SshUnreachable catch (f) {
        if (!now.isBefore(deadline)) return _prebootTimeout();
        _emit(f.message, phase: HostPhase.waitingForPreboot);
      } on SshTimedOut catch (f) {
        if (!now.isBefore(deadline)) return _prebootTimeout();
        _emit(f.message, phase: HostPhase.waitingForPreboot);
      } on SshConnectionLost catch (f) {
        if (!now.isBefore(deadline)) return _prebootTimeout();
        _emit(f.message, phase: HostPhase.waitingForPreboot);
      } on SshFailure catch (f) {
        return _failure(f);
      }
      await control.sleep(timings.pollInitial);
    }

    final driver = engine.drivers[plan.profile.driver];
    if (driver == null) {
      return _Outcome(
        FinalState.error,
        'driver ${plan.profile.driver.id} is not available',
      );
    }
    _emit('running ${plan.profile.command}', phase: HostPhase.unlocking);
    final DriverResult result;
    try {
      result = await driver.run(
        DriverContext(
          connection: conn,
          reconnect: () => _connect(endpoint!),
          profile: plan.profile,
          secrets: plan.secrets,
          log: this,
          control: control,
          timings: timings.driver,
        ),
      );
    } on SshFailure catch (f) {
      return _failure(f);
    }
    await _closeConnections();

    final disks = result.unlockedDisks;
    final unlockedNote = disks.isEmpty ? '' : ' (unlocked ${disks.join(', ')})';
    switch (result) {
      case DriverUnlocked(:final note):
        _emit(note);
        return _waitForBoot(
          host.bootTimeout,
          afterLoss: false,
          note: unlockedNote,
        );
      case DriverLostAfterPassphrase(:final disk):
        _emit('connection lost after the passphrase for $disk was sent');
        return _waitForBoot(
          timings.lostAfterPassphraseBootTimeout,
          afterLoss: true,
          note: unlockedNote,
        );
      case DriverWrongPassphrase(:final message):
        return _Outcome(FinalState.wrongPassphrase, message);
      case DriverError(:final message):
        return _Outcome(FinalState.error, '$message$unlockedNote');
    }
  }

  _Outcome _prebootTimeout() => _Outcome(
    FinalState.prebootTimeout,
    'no pre-boot SSH within ${_fmt(host.waitTimeout)}',
  );

  _Outcome _failure(SshFailure f) {
    switch (f) {
      case SshHostKeyRejected(:final presented):
        final gate = _gate;
        return switch (gate.verdict) {
          _Verdict.postbootKey => const _Outcome(
            FinalState.alreadyUp,
            'the pre-boot address presents the post-boot key; the server is already up',
          ),
          _Verdict.mismatch => _Outcome(
            FinalState.hostKeyMismatch,
            'host key mismatch: pinned $pinned, server presented ${gate.presented}',
            presented: gate.presented,
          ),
          _Verdict.unpinned => _Outcome(
            FinalState.hostKeyMismatch,
            'pre-boot host key is not pinned; server presented ${gate.presented}',
            presented: gate.presented,
          ),
          _Verdict.declined => const _Outcome(
            FinalState.cancelled,
            'new host key declined',
          ),
          null => _Outcome(
            FinalState.hostKeyMismatch,
            presented == null
                ? 'server offers no ${pinned?.type} host key (pinned $pinned)'
                : 'host key rejected: $presented',
            presented: presented,
          ),
        };
      case SshAuthFailed(:final message):
        return _Outcome(
          FinalState.authFailed,
          'login as ${host.user} rejected: $message',
        );
      default:
        return _Outcome(FinalState.error, f.message);
    }
  }

  Future<SshConnection> _connect(Endpoint e) {
    final gate = _gate = _Gate();
    final future = engine.ssh.connect(
      e,
      user: host.user,
      privateKeyPem: plan.privateKeyPem,
      policy: HostKeyPolicy(
        offerOnlyType: pinned?.type,
        verify: (k) => _verify(k, gate),
      ),
      legacyAlgorithms: host.legacyAlgorithms,
      timeout: timings.sshTimeout,
    );
    future.then((c) {
      _connections.add(c);
      if (_finished) unawaited(c.close());
    }, onError: (Object _) {}).ignore();
    return control.guard(future);
  }

  Future<bool> _verify(HostKey k, _Gate gate) async {
    final pin = pinned;
    if (pin != null && pin.matches(k)) {
      _emit('host key ok: $k', phase: HostPhase.authenticating);
      return true;
    }
    final post = knownPost;
    if (post != null && post.matches(k)) {
      gate.verdict = _Verdict.postbootKey;
      return false;
    }
    gate.presented = k;
    if (pin != null) {
      gate.verdict = _Verdict.mismatch;
      return false;
    }
    final prompt = engine.hostKeyPrompt;
    if (prompt == null) {
      gate.verdict = _Verdict.unpinned;
      return false;
    }
    _emit('new pre-boot host key $k, waiting for confirmation');
    bool ok;
    try {
      ok = await control.guard(prompt.confirm(host, k));
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      gate.verdict = _Verdict.declined;
      return false;
    }
    pinned = k;
    _emit(
      'host key accepted: $k',
      phase: HostPhase.authenticating,
      newPrebootKey: k,
    );
    return true;
  }

  Future<Endpoint?> _waitForPreboot(DateTime deadline) async {
    var interval = timings.pollInitial;
    while (true) {
      for (final e in host.preboot) {
        final open = await control.guard(
          engine.reachability.tcpOpen(e.host, e.port, timings.tcpTimeout),
        );
        if (open) return e;
      }
      final left = deadline.difference(now);
      if (left <= Duration.zero) return null;
      await control.sleep(interval < left ? interval : left);
      final next = interval * 1.5;
      interval = next < timings.pollMax ? next : timings.pollMax;
    }
  }

  Future<_Outcome> _waitForBoot(
    Duration timeout, {
    required bool afterLoss,
    required String note,
  }) async {
    if (host.postbootCheck == PostBootCheck.none) {
      return afterLoss
          ? _Outcome(
              FinalState.error,
              'connection lost after the passphrase was sent and no post-boot check is set$note',
            )
          : _Outcome(
              FinalState.unlockedBootNotConfirmed,
              'post-boot check is off$note',
            );
    }
    _emit('waiting for ${host.postboot}', phase: HostPhase.waitingForBoot);
    _lastCheckNote = null;
    final deadline = now.add(timeout);
    while (true) {
      if (await _postbootCheck(timings.bootCheckTimeout)) {
        return _Outcome(FinalState.unlocked, 'booted$note');
      }
      final left = deadline.difference(now);
      if (left <= Duration.zero) {
        return afterLoss
            ? _Outcome(
                FinalState.error,
                'connection lost after the passphrase was sent and the server did not boot within ${_fmt(timeout)}$note',
              )
            : _Outcome(
                FinalState.unlockedBootNotConfirmed,
                'no boot confirmation within ${_fmt(timeout)}$note',
              );
      }
      final pause = timings.bootPollInterval;
      await control.sleep(pause < left ? pause : left);
    }
  }

  /// True when the booted system answers at the post-boot address.
  Future<bool> _postbootCheck(Duration timeout) async {
    final e = host.postboot;
    switch (host.postbootCheck) {
      case PostBootCheck.none:
        return false;
      case PostBootCheck.tcp:
        final open = await control.guard(
          engine.reachability.tcpOpen(e.host, e.port, timeout),
        );
        _note(open ? '$e accepts connections' : '$e is closed');
        return open;
      case PostBootCheck.sshHostKey:
        final pin = pinned;
        final post = knownPost;
        if (pin == null && post == null && host.preboot.contains(e)) {
          _note(
            '$e is also a pre-boot address and no key is known to tell them apart',
          );
          return false;
        }
        final HostKey k;
        try {
          k = await control.guard(
            engine.ssh.probeHostKey(
              e,
              timeout: timeout,
              legacyAlgorithms: host.legacyAlgorithms,
              preferType: post?.type ?? pin?.type,
            ),
          );
        } on SshFailure catch (f) {
          _note(f.message);
          return false;
        }
        if (pin != null && pin.matches(k)) {
          _note('$e still presents the pre-boot key');
          return false;
        }
        if (post != null) {
          if (post.matches(k)) {
            _note('$e presents the post-boot key');
            return true;
          }
          _note(
            'warning: $e presents $k, not the recorded post-boot key $post',
          );
          return false;
        }
        knownPost = k;
        _emit('post-boot host key recorded: $k', newPostbootKey: k);
        return true;
    }
  }

  void _note(String message) {
    if (message == _lastCheckNote) return;
    _lastCheckNote = message;
    _emit(message);
  }

  Future<void> _closeConnections() async {
    final all = List.of(_connections);
    _connections.clear();
    await Future.wait([
      for (final c in all) c.close().catchError((Object _) {}),
    ]);
  }

  static String _fmt(Duration d) => d.inSeconds % 60 == 0 && d.inMinutes > 0
      ? '${d.inMinutes} min'
      : '${d.inSeconds} s';
}
