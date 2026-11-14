import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unlock_cli/unlock_cli.dart';
import 'package:unlock_core/engine.dart';

const fakePass = 'fake-cli-pass';

final class FixedPassphrase implements PassphraseReader {
  FixedPassphrase(this.value);

  final String value;
  int reads = 0;

  @override
  Uint8List read({int? fd, required StringSink prompt}) {
    reads++;
    return Uint8List.fromList(utf8.encode(value));
  }
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
    final path = config(
      '  - name: a\n    preboot: a\n    wait_timeout: 1\n    passphrase_file: p\n',
    );
    final pass = FixedPassphrase(fakePass);
    expect(await cli(['unlock', '-c', path, '--host', 'a'], pass: pass), 1);
    expect(pass.reads, 0);
  });
}
