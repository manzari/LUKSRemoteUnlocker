import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:unlock_core/engine.dart';

const fakePass = 'fake-pass-0000';

final preKey = HostKey('ssh-ed25519', 'SHA256:${'A' * 43}');
final postKey = HostKey('ssh-ed25519', 'SHA256:${'B' * 43}');
final otherKey = HostKey('ssh-ed25519', 'SHA256:${'C' * 43}');

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

/// Virtual time that jumps to the next sleeper once nothing else is pending.
final class FakeClock implements Clock {
  FakeClock() : start = DateTime.utc(2026, 11, 14, 12);

  final DateTime start;
  late DateTime _now = start;
  final _sleepers = <_Sleeper>[];
  var _seq = 0;
  var _pumping = false;

  Duration get elapsed => _now.difference(start);

  @override
  DateTime now() => _now;

  @override
  Future<void> sleep(Duration duration, {Future<void>? abort}) {
    final s = _Sleeper(_now.add(duration), _seq++);
    _sleepers.add(s);
    abort?.whenComplete(() {
      if (_sleepers.remove(s)) s.done.complete();
    }).ignore();
    _pump();
    return s.done.future;
  }

  void _pump() {
    if (_pumping) return;
    _pumping = true;
    unawaited(() async {
      while (true) {
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        if (_sleepers.isEmpty) break;
        _sleepers.sort((a, b) {
          final c = a.due.compareTo(b.due);
          return c != 0 ? c : a.seq - b.seq;
        });
        final s = _sleepers.removeAt(0);
        if (s.due.isAfter(_now)) _now = s.due;
        s.done.complete();
      }
      _pumping = false;
    }());
  }
}

final class _Sleeper {
  _Sleeper(this.due, this.seq);

  final DateTime due;
  final int seq;
  final done = Completer<void>();
}

enum AfterUnlock { refuse, execFails, silentExit, authFails, hang }

/// A pre-boot server with the texts and exit codes of cryptroot-unlock.
final class FakeServer {
  FakeServer(
    this.clock, {
    List<Endpoint>? preboot,
    Endpoint? postboot,
    this.disks = const ['sda3_crypt'],
    this.passphrase = fakePass,
    this.diskPassphrases = const {},
    this.maxTries = 3,
  }) : preboot = preboot ?? [const Endpoint('srv', 2222)],
       postboot = postboot ?? const Endpoint('srv', 22),
       createdAt = clock.now();

  final FakeClock clock;
  final List<Endpoint> preboot;
  Endpoint postboot;
  final DateTime createdAt;
  List<String> disks;
  String passphrase;
  Map<String, String> diskPassphrases;
  int maxTries;

  Duration notReadyFor = Duration.zero;
  Duration unlockDelay = const Duration(milliseconds: 700);
  Duration bootDelay = const Duration(seconds: 3);
  Duration? prebootDelay;
  bool absent = false;
  bool authorized = true;
  bool neverBoots = false;
  AfterUnlock afterUnlock = AfterUnlock.refuse;
  HostKey prebootKey = preKey;
  HostKey postbootKey = postKey;

  /// Per exec index (0-based): replaces the script for that call.
  final overrides = <int, Future<void> Function(FakeExec exec)>{};

  final unlocked = <String>{};
  final tries = <String, int>{};
  bool gaveUp = false;
  DateTime? bootedAt;
  bool dropbearStopped = false;
  bool authKeysDeleted = false;
  bool hanging = false;
  bool execBroken = false;

  final received = <Uint8List>[];
  final connections = <FakeConnection>[];
  int connects = 0;
  int authAttempts = 0;
  int execs = 0;

  bool get booted => bootedAt != null && !clock.now().isBefore(bootedAt!);

  bool get prebootListening {
    if (absent || dropbearStopped) return false;
    final d = prebootDelay;
    return d == null || !clock.now().isBefore(createdAt.add(d));
  }

  void bootNow() {
    bootedAt = clock.now();
    dropbearStopped = true;
  }

  void _allUnlocked() {
    if (!neverBoots) bootedAt = clock.now().add(bootDelay);
    switch (afterUnlock) {
      case AfterUnlock.refuse:
        dropbearStopped = true;
        for (final c in connections) {
          c.closed = true;
        }
      case AfterUnlock.execFails:
        dropbearStopped = true;
        execBroken = true;
      case AfterUnlock.silentExit:
        break;
      case AfterUnlock.authFails:
        authKeysDeleted = true;
        for (final c in connections) {
          c.closed = true;
        }
      case AfterUnlock.hang:
        hanging = true;
    }
  }
}

final class FakeSsh implements SshConnector {
  FakeSsh(this.clock, this.servers);

  final FakeClock clock;
  final List<FakeServer> servers;
  final offeredTypes = <String?>[];
  final connectedTo = <Endpoint>[];
  final probed = <(Endpoint, String?)>[];
  final forcedFailures = <SshFailure>[];

