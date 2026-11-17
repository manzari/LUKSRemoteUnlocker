import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:unlock_core/unlock_core.dart';

/// What every fake target accepts; obviously not a real passphrase.
const fakeServerPassphrase = 'FAKE-server-passphrase-0000';

HostKey fakeHostKey(String c) => HostKey('ssh-ed25519', 'SHA256:${c * 43}');

const fastTimings = EngineTimings(
  upCheckTimeout: Duration(milliseconds: 50),
  tcpTimeout: Duration(milliseconds: 50),
  pollInitial: Duration(milliseconds: 10),
  pollMax: Duration(milliseconds: 20),
  sshTimeout: Duration(seconds: 1),
  bootPollInterval: Duration(milliseconds: 10),
  bootCheckTimeout: Duration(milliseconds: 50),
  lostAfterPassphraseBootTimeout: Duration(seconds: 1),
  driver: DriverTimings(
    execTimeout: Duration(seconds: 1),
    notReadyDelay: Duration(milliseconds: 10),
    notReadyMax: Duration(milliseconds: 100),
  ),
);

/// A server at the Dropbear prompt with the texts of cryptroot-unlock; boots once all disks are open.
final class FakeTarget {
  FakeTarget(
    this.name, {
    this.passphrase = fakeServerPassphrase,
    this.disks = const ['sda3_crypt'],
    HostKey? prebootKey,
    HostKey? postbootKey,
  }) : prebootKey = prebootKey ?? fakeHostKey('P'),
       postbootKey = postbootKey ?? fakeHostKey('Q');

  final String name;
  String passphrase;
  List<String> disks;
  HostKey prebootKey;
  HostKey postbootKey;

  /// False: nothing answers on the pre-boot port.
  bool present = true;
  bool booted = false;

  /// Prints the received passphrase back on stderr and exits 2.
  bool echoesPassphrase = false;

  final unlocked = <String>{};
  final received = <String>[];
  int connects = 0;

  Endpoint get preboot => Endpoint(name, 2222);

  Endpoint get postboot => Endpoint(name, 22);

  bool get prebootListening => present && !booted;
}

final class FakeNetwork implements Reachability, SshConnector {
  FakeNetwork(this.targets);

  final List<FakeTarget> targets;

  /// The buffers the engine handed over, kept to check that they were wiped.
  final keyBuffers = <Uint8List>[];
  final passphraseBuffers = <Uint8List>[];

  UnlockEngine engine(HostKeyPrompt prompt) => UnlockEngine(
    reachability: this,
    ssh: this,
    hostKeyPrompt: prompt,
    timings: fastTimings,
  );

  FakeTarget? _at(Endpoint e) {
    for (final t in targets) {
      if (t.preboot == e || t.postboot == e) return t;
    }
    return null;
  }

  @override
  Future<bool> tcpOpen(String host, int port, Duration timeout) async {
    await Future<void>.delayed(Duration.zero);
    final e = Endpoint(host, port);
    final t = _at(e);
    if (t == null) return false;
    return e == t.preboot ? t.prebootListening : t.booted;
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
    await Future<void>.delayed(Duration.zero);
    final t = _at(endpoint);
    if (t == null || endpoint != t.preboot || !t.prebootListening) {
      throw SshUnreachable('$endpoint: connection refused');
    }
    t.connects++;
    keyBuffers.add(privateKeyPem);
    final only = policy.offerOnlyType;
    if (only != null && only != t.prebootKey.type) {
      throw SshHostKeyRejected('$endpoint: no $only host key', null);
    }
    if (!await policy.verify(t.prebootKey)) {
      throw SshHostKeyRejected('$endpoint: host key rejected', t.prebootKey);
    }
    return _Connection(t, this);
  }

  @override
  Future<HostKey> probeHostKey(
    Endpoint endpoint, {
    required Duration timeout,
    required bool legacyAlgorithms,
    String? preferType,
  }) async {
    await Future<void>.delayed(Duration.zero);
    final t = _at(endpoint);
    if (t != null) {
      if (endpoint == t.postboot && t.booted) return t.postbootKey;
      if (endpoint == t.preboot && t.prebootListening) return t.prebootKey;
    }
    throw SshUnreachable('$endpoint: connection refused');
  }
}

final class _Connection implements SshConnection {
  _Connection(this.target, this.network);

  final FakeTarget target;
  final FakeNetwork network;
  bool _closed = false;

  @override
  bool get isClosed => _closed || target.booted;

  @override
  Future<void> close() async => _closed = true;

  @override
  Future<ExecSession> exec(String command) async {
    await Future<void>.delayed(Duration.zero);
    if (isClosed) throw const SshConnectionLost('connection closed');
    final exec = _Exec(network);
    unawaited(_script(exec));
    return exec;
  }

  Future<void> _script(_Exec exec) async {
    final t = target;
    final locked = t.disks.where((d) => !t.unlocked.contains(d)).toList();
    if (locked.isEmpty) return exec.finish(0);
    final disk = locked.first;
    exec.out('Please unlock disk $disk\n');
    final got = utf8.decode(await exec.stdinEof, allowMalformed: true);
    if (exec.finished) return;
    t.received.add(got);
    if (t.echoesPassphrase) {
      exec.err('FAKE unexpected answer, got $got\n');
      return exec.finish(2);
    }
    if (got != t.passphrase) {
      exec.err('cryptsetup: cryptsetup failed, bad password or options?\n');
      return exec.finish(1);
    }
    t.unlocked.add(disk);
    exec.err('cryptsetup: $disk set up successfully\n');
    exec.finish(0);
    if (t.disks.every(t.unlocked.contains)) t.booted = true;
  }
}

final class _Exec implements ExecSession {
  _Exec(this.network);

  final FakeNetwork network;
  final _out = StreamController<Uint8List>();
  final _err = StreamController<Uint8List>();
  final _exit = Completer<int?>();
  final _stdin = BytesBuilder();
  final _eof = Completer<Uint8List>();

  Future<Uint8List> get stdinEof => _eof.future;

  bool get finished => _exit.isCompleted;

  void out(String s) {
    if (!finished) _out.add(utf8.encode(s));
  }

  void err(String s) {
    if (!finished) _err.add(utf8.encode(s));
  }

  void finish(int? code) {
    if (_exit.isCompleted) return;
    _exit.complete(code);
    unawaited(_out.close());
    unawaited(_err.close());
  }

  @override
  Stream<Uint8List> get stdout => _out.stream;

  @override
  Stream<Uint8List> get stderr => _err.stream;

  @override
  Future<int?> get exitCode => _exit.future;

  @override
  void write(Uint8List data) {
    network.passphraseBuffers.add(data);
    _stdin.add(data);
  }

  @override
  Future<void> closeStdin() async {
    if (!_eof.isCompleted) _eof.complete(_stdin.toBytes());
  }

  @override
  void close() {
    finish(null);
    if (!_eof.isCompleted) _eof.complete(Uint8List(0));
  }
}
