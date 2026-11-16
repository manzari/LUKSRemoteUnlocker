import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unlock_cli/unlock_cli.dart';
import 'package:unlock_core/engine.dart';

import 'support.dart' show chmod;

const fakePass = 'fake-cli-pass';

final class FixedPassphrase implements PassphraseReader {
  FixedPassphrase(this.value);

  final String value;
  int reads = 0;

  @override
  Future<Uint8List> read({int? fd, required StringSink prompt}) async {
    reads++;
    return Uint8List.fromList(utf8.encode(value));
  }
}

/// A pre-boot server whose output and error text carry terminal escape sequences.
final class EscapingServer
    implements Reachability, SshConnector, UnlockDriver, SshConnection {
  @override
  Future<bool> tcpOpen(String host, int port, Duration timeout) async =>
      port == 2222;

  @override
  Future<SshConnection> connect(
    Endpoint endpoint, {
    required String user,
    required Uint8List privateKeyPem,
    required HostKeyPolicy policy,
    required bool legacyAlgorithms,
    required Duration timeout,
  }) async => this;

  @override
  Future<HostKey> probeHostKey(
    Endpoint endpoint, {
    required Duration timeout,
    required bool legacyAlgorithms,
    String? preferType,
  }) async => throw const SshUnreachable('refused');

  @override
  Future<DriverResult> run(DriverContext context) async {
    context.log.log('stdout: \x1b[2J\x1b]0;owned\x07tab\there\rback');
    return const DriverError([], 'exit 1: \x1b[31mred\u009b1m\u202edone');
  }

  @override
  Future<ExecSession> exec(String command) =>
      throw const SshConnectionLost('unused');

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async {}
}

final class NothingThere implements Reachability, SshConnector {
  @override
  Future<bool> tcpOpen(String host, int port, Duration timeout) async => false;

  @override
  Future<SshConnection> connect(
    Endpoint endpoint, {
    required String user,
    required Uint8List privateKeyPem,
    required HostKeyPolicy policy,
    required bool legacyAlgorithms,
    required Duration timeout,
  }) async => throw const SshUnreachable('refused');

  @override
  Future<HostKey> probeHostKey(
    Endpoint endpoint, {
    required Duration timeout,
    required bool legacyAlgorithms,
    String? preferType,
  }) async => throw const SshUnreachable('refused');
}