  @override
  Future<SshConnection> connect(
    Endpoint endpoint, {
    required String user,
    required Uint8List privateKeyPem,
    required HostKeyPolicy policy,
    required bool legacyAlgorithms,
    required Duration timeout,
  }) async {
    await Future<void>.delayed(Duration.zero);
    connectedTo.add(endpoint);
    offeredTypes.add(policy.offerOnlyType);
    if (forcedFailures.isNotEmpty) throw forcedFailures.removeAt(0);
    final s = _serverAt(endpoint);
    if (s == null) throw SshUnreachable('$endpoint: refused');
    s.connects++;
    final HostKey presented;
    if (s.prebootListening && s.preboot.contains(endpoint)) {
      if (s.hanging) {
        await clock.sleep(timeout);
        throw SshTimedOut('$endpoint: timed out');
      }
      presented = s.prebootKey;
    } else if (s.booted && s.postboot == endpoint) {
      presented = s.postbootKey;
    } else if (s.hanging) {
      await clock.sleep(timeout);
      throw SshTimedOut('$endpoint: timed out');
    } else {
      throw SshUnreachable('$endpoint: refused');
    }
    final only = policy.offerOnlyType;
    if (only != null && only != presented.type) {
      throw SshHostKeyRejected('$endpoint: no $only key', null);
    }
    if (!await policy.verify(presented)) {
      throw SshHostKeyRejected('$endpoint: rejected', presented);
    }
    s.authAttempts++;
    if (!s.authorized || s.authKeysDeleted || presented == s.postbootKey) {
      throw SshAuthFailed('$endpoint: denied');
    }
    final c = FakeConnection(s);
    s.connections.add(c);
    return c;
  }

  @override
  Future<HostKey> probeHostKey(
    Endpoint endpoint, {
    required Duration timeout,
    required bool legacyAlgorithms,
    String? preferType,
  }) async {
    await Future<void>.delayed(Duration.zero);
    probed.add((endpoint, preferType));
    final s = _serverAt(endpoint);
    if (s != null) {
      if (s.prebootListening && s.preboot.contains(endpoint)) {
        return s.prebootKey;
      }
      if (s.booted && s.postboot == endpoint) return s.postbootKey;
    }
    throw SshUnreachable('$endpoint: refused');
  }

  FakeServer? _serverAt(Endpoint e) {
    for (final s in servers) {
      if (s.preboot.contains(e) || s.postboot == e) return s;
    }
    return null;
  }
}

final class FakeReachability implements Reachability {
  FakeReachability(this.clock, this.servers);

  final FakeClock clock;
  final List<FakeServer> servers;
  final calls = <(Endpoint, Duration)>[];

  /// Endpoints that drop packets: the check takes the full timeout.
  final blackholes = <Endpoint>{};

  @override
  Future<bool> tcpOpen(String host, int port, Duration timeout) async {
    final e = Endpoint(host, port);
    calls.add((e, clock.elapsed));
    await Future<void>.delayed(Duration.zero);
    if (blackholes.contains(e)) {
      await clock.sleep(timeout);
      return false;
    }
    for (final s in servers) {
      if (s.prebootListening && s.preboot.contains(e)) return true;
      if (s.booted && s.postboot == e) return true;
    }
    return false;
  }
}

final class FakeConnection implements SshConnection {
  FakeConnection(this.server);

  final FakeServer server;
  bool closed = false;

  @override
  bool get isClosed => closed;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<ExecSession> exec(String command) async {
    await Future<void>.delayed(Duration.zero);
    if (closed || server.execBroken) {
      throw const SshConnectionLost('connection closed');
    }
    if (server.hanging) return Completer<ExecSession>().future;
    final exec = FakeExec(server, this, command);
    final index = server.execs++;
    final override = server.overrides[index];
    unawaited(override == null ? exec.script() : override(exec));
    return exec;
  }
}

final class FakeExec implements ExecSession {
  FakeExec(this.server, this.connection, this.command);

  final FakeServer server;
  final FakeConnection connection;
  final String command;
  final _out = StreamController<Uint8List>();
  final _err = StreamController<Uint8List>();
  final _exit = Completer<int?>();
  final _stdin = BytesBuilder();
  final _eof = Completer<Uint8List>();
  bool killedBeforeEof = false;

  /// Thrown by [write] or [closeStdin], as by a channel that is already gone.
  Object? writeError;
  Object? closeStdinError;

  FakeClock get clock => server.clock;

  Future<Uint8List> get stdinEof => _eof.future;

  void out(String s) {
    if (!_exit.isCompleted) _out.add(bytes(s));
  }

  void err(String s) => errBytes(bytes(s));

  void errBytes(List<int> b) {
    if (!_exit.isCompleted) _err.add(Uint8List.fromList(b));
  }

  void finish(int? code) {
    if (_exit.isCompleted) return;
    _exit.complete(code);
    _out.close();
    _err.close();
  }

  @override
  Stream<Uint8List> get stdout => _out.stream;

  @override
  Stream<Uint8List> get stderr => _err.stream;

  @override
  Future<int?> get exitCode => _exit.future;

