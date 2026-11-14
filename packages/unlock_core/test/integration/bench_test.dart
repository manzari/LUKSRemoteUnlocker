@Tags(['bench'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unlock_core/engine.dart';

import 'bench.dart';

const ssh = DartSsh2Connector();
const t1 = 'target1';
const t2 = 'target2';

Host benchHost(
  String t, {
  HostKey? pinned,
  HostKey? postKey,
  List<Endpoint>? preboot,
  PostBootCheck check = PostBootCheck.sshHostKey,
  Duration wait = const Duration(seconds: 40),
}) => Host(
  id: t,
  name: t,
  preboot: preboot ?? [Bench.preboot(t)],
  postbootHost: Bench.postboot(t).host,
  postbootPort: Bench.postboot(t).port,
  postbootCheck: check,
  prebootKey: pinned,
  postbootKey: postKey,
  waitTimeout: wait,
  bootTimeout: const Duration(seconds: 40),
);

HostPlan benchPlan(
  Host h, {
  String pass = benchPass,
  Map<String, String> perDisk = const {},
  String key = 'id_ed25519_bench',
}) => HostPlan(
  host: h,
  privateKeyPem: Bench.key(key),
  secrets: DiskPassphrases(
    bytes(pass),
    perDisk: {for (final e in perDisk.entries) e.key: bytes(e.value)},
  ),
);

Future<List<HostEvent>> unlock(
  List<HostPlan> plans, {
  HostKeyPrompt? prompt,
  void Function(UnlockEngine engine, HostEvent event)? onEvent,
}) async {
  final engine = UnlockEngine(
    reachability: const TcpReachability(),
    ssh: ssh,
    hostKeyPrompt: prompt,
  );
  final events = <HostEvent>[];
  await for (final e in engine.run(plans)) {
    events.add(e);
    printOnFailure('$e');
    onEvent?.call(engine, e);
  }
  return events;
}

FinalState? resultOf(List<HostEvent> events, String id) =>
    events.lastWhere((e) => e.hostId == id && e.isFinal).result;

void expectNoSecrets(List<HostEvent> events, List<String> secrets) {
  final all = jsonEncode(events);
  for (final s in secrets) {
    expect(all, isNot(contains(s)));
  }
}

Future<(ExecSession, SshConnection)> openUnlock(HostKey pinned) async {
  final conn = await ssh.connect(
    Bench.preboot(t1),
    user: 'root',
    privateKeyPem: Bench.key(),
    policy: HostKeyPolicy(offerOnlyType: pinned.type, verify: pinned.matches),
    legacyAlgorithms: false,
    timeout: const Duration(seconds: 10),
  );
  return (await conn.exec('cryptroot-unlock'), conn);
}

Future<String> firstLine(Stream<Uint8List> s) => s
    .cast<List<int>>()
    .transform(utf8.decoder)
    .transform(const LineSplitter())
    .first;

void main() {
  final bench = Bench();

  group('bench', skip: benchSkip, () {
    group('dartssh2 adapter', () {
      test('closing stdin sends EOF; the exit code arrives', () async {
        await bench.prepare(t1);
        final keys = await bench.keys(t1);
        final (session, conn) = await openUnlock(keys.preEd25519);
        final err = <int>[];
        final errDone = session.stderr.listen(err.addAll).asFuture<void>();
        expect(
          await firstLine(session.stdout),
          'Please unlock disk sda3_crypt',
        );
        session.write(bytes('fake-wrong-pass'));
        await session.closeStdin();
        final code = await session.exitCode.timeout(
          const Duration(seconds: 10),
        );
        await errDone.timeout(const Duration(seconds: 2), onTimeout: () {});
        await conn.close();
        expect(code, 1);
        expect(utf8.decode(err), contains('bad password or options'));
        expect((await bench.status(t1)).tries, {'sda3_crypt': 1});
      });

      for (final viaConnection in [false, true]) {
        final what = viaConnection ? 'connection' : 'session';
        test('closing the $what before the passphrase uses no try', () async {
          await bench.prepare(t1, {'UNLOCK_DELAY': '0'});
          final keys = await bench.keys(t1);
          final (session, conn) = await openUnlock(keys.preEd25519);
          expect(
            await firstLine(session.stdout),
            'Please unlock disk sda3_crypt',
          );
          if (!viaConnection) session.close();
          await conn.close();
          await Future<void>.delayed(const Duration(seconds: 2));
          final status = await bench.status(t1);
          expect(status.tries, {'sda3_crypt': 0});
          expect(status.phase, 'preboot');
        });
      }

      test(
        'probeHostKey reads Dropbear keys of each type without login',
        () async {
          await bench.prepare(t1);
          final keys = await bench.keys(t1);
          final since = DateTime.now().subtract(const Duration(seconds: 1));
          Future<HostKey> probe(String? prefer) => ssh.probeHostKey(
            Bench.preboot(t1),
            timeout: const Duration(seconds: 5),
            legacyAlgorithms: false,
            preferType: prefer,
          );
          expect(await probe(null), keys.preEd25519);
          expect(
            await probe('ecdsa-sha2-nistp256'),
            keys.pre['ecdsa-sha2-nistp256'],
          );
          expect(await probe('ssh-rsa'), keys.pre['ssh-rsa']);
          final logs = await bench.logsSince(t1, since);
          expect(logs, contains('Exit before auth'));
          expect(logs, isNot(contains("user 'root'")));
        },
      );

      test('a pinned RSA key restricts the offer to RSA and logs in', () async {
        await bench.prepare(t1);
        final rsa = (await bench.keys(t1)).pre['ssh-rsa']!;
        final seen = <HostKey>[];
        final conn = await ssh.connect(
          Bench.preboot(t1),
          user: 'root',
          privateKeyPem: Bench.key(),
          policy: HostKeyPolicy(
            offerOnlyType: rsa.type,
            verify: (k) => (seen..add(k)).isNotEmpty && rsa.matches(k),
          ),
          legacyAlgorithms: false,
          timeout: const Duration(seconds: 10),
        );
        await conn.close();
        expect(seen, [rsa]);
      });

      test(
        'typed failures: missing key type, wrong key, closed port',
        () async {
          await bench.prepare(t1);
          Future<void> connect({
            String? only,
            String key = 'id_ed25519_bench',
            Endpoint? at,
          }) => ssh.connect(
            at ?? Bench.preboot(t1),
            user: 'root',
            privateKeyPem: Bench.key(key),
            policy: HostKeyPolicy(offerOnlyType: only, verify: (_) => true),
            legacyAlgorithms: false,
            timeout: const Duration(seconds: 10),
          );
          await expectLater(
            connect(only: 'ecdsa-sha2-nistp384'),
            throwsA(
              isA<SshHostKeyRejected>().having(
                (e) => e.presented,
                'presented',
                isNull,
              ),
            ),
          );
          await expectLater(
            connect(key: 'id_ed25519_wrong'),
            throwsA(isA<SshAuthFailed>()),
          );
          await expectLater(
            connect(at: Bench.absent),
            throwsA(isA<SshUnreachable>()),
          );
          expect((await bench.status(t1)).tries, {'sda3_crypt': 0});
        },
      );
    });

    group('engine', () {
      late BenchKeys keys1;

      test(
        'success; post-boot key recorded and differs from pre-boot',
        () async {
          await bench.prepare(t1);
          keys1 = await bench.keys(t1);
          final events = await unlock([
            benchPlan(benchHost(t1, pinned: keys1.preEd25519)),
          ]);
          expect(resultOf(events, t1), FinalState.unlocked);
          final post = events
              .where((e) => e.newPostbootKey != null)
              .single
              .newPostbootKey;
          expect(post, keys1.postEd25519);
          expect(post, isNot(keys1.preEd25519));
          expect((await bench.status(t1)).phase, 'booted');
          expectNoSecrets(events, [benchPass]);
        },
      );

      test('already up: run again after boot', () async {
        final events = await unlock([
          benchPlan(benchHost(t1, pinned: keys1.preEd25519)),
        ]);
        expect(resultOf(events, t1), FinalState.alreadyUp);
        final again = await unlock([
          benchPlan(
            benchHost(t1, pinned: keys1.preEd25519, postKey: keys1.postEd25519),
          ),
        ]);
        expect(resultOf(again, t1), FinalState.alreadyUp);
        expect(again.where((e) => e.newPostbootKey != null), isEmpty);
      });

      test('two disks', () async {
        await bench.prepare(t2);
        final keys = await bench.keys(t2);
        final events = await unlock([
          benchPlan(benchHost(t2, pinned: keys.preEd25519)),
        ]);
        expect(resultOf(events, t2), FinalState.unlocked);
        expect(
          events.last.message,
          contains('unlocked sda3_crypt, sdb1_crypt'),
        );
        expect((await bench.status(t2)).unlocked, ['sda3_crypt', 'sdb1_crypt']);
      });

      test('per-disk secrets', () async {
        await bench.prepare(t2, {
          'DISK_PASSPHRASES': 'sdb1_crypt=fake-disk-b-pass',
        });
        final keys = await bench.keys(t2);
        final events = await unlock([
          benchPlan(
            benchHost(t2, pinned: keys.preEd25519),
            perDisk: {'sdb1_crypt': 'fake-disk-b-pass'},
          ),
        ]);
        expect(resultOf(events, t2), FinalState.unlocked);
        expect((await bench.status(t2)).tries, {
          'sda3_crypt': 0,
          'sdb1_crypt': 0,
        });
        expectNoSecrets(events, [benchPass, 'fake-disk-b-pass']);
      });

      test('not ready, then success', () async {
        await bench.prepare(t1, {'NOT_READY_SECONDS': '5'});
        final keys = await bench.keys(t1);
        final events = await unlock([
          benchPlan(benchHost(t1, pinned: keys.preEd25519)),
        ]);
        expect(
          events.map((e) => e.message),
          contains('stderr: Try again later'),
        );
        expect(
          events.map((e) => e.message),
          contains(startsWith('not ready, retrying')),
        );
        expect(resultOf(events, t1), FinalState.unlocked);
      });

      test('waits for pre-boot SSH', () async {
        await bench.prepare(t1, {'PREBOOT_DELAY': '6'});
        final keys = await bench.keys(t1);
        final start = DateTime.now();
        final events = await unlock([
          benchPlan(benchHost(t1, pinned: keys.preEd25519)),
        ]);
        expect(resultOf(events, t1), FinalState.unlocked);
        final connected = events.firstWhere(
          (e) => e.phase == HostPhase.verifyingHostKey,
        );
        expect(
          connected.time.difference(start),
          greaterThan(const Duration(seconds: 4)),
        );
      });

      test('wrong passphrase: one attempt only', () async {
        await bench.prepare(t1);
        final keys = await bench.keys(t1);
        final events = await unlock([
          benchPlan(
            benchHost(t1, pinned: keys.preEd25519),
            pass: 'fake-wrong-pass',
          ),
        ]);
        expect(resultOf(events, t1), FinalState.wrongPassphrase);
        expect(events.last.message, contains('bad password or options'));
        expect(
          events.where((e) => e.message.contains('sending passphrase')),
          hasLength(1),
        );
        expect((await bench.status(t1)).tries, {'sda3_crypt': 1});
        await Future<void>.delayed(const Duration(seconds: 3));
        expect((await bench.status(t1)).tries, {'sda3_crypt': 1});
        expectNoSecrets(events, ['fake-wrong-pass']);
      });

      test('rotated host key: mismatch, no login attempted', () async {
        await bench.prepare(t1);
        final old = (await bench.keys(t1)).preEd25519;
        await bench.rotateHostKey(t1);
        final fresh = (await bench.keys(t1)).preEd25519;
        expect(fresh, isNot(old));
        final since = DateTime.now().subtract(const Duration(seconds: 1));
        final events = await unlock([benchPlan(benchHost(t1, pinned: old))]);
        expect(resultOf(events, t1), FinalState.hostKeyMismatch);
        expect(events.last.presentedKey, fresh);
        expect(
          events.map((e) => e.phase),
          isNot(contains(HostPhase.authenticating)),
        );
        final logs = await bench.logsSince(t1, since);
        expect(logs, contains('Exit before auth'));
        expect(logs, isNot(contains("user 'root'")));
        expect(logs, isNot(contains('auth succeeded')));
        expect((await bench.status(t1)).tries, {'sda3_crypt': 0});
      });

      test('unpinned key refused without a prompt', () async {
        await bench.prepare(t1);
        final keys = await bench.keys(t1);
        final events = await unlock([benchPlan(benchHost(t1))]);
        expect(resultOf(events, t1), FinalState.hostKeyMismatch);
        expect(events.last.message, contains('not pinned'));
        expect(events.last.presentedKey, keys.preEd25519);
        expect((await bench.status(t1)).tries, {'sda3_crypt': 0});
      });

      test('wrong SSH key: auth failed', () async {
        await bench.prepare(t1);
        final keys = await bench.keys(t1);
        final events = await unlock([
          benchPlan(
            benchHost(t1, pinned: keys.preEd25519),
            key: 'id_ed25519_wrong',
          ),
        ]);
        expect(resultOf(events, t1), FinalState.authFailed);
        expect((await bench.status(t1)).tries, {'sda3_crypt': 0});
      });

      test('absent host: pre-boot timeout', () async {
        final events = await unlock([
          benchPlan(
            benchHost(
              t1,
              preboot: [Bench.absent],
              check: PostBootCheck.none,
              wait: const Duration(seconds: 5),
            ),
          ),
        ]);
        expect(resultOf(events, t1), FinalState.prebootTimeout);
      });

      test('cancel while waiting for pre-boot', () async {
        await bench.prepare(t1, {'PREBOOT_DELAY': '60'});
        final keys = await bench.keys(t1);
        final start = DateTime.now();
        final events = await unlock(
          [benchPlan(benchHost(t1, pinned: keys.preEd25519))],
          onEvent: (engine, e) {
            if (e.phase == HostPhase.waitingForPreboot) {
              Timer(const Duration(seconds: 1), engine.cancel);
            }
          },
        );
        expect(resultOf(events, t1), FinalState.cancelled);
        expect(
          DateTime.now().difference(start),
          lessThan(const Duration(seconds: 10)),
        );
        await bench.ctl(t1, ['clear']);
      });

      test('two hosts in parallel', () async {
        await Future.wait([bench.prepare(t1), bench.prepare(t2)]);
        final k1 = await bench.keys(t1);
        final k2 = await bench.keys(t2);
        final events = await unlock([
          benchPlan(benchHost(t1, pinned: k1.preEd25519)),
          benchPlan(benchHost(t2, pinned: k2.preEd25519)),
        ]);
        expect(resultOf(events, t1), FinalState.unlocked);
        expect(resultOf(events, t2), FinalState.unlocked);
        await Future.wait([
          bench.ctl(t1, ['clear']),
          bench.ctl(t2, ['clear']),
        ]);
      });
    });
  });
}