void main() {
  late StringBuffer out;
  late StringBuffer err;
  late Directory dir;

  setUp(() {
    out = StringBuffer();
    err = StringBuffer();
    dir = Directory('.dart_tool/cli-test')..createSync(recursive: true);
    File('${dir.path}/key').writeAsStringSync('not a real key\n');
    chmod('600', '${dir.path}/key');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  String config(String hosts) {
    final f = File('${dir.path}/hosts.yaml')
      ..writeAsStringSync('defaults:\n  key_file: key\nhosts:\n$hosts');
    return f.path;
  }

  Future<int> cli(List<String> args, {PassphraseReader? pass}) => runCli(
    args,
    out: out,
    err: err,
    readPassphrase: pass ?? FixedPassphrase(fakePass),
    newEngine: (prompt) {
      final none = NothingThere();
      return UnlockEngine(
        reachability: none,
        ssh: none,
        hostKeyPrompt: prompt,
        timings: const EngineTimings(pollInitial: Duration(milliseconds: 20)),
      );
    },
  );

  test('prints usage without arguments', () async {
    expect(await runCli(const [], out: out, err: err), 0);
    expect(out.toString(), contains('Usage: luks-unlock'));
    expect(err.toString(), isEmpty);
  });

  test('prints the version', () async {
    expect(await runCli(const ['--version'], out: out, err: err), 0);
    expect(out.toString(), startsWith('luks-unlock $cliVersion'));
  });

  test('rejects unknown options with a usage exit code', () async {
    expect(await runCli(const ['--nope'], out: out, err: err), exitUsage);
    expect(err.toString(), contains('Usage: luks-unlock'));
  });

  test('unlock --help', () async {
    expect(await cli(['unlock', '--help']), 0);
    expect(out.toString(), contains('--accept-new-host-key'));
  });

  group('usage errors exit 64', () {
    const hosts = '  - name: a\n    preboot: a:2222\n    group: g\n';
    for (final (args, text) in [
      (['unlock', '--all'], '--config is required'),
      (['unlock', '-c', 'CFG'], 'exactly one of'),
      (['unlock', '-c', 'CFG', '--all', '--host', 'a'], 'exactly one of'),
      (['unlock', '-c', 'CFG', '--host', 'b'], 'no host named b'),
      (['unlock', '-c', 'CFG', '--group', 'x'], 'no enabled host selected'),
      (
        ['unlock', '-c', 'CFG', '--all', '--passphrase-fd', 'x'],
        '--passphrase-fd',
      ),
      (['unlock', '-c', 'missing.yaml', '--all'], 'missing.yaml'),
    ]) {
      test(text, () async {
        final path = config(hosts);
        final code = await cli([for (final a in args) a == 'CFG' ? path : a]);
        expect(code, exitUsage);
        expect(err.toString(), contains(text));
      });
    }

    test('empty passphrase', () async {
      final path = config(hosts);
      expect(
        await cli(['unlock', '-c', path, '--all'], pass: FixedPassphrase('')),
        exitUsage,
      );
      expect(err.toString(), contains('passphrase is empty'));
    });

    test('missing key file', () async {
      final path = config('  - name: a\n    preboot: a\n    key_file: nokey\n');
      expect(await cli(['unlock', '-c', path, '--all']), exitUsage);
      expect(err.toString(), contains('nokey'));
    });
  });

  test(
    'one line per event, a summary, exit 1 when not every host is up',
    () async {
      final path = config(
        '  - name: alpha\n    preboot: alpha:2222\n    wait_timeout: 1\n'
        '  - name: beta\n    preboot: beta:2222\n    wait_timeout: 1\n    enabled: false\n',
      );
      final pass = FixedPassphrase(fakePass);
      expect(await cli(['unlock', '-c', path, '--all'], pass: pass), 1);
      final text = out.toString();
      expect(text, contains('[alpha] checking-if-up: checking alpha:22'));
      expect(
        text,
        contains(
          '[alpha] waiting-for-preboot: waiting for pre-boot SSH at alpha:2222',
        ),
      );
      expect(
        text,
        contains('[alpha] Pre-boot timeout: no pre-boot SSH within 1 s'),
      );
      expect(
        text,
        contains(RegExp(r'HOST\s+RESULT\s+DETAIL\nalpha\s+Pre-boot timeout')),
      );
      expect(text, isNot(contains('beta')));
      expect(pass.reads, 1);
    },
  );

  test('hosts with a passphrase_file do not read stdin', () async {
    File('${dir.path}/p').writeAsStringSync('$fakePass\n');
    chmod('600', '${dir.path}/p');
    final path = config(
      '  - name: a\n    preboot: a\n    wait_timeout: 1\n    passphrase_file: p\n',
    );
    final pass = FixedPassphrase(fakePass);
    expect(await cli(['unlock', '-c', path, '--host', 'a'], pass: pass), 1);
    expect(pass.reads, 0);
  });

  group('secret files readable by others are refused', () {
    for (final (mode, file, hosts) in [
      ('644', 'key', '  - name: a\n    preboot: a\n'),
      ('604', 'key', '  - name: a\n    preboot: a\n'),
      (
        '640',
        'p',
        '  - name: a\n    preboot: a\n    passphrase_file: p\n',
      ),
      (
        '620',
        'd',
        '  - name: a\n    preboot: a\n    disk_passphrase_files: {sdb1_crypt: d}\n',
      ),
    ]) {
      test('$file with mode $mode', () async {
        File('${dir.path}/$file').writeAsStringSync('FAKE-secret\n');
        chmod(mode, '${dir.path}/$file');
        final path = config(hosts);
        final pass = FixedPassphrase(fakePass);
        expect(await cli(['unlock', '-c', path, '--all'], pass: pass), 64);
        expect(err.toString(), contains('accessible by group or others'));
        expect(err.toString(), contains('(mode 0$mode)'));
        expect(pass.reads, 0);
      }, testOn: 'posix');
    }
  });

  test('server text is printed with control characters escaped', () async {
    final server = EscapingServer();
    final path = config(
      '  - name: a\n    preboot: a:2222\n    postboot_check: none\n',
    );
    final code = await runCli(
      ['unlock', '-c', path, '--all'],
      out: out,
      err: err,
      readPassphrase: FixedPassphrase(fakePass),
      newEngine: (prompt) => UnlockEngine(
        reachability: server,
        ssh: server,
        hostKeyPrompt: prompt,
        drivers: {UnlockDriverKind.stdin: server},
      ),
    );
    expect(code, 1);
    final text = out.toString();
    expect(
      text,
      contains(r'[a] unlocking: stdout: \x1b[2J\x1b]0;owned\x07tab' '\there'),
    );
    expect(text, contains(r'exit 1: \x1b[31mred\x9b1m\u202edone'));
    for (final raw in ['\x1b', '\x07', '\r', '\u009b', '\u202e']) {
      expect(text, isNot(contains(raw)));
    }
  });

  group('unexpected errors', () {
    test('one line on stderr, exit 1', () async {
      final code = await runGuarded(
        () async => throw StateError('boom\nsecond \x1b[2J line'),
        err,
      );
      expect(code, exitFailure);
      expect(
        err.toString(),
        'luks-unlock: unexpected error: '
        r'Bad state: boom\x0asecond \x1b[2J line'
        '\n',
      );
    });

    test('uncaught asynchronous errors too', () async {
      final code = await runGuarded(() {
        Future<void>(() => throw StateError('late'));
        return Completer<int>().future;
      }, err);
      expect(code, exitFailure);
      expect(err.toString(), contains('unexpected error: Bad state: late'));
    });

    test('a FormatException does not show its source', () async {
      final code = await runGuarded(
        () async => throw const FormatException('bad', 'FAKE-source-text'),
        err,
      );
      expect(code, exitFailure);
      expect(err.toString(), isNot(contains('FAKE-source-text')));
    });

    test('from inside runCli', () async {
      final path = config('  - name: a\n    preboot: a\n');
      final code = await runGuarded(
        () => runCli(
          ['unlock', '-c', path, '--all'],
          out: out,
          err: err,
          readPassphrase: FixedPassphrase(fakePass),
          newEngine: (_) => throw StateError('engine broke'),
        ),
        err,
      );
      expect(code, exitFailure);
      expect(err.toString(), 'luks-unlock: unexpected error: Bad state: engine broke\n');
    });

    test('a normal exit status passes through', () async {
      expect(await runGuarded(() async => 64, err), 64);
      expect(err.toString(), isEmpty);
    });
  });
}