  @override
  void write(Uint8List data) {
    _stdin.add(data);
    if (writeError case final e?) Error.throwWithStackTrace(e, StackTrace.current);
  }

  @override
  Future<void> closeStdin() async {
    if (!_eof.isCompleted) _eof.complete(_stdin.toBytes());
    if (closeStdinError case final e?) {
      Error.throwWithStackTrace(e, StackTrace.current);
    }
  }

  @override
  void close() {
    if (!_eof.isCompleted) killedBeforeEof = true;
    finish(null);
  }

  /// The fake cryptroot-unlock, as in bench/fake-cryptroot-unlock.
  Future<void> script() async {
    final s = server;
    if (clock.now().isBefore(s.createdAt.add(s.notReadyFor))) {
      err('Try again later\n');
      return finish(1);
    }
    final locked = s.disks.where((d) => !s.unlocked.contains(d)).toList();
    if (locked.isEmpty) return finish(0);
    if (s.gaveUp) {
      await clock.sleep(const Duration(seconds: 10));
      err('Error: Timeout reached while waiting for askpass.\n');
      return finish(1);
    }
    final disk = locked.first;
    out('Please unlock disk $disk\n');
    final got = await stdinEof;
    if (_exit.isCompleted) return;
    s.received.add(got);
    await clock.sleep(s.unlockDelay);
    final expected = s.diskPassphrases[disk] ?? s.passphrase;
    if (utf8.decode(got, allowMalformed: true) == expected) {
      s.unlocked.add(disk);
      err('cryptsetup: $disk set up successfully\n');
      finish(0);
      if (s.disks.every(s.unlocked.contains)) s._allUnlocked();
      return;
    }
    final tried = s.tries[disk] = (s.tries[disk] ?? 0) + 1;
    if (s.maxTries > 0 && tried >= s.maxTries) {
      s.gaveUp = true;
      err('cryptsetup: maximum number of tries exceeded for $disk\n');
      return finish(1);
    }
    err('cryptsetup: cryptsetup failed, bad password or options?\n');
    finish(1);
  }
}

final class FakePrompt implements HostKeyPrompt {
  FakePrompt(this.answer);

  /// Null never answers.
  final bool? answer;
  final asked = <HostKey>[];

  @override
  Future<bool> confirm(Host host, HostKey key) {
    asked.add(key);
    final a = answer;
    return a == null ? Completer<bool>().future : Future.value(a);
  }
}

/// One world with servers, fakes and an engine factory.
final class World {
  World({int servers = 1}) {
    for (var i = 0; i < servers; i++) {
      this.servers.add(
        FakeServer(
          clock,
          preboot: [Endpoint('srv$i', 2222)],
          postboot: Endpoint('srv$i', 22),
        ),
      );
    }
  }

  final clock = FakeClock();
  final servers = <FakeServer>[];
  late final ssh = FakeSsh(clock, servers);
  late final reach = FakeReachability(clock, servers);

  FakeServer get server => servers.first;

  UnlockEngine engine({HostKeyPrompt? prompt}) => UnlockEngine(
    reachability: reach,
    ssh: ssh,
    hostKeyPrompt: prompt,
    clock: clock,
  );

  Host host({
    int index = 0,
    List<Endpoint>? preboot,
    PostBootCheck check = PostBootCheck.sshHostKey,
    HostKey? prebootKey,
    HostKey? postbootKey,
    bool pinned = true,
    String? postbootHost,
    int postbootPort = 22,
    Duration waitTimeout = const Duration(minutes: 10),
    Duration bootTimeout = const Duration(minutes: 5),
  }) => Host(
    id: 'h$index',
    name: 'host$index',
    preboot: preboot ?? servers[index].preboot,
    postbootHost: postbootHost,
    postbootPort: postbootPort,
    postbootCheck: check,
    prebootKey: prebootKey ?? (pinned ? servers[index].prebootKey : null),
    postbootKey: postbootKey,
    waitTimeout: waitTimeout,
    bootTimeout: bootTimeout,
  );

  HostPlan plan(
    Host host, {
    String pass = fakePass,
    Map<String, String>? perDisk,
  }) => HostPlan(
    host: host,
    privateKeyPem: bytes('fake-key'),
    secrets: DiskPassphrases(
      bytes(pass),
      perDisk: {
        for (final e in (perDisk ?? const <String, String>{}).entries)
          e.key: bytes(e.value),
      },
    ),
  );
}

/// Runs the engine to completion; [onEvent] sees every event as it arrives.
Future<List<HostEvent>> runAll(
  UnlockEngine engine,
  List<HostPlan> plans, {
  void Function(UnlockEngine engine, List<HostEvent> events)? onEvent,
}) async {
  final events = <HostEvent>[];
  await for (final e in engine.run(plans)) {
    events.add(e);
    onEvent?.call(engine, events);
  }
  return events;
}

FinalState? resultOf(List<HostEvent> events, [String hostId = 'h0']) =>
    events.lastWhere((e) => e.hostId == hostId && e.isFinal).result;

String messages(List<HostEvent> events) => events.map((e) => '$e').join('\n');
