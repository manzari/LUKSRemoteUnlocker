@Tags(['bench'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const pass = 'fake-cli-bench-pass';
const t1 = 'target1';

final String? benchSkip = Platform.environment['BENCH'] == '1'
    ? null
    : 'needs the bench and BENCH=1 (make test-bench)';

final env = Platform.environment;
final repo = Directory.current.absolute.parent.parent.path;
final relay = env['BENCH_RELAY_DIR'] ?? '$repo/.dart_tool/bench-relay';
final work = Directory('.dart_tool/bench-cli')..createSync(recursive: true);
var _n = 0;

/// bench-ctl through the relay of `make test-bench`, as in unlock_core's bench.dart.
Future<String> ctl(String target, List<String> args) async {
  final id = '$pid.cli.${_n++}.${DateTime.now().microsecondsSinceEpoch}';
  File('$relay/.req.$id')
    ..writeAsStringSync([target, ...args].join('\n'))
    ..renameSync('$relay/req.$id');
  final res = File('$relay/res.$id');
  for (var i = 0; !res.existsSync(); i++) {
    if (i > 1800) throw StateError('no answer from the bench relay');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  final text = res.readAsStringSync();
  res.deleteSync();
  if (!text.startsWith('0\n')) throw StateError('bench-ctl failed: $text');
  return text.substring(2);
}

Future<String> prepare() async {
  await ctl(t1, ['clear']);
  await ctl(t1, ['set', 'PASSPHRASE=$pass']);
  final fp = await ctl(t1, ['fingerprint']);
  return fp
      .split('\n')
      .firstWhere((l) => l.startsWith('preboot ssh-ed25519 '))
      .substring('preboot '.length)
      .trim();
}

Future<int> tries() async {
  final status = await ctl(t1, ['status']);
  final m = RegExp(r'sda3_crypt=(\d+)/').firstMatch(status)!;
  return int.parse(m[1]!);
}

String config({String? pinned}) {
  final pre = env['BENCH_TARGET1_PREBOOT'] ?? 'target1:2222';
  final post = env['BENCH_TARGET1_POSTBOOT'] ?? 'target1:22';
  final f = File('${work.path}/hosts.yaml')
    ..writeAsStringSync('''
hosts:
  - name: $t1
    group: bench
    preboot: $pre
    postboot: $post
    key_file: $repo/bench/fixtures/id_ed25519_bench
    wait_timeout: 40s
    boot_timeout: 40s
${pinned == null ? '' : '    preboot_host_key: "$pinned"'}
''');
  return f.path;
}

final class Run {
  Run(this.code, this.out, this.err);

  final int code;
  final List<int> out;
  final List<int> err;

  String get stdout => utf8.decode(out, allowMalformed: true);
  String get stderr => utf8.decode(err, allowMalformed: true);

  void expectNoSecret(String secret) {
    final needle = utf8.encode(secret);
    for (final stream in [out, err]) {
      for (var i = 0; i + needle.length <= stream.length; i++) {
        var hit = true;
        for (var k = 0; k < needle.length && hit; k++) {
          hit = stream[i + k] == needle[k];
        }
        expect(hit, isFalse, reason: 'secret bytes at offset $i');
      }
    }
  }
}

/// Runs the CLI as a process; [shell] wraps it in bash for fd redirections.
Future<Run> luksUnlock(
  List<String> args, {
  List<int>? input,
  String? shell,
}) async {
  final dart = Platform.resolvedExecutable;
  final p = shell == null
      ? await Process.start(dart, ['run', 'bin/luks_unlock.dart', ...args])
      : await Process.start(
          'bash',
          ['-c', shell, 'bash', dart, ...args],
          environment: {'PASS': pass},
        );
  final out = <int>[];
  final err = <int>[];
  final done = [
    p.stdout.listen(out.addAll).asFuture<void>(),
    p.stderr.listen(err.addAll).asFuture<void>(),
  ];
  if (input != null) p.stdin.add(input);
  await p.stdin.close();
  final code = await p.exitCode.timeout(const Duration(minutes: 2));
  await Future.wait(done);
  final run = Run(code, out, err);
  printOnFailure('exit $code\n${run.stdout}\n${run.stderr}');
  return run;
}

void main() {
  group('luks-unlock against the bench', skip: benchSkip, () {
    test('success: exit 0, passphrase never in stdout or stderr', () async {
      final pinned = await prepare();
      final r = await luksUnlock([
        'unlock',
        '-c',
        config(pinned: pinned),
        '--host',
        t1,
      ], input: utf8.encode('$pass\n'));
      expect(r.code, 0);
      expect(
        r.stdout,
        contains('[$t1] Unlocked: booted (unlocked sda3_crypt)'),
      );
      expect(r.stdout, contains(RegExp(r'\ntarget1\s+Unlocked\s+booted')));
      expect(r.stdout, contains('postboot_host_key: "ssh-ed25519 SHA256:'));
      r.expectNoSecret(pass);
    });

    test('wrong passphrase: exit 1, one try, passphrase never printed', () async {
      final pinned = await prepare();
      const wrong = 'fake-cli-wrong-pass';
      final r = await luksUnlock([
        'unlock',
        '-c',
        config(pinned: pinned),
        '--group',
        'bench',
      ], input: utf8.encode(wrong));
      expect(r.code, 1);
      expect(
        r.stdout,
        contains(
          '[$t1] Wrong passphrase: cryptsetup: cryptsetup failed, bad password',
        ),
      );
      expect(await tries(), 1);
      r
        ..expectNoSecret(wrong)
        ..expectNoSecret(pass);
    });

    test('unpinned key without the flag: refused, fingerprint printed', () async {
      final key = await prepare();
      final r = await luksUnlock([
        'unlock',
        '-c',
        config(),
        '--all',
      ], input: utf8.encode(pass));
      expect(r.code, 1);
      expect(
        r.stdout,
        contains(
          '[$t1] Host key mismatch: pre-boot host key is not pinned; server presented $key',
        ),
      );
      expect(
        r.stdout,
        contains('preboot_host_key: "$key"  or run with --accept-new-host-key'),
      );
      expect(await tries(), 0);
    });

    test(
      'unpinned key with --accept-new-host-key: unlocked, key printed',
      () async {
        final key = await prepare();
        final r = await luksUnlock([
          'unlock',
          '-c',
          config(),
          '--all',
          '--accept-new-host-key',
        ], input: utf8.encode(pass));
        expect(r.code, 0);
        expect(
          r.stderr,
          contains('[$t1] accepting new pre-boot host key $key'),
        );
        expect(
          r.stdout,
          contains(
            'accepted pre-boot key; pin it with  preboot_host_key: "$key"',
          ),
        );
        r.expectNoSecret(pass);
      },
    );

    test('--passphrase-fd uses the bytes as read', () async {
      const fd =
          r'exec "$1" run bin/luks_unlock.dart "${@:2}" --passphrase-fd 3 3< <(printf';
      final pinned = await prepare();
      final args = ['unlock', '-c', config(pinned: pinned), '--host', t1];
      final ok = await luksUnlock(args, shell: '$fd %s "\$PASS")');
      expect(ok.code, 0);
      ok.expectNoSecret(pass);

      await prepare();
      final newline = await luksUnlock(args, shell: '$fd \'%s\\n\' "\$PASS")');
      expect(newline.code, 1);
      expect(newline.stdout, contains('Wrong passphrase'));
      expect(await tries(), 1);
      newline.expectNoSecret(pass);
    });
  });
}
