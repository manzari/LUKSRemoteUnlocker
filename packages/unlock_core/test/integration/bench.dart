import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:unlock_core/engine.dart';

const benchPass = 'fake-bench-pass';

final String? benchSkip = Platform.environment['BENCH'] == '1'
    ? null
    : 'needs the bench and BENCH=1 (make test-bench)';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

Directory get repoRoot {
  var d = Directory.current.absolute;
  while (!File('${d.path}/bench/compose.yaml').existsSync()) {
    if (d.parent.path == d.path) throw StateError('repo root not found');
    d = d.parent;
  }
  return d;
}

/// Drives bench-ctl through the host-side relay started by `make test-bench`.
final class Bench {
  Bench()
    : relay = Directory(
        Platform.environment['BENCH_RELAY_DIR'] ??
            '${repoRoot.path}/.dart_tool/bench-relay',
      );

  final Directory relay;
  var _n = 0;

  static Endpoint preboot(String t) => Endpoint.parse(
    Platform.environment['BENCH_${t.toUpperCase()}_PREBOOT'] ?? '$t:2222',
  );

  static Endpoint postboot(String t) => Endpoint.parse(
    Platform.environment['BENCH_${t.toUpperCase()}_POSTBOOT'] ?? '$t:22',
  );

  /// A pre-boot address where nothing listens.
  static Endpoint get absent =>
      Endpoint.parse(Platform.environment['BENCH_ABSENT'] ?? 'target1:2299');

  static Uint8List key([String name = 'id_ed25519_bench']) =>
      File('${repoRoot.path}/bench/fixtures/$name').readAsBytesSync();

  Future<String> ctl(String target, List<String> args) async {
    final id = '$pid.${_n++}.${DateTime.now().microsecondsSinceEpoch}';
    File('${relay.path}/.req.$id')
      ..writeAsStringSync([target, ...args].join('\n'))
      ..renameSync('${relay.path}/req.$id');
    final res = File('${relay.path}/res.$id');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (!res.existsSync()) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError(
          'no answer from the bench relay; run via make test-bench',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final text = res.readAsStringSync();
    res.deleteSync();
    final nl = text.indexOf('\n');
    final code = int.parse(nl < 0 ? text : text.substring(0, nl));
    final output = nl < 0 ? '' : text.substring(nl + 1);
    if (code != 0) {
      throw StateError(
        'bench-ctl $target ${args.first} failed ($code): $output',
      );
    }
    return output;
  }

  /// Drops overrides, sets the fake passphrase plus [extra], resets.
  Future<void> prepare(String t, [Map<String, String> extra = const {}]) async {
    await ctl(t, ['clear']);
    await ctl(t, [
      'set',
      for (final e in {'PASSPHRASE': benchPass, ...extra}.entries)
        '${e.key}=${e.value}',
    ]);
  }

  Future<void> rotateHostKey(String t) => ctl(t, ['rotate-hostkey']);

  Future<BenchStatus> status(String t) async =>
      BenchStatus.parse(await ctl(t, ['status']));

  Future<BenchKeys> keys(String t) async =>
      BenchKeys.parse(await ctl(t, ['fingerprint']));

  Future<String> logsSince(String t, DateTime since) =>
      ctl(t, ['logs', since.toUtc().toIso8601String()]);
}

final class BenchStatus {
  BenchStatus(this.phase, this.unlocked, this.tries);

  final String phase;
  final List<String> unlocked;
  final Map<String, int> tries;

  factory BenchStatus.parse(String text) {
    final lines = text.trim().split('\n');
    List<String> field(String name) =>
        lines
            .firstWhere((l) => l.startsWith('$name:'))
            .substring(name.length + 1)
            .trim()
            .split(' ')
          ..removeWhere((s) => s.isEmpty);
    return BenchStatus(lines.first.trim(), field('unlocked'), {
      for (final t in field('tries'))
        t.split('=').first: int.parse(t.split('=').last.split('/').first),
    });
  }

  @override
  String toString() => '$phase unlocked=$unlocked tries=$tries';
}

final class BenchKeys {
  BenchKeys(this.pre, this.post);

  final Map<String, HostKey> pre;
  final Map<String, HostKey> post;

  factory BenchKeys.parse(String text) {
    final pre = <String, HostKey>{};
    final post = <String, HostKey>{};
    for (final line in text.trim().split('\n')) {
      final [phase, type, fp] = line.trim().split(' ');
      (phase == 'preboot' ? pre : post)[type] = HostKey(type, fp);
    }
    return BenchKeys(pre, post);
  }

  HostKey get preEd25519 => pre['ssh-ed25519']!;
  HostKey get postEd25519 => post['ssh-ed25519']!;
}
