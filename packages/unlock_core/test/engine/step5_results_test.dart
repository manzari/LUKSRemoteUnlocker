import 'dart:convert';

import 'package:test/test.dart';
import 'package:unlock_core/engine.dart';

import 'fakes.dart';

void main() {
  group('step 5 result table', () {
    test('success line, exit 0: next round for the next disk', () async {
      final w = World()..server.disks = ['sda3_crypt', 'sdb1_crypt'];
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(resultOf(events), FinalState.unlocked, reason: messages(events));
      expect(w.server.unlocked, {'sda3_crypt', 'sdb1_crypt'});
      expect(w.server.received, hasLength(2));
      expect(events.last.message, contains('sda3_crypt, sdb1_crypt'));
    });

    test('no prompt, exit 0: all unlocked, wait for boot', () async {
      final w = World();
      w.server
        ..unlocked.add('sda3_crypt')
        ..bootedAt = w.clock.now().add(const Duration(seconds: 20));
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(
        events.map((e) => e.message),
        contains('no disk is waiting for a passphrase'),
      );
      expect(resultOf(events), FinalState.unlocked);
      expect(w.server.received, isEmpty);
    });

    test('later round refused after a success: booting', () async {
      final w = World()..server.afterUnlock = AfterUnlock.refuse;
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(
        events.map((e) => e.message),
        contains(startsWith('server is booting')),
      );
      expect(resultOf(events), FinalState.unlocked);
      expect(w.server.execs, 1);
    });

    test(
      'later round: session cannot be opened after a success: booting',
      () async {
        final w = World()..server.afterUnlock = AfterUnlock.execFails;
        final events = await runAll(w.engine(), [w.plan(w.host())]);
        expect(
          events.map((e) => e.message),
          contains(contains('could not start the unlock command')),
        );
        expect(resultOf(events), FinalState.unlocked, reason: messages(events));
      },
    );

    test(
      'finding 2: reconnect fails authentication after a success: booting',
      () async {
        final w = World()..server.afterUnlock = AfterUnlock.authFails;
        final events = await runAll(w.engine(), [w.plan(w.host())]);
        expect(
          events.map((e) => e.message),
          contains('server is booting (srv0:2222: denied)'),
        );
        expect(resultOf(events), FinalState.unlocked, reason: messages(events));
      },
    );

    test('finding 2: next round times out after a success: booting', () async {
      final w = World()..server.afterUnlock = AfterUnlock.hang;
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(
        events.map((e) => e.message),
        contains(contains('server is booting')),
      );
      expect(resultOf(events), FinalState.unlocked, reason: messages(events));
    });

    test('finding 2: next session opens but stays silent: booting', () async {
      final w = World()
        ..server.disks = ['sda3_crypt', 'sdb1_crypt']
        ..server.bootDelay = const Duration(seconds: 40);
      w.server.overrides[1] = (e) async {
        w.server.unlocked.add('sdb1_crypt');
        w.server.bootedAt = e.clock.now().add(const Duration(seconds: 5));
        w.server.dropbearStopped = true;
      };
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(
        events.map((e) => e.message),
        contains(startsWith('server is booting (no unlock prompt')),
      );
      expect(resultOf(events), FinalState.unlocked, reason: messages(events));
    });

    test('a silent session before any unlock: Error', () async {
      final w = World();
      w.server.overrides[0] = (e) async {};
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(resultOf(events), FinalState.error);
      expect(events.last.message, contains('no unlock prompt and no exit'));
      expect(w.server.received, isEmpty);
    });

    test('finding 3: next round exits 0 silently: booting', () async {
      final w = World()..server.afterUnlock = AfterUnlock.silentExit;
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(events.map((e) => e.message), contains('all disks unlocked'));
      expect(w.server.execs, 2);
      expect(resultOf(events), FinalState.unlocked);
    });

    test('Try again later: retried every 2 s, then success', () async {
      final w = World()..server.notReadyFor = const Duration(seconds: 7);
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(resultOf(events), FinalState.unlocked, reason: messages(events));
      expect(w.server.execs, 5);
      expect(w.server.received, hasLength(1));
    });

    test('not ready for more than 60 s: Error, nothing sent', () async {
      final w = World()..server.notReadyFor = const Duration(minutes: 5);
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(resultOf(events), FinalState.error);
      expect(events.last.message, contains('not ready after 60 s'));
      expect(w.server.received, isEmpty);
      final start = events
          .firstWhere((e) => e.phase == HostPhase.unlocking)
          .time;
      expect(events.last.time.difference(start), const Duration(seconds: 60));
    });

    test(
      'finding 1: tries used up earlier, askpass timeout: retried, then Error',
      () async {
        final w = World()..server.gaveUp = true;
        final events = await runAll(w.engine(), [w.plan(w.host())]);
        expect(resultOf(events), FinalState.error);
        expect(
          events.last.message,
          contains('Timeout reached while waiting for askpass'),
        );
        expect(w.server.received, isEmpty);
      },
    );

    test(
      'finding 1: askpass timeout after a passphrase was sent: Error, no retry',
      () async {
        final w = World()..server.disks = ['sda3_crypt', 'sdb1_crypt'];
        w.server.overrides[1] = (e) async {
          await e.clock.sleep(const Duration(seconds: 10));
          e.err('Error: Timeout reached while waiting for askpass.\n');
          e.finish(1);
        };
        final events = await runAll(w.engine(), [w.plan(w.host())]);
        expect(resultOf(events), FinalState.error);
        expect(events.last.message, contains('after a passphrase was sent'));
        expect(events.last.message, contains('unlocked sda3_crypt'));
        expect(w.server.execs, 2);
      },
    );

    test('bad password: Wrong passphrase, exactly one attempt', () async {
      final w = World();
      final events = await runAll(w.engine(), [
        w.plan(w.host(), pass: 'wrong-fake-pass'),
      ]);
      expect(resultOf(events), FinalState.wrongPassphrase);
      expect(events.last.message, contains('bad password or options'));
      expect(w.server.received, hasLength(1));
      expect(w.server.execs, 1);
      expect(w.server.tries['sda3_crypt'], 1);
    });

    test('maximum number of tries exceeded: Wrong passphrase', () async {
      final w = World()..server.maxTries = 1;
      final events = await runAll(w.engine(), [
        w.plan(w.host(), pass: 'wrong-fake-pass'),
      ]);
      expect(resultOf(events), FinalState.wrongPassphrase);
      expect(events.last.message, contains('maximum number of tries exceeded'));
      expect(w.server.execs, 1);
    });

    test('wrong passphrase on the second disk stops there', () async {
      final w = World()
        ..server.disks = ['sda3_crypt', 'sdb1_crypt']
        ..server.diskPassphrases = {'sdb1_crypt': 'second-fake-pass'};
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(resultOf(events), FinalState.wrongPassphrase);
      expect(w.server.received, hasLength(2));
      expect(w.server.execs, 2);
    });

    test(
      'connection lost after the passphrase, server boots: Unlocked',
      () async {
        final w = World();
        w.server.overrides[0] = (e) async {
          e.out('Please unlock disk sda3_crypt\n');
          w.server.received.add(await e.stdinEof);
          w.server.unlocked.add('sda3_crypt');
          w.server.bootedAt = e.clock.now().add(const Duration(seconds: 20));
          w.server.dropbearStopped = true;
          e.connection.closed = true;
          e.finish(null);
        };
        final events = await runAll(w.engine(), [w.plan(w.host())]);
        expect(
          events.map((e) => e.message),
          contains(startsWith('connection lost after the passphrase')),
        );
        expect(resultOf(events), FinalState.unlocked, reason: messages(events));
      },
    );

    test(
      'connection lost after the passphrase, no boot within 60 s: Error',
      () async {
        final w = World();
        w.server.overrides[0] = (e) async {
          e.out('Please unlock disk sda3_crypt\n');
          await e.stdinEof;
          e.connection.closed = true;
          e.finish(null);
        };
        final events = await runAll(w.engine(), [w.plan(w.host())]);
        expect(resultOf(events), FinalState.error);
        expect(events.last.message, contains('did not boot within 1 min'));
        final start = events
            .firstWhere((e) => e.phase == HostPhase.waitingForBoot)
            .time;
        expect(events.last.time.difference(start), const Duration(seconds: 60));
      },
    );

    test('no result 30 s after the passphrase counts as lost', () async {
      final w = World();
      w.server.overrides[0] = (e) async {
        e.out('Please unlock disk sda3_crypt\n');
        await e.stdinEof;
        w.server.bootNow();
      };
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(
        events.map((e) => e.message),
        contains(startsWith('connection lost after the passphrase')),
      );
      expect(resultOf(events), FinalState.unlocked);
    });

    test('anything else: Error with the sanitized output', () async {
      final w = World();
      w.server.overrides[0] = (e) async {
        e.err('cryptroot-unlock: something odd $fakePass happened\n');
        e.finish(2);
      };
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(resultOf(events), FinalState.error);
      expect(
        events.last.message,
        'exit 2: cryptroot-unlock: something odd [redacted] happened',
      );
      expect(messages(events), isNot(contains(fakePass)));
    });

    test('command not found on a booted system: Error, nothing sent', () async {
      final w = World();
      w.server.overrides[0] = (e) async {
        e.err('sh: cryptroot-unlock: not found\n');
        e.finish(127);
      };
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(resultOf(events), FinalState.error);
      expect(w.server.received, isEmpty);
    });

    test('at most 8 rounds', () async {
      final w = World()
        ..server.disks = [for (var i = 0; i < 10; i++) 'd$i']
        ..server.neverBoots = true;
      final events = await runAll(w.engine(), [
        w.plan(w.host(bootTimeout: const Duration(seconds: 10))),
      ]);
      expect(w.server.execs, 8);
      expect(events.map((e) => e.message), contains('stopped after 8 rounds'));
      expect(resultOf(events), FinalState.unlockedBootNotConfirmed);
    });
  });

  group('passphrase handling', () {
    test('finding 4: exact bytes, no newline, then end of file', () async {
      final w = World()..server.passphrase = 'fäke pass\twith spaces ';
      final events = await runAll(w.engine(), [
        w.plan(w.host(), pass: 'fäke pass\twith spaces '),
      ]);
      expect(resultOf(events), FinalState.unlocked);
      expect(w.server.received.single, utf8.encode('fäke pass\twith spaces '));
      expect(w.server.received.single.last, isNot(0x0a));
    });

    test('per-disk overrides', () async {
      final w = World()
        ..server.disks = ['sda3_crypt', 'sdb1_crypt']
        ..server.diskPassphrases = {'sdb1_crypt': 'second-fake-pass'};
      final events = await runAll(w.engine(), [
        w.plan(w.host(), perDisk: {'sdb1_crypt': 'second-fake-pass'}),
      ]);
      expect(resultOf(events), FinalState.unlocked, reason: messages(events));
      expect(w.server.received.map(utf8.decode), [
        fakePass,
        'second-fake-pass',
      ]);
      for (final s in [fakePass, 'second-fake-pass']) {
        expect(messages(events), isNot(contains(s)));
      }
    });

    test(
      'secrets echoed by the server are redacted, also across chunks',
      () async {
        final w = World();
        w.server.overrides[0] = (e) async {
          e.out('Please unlock disk sda3_crypt\n');
          final got = await e.stdinEof;
          e.errBytes([...utf8.encode('echo: '), ...got.sublist(0, 3)]);
          e.errBytes(got.sublist(3, 9));
          e.errBytes([...got.sublist(9), ...utf8.encode('\n')]);
          e.err('cryptsetup: sda3_crypt set up successfully\n');
          w.server.unlocked.add('sda3_crypt');
          w.server.bootNow();
          e.finish(0);
        };
        final events = await runAll(w.engine(), [w.plan(w.host())]);
        expect(resultOf(events), FinalState.unlocked);
        expect(
          events.map((e) => e.message),
          contains('stderr: echo: [redacted]'),
        );
        expect(messages(events), isNot(contains(fakePass)));
        expect(jsonEncode(events), isNot(contains(fakePass)));
      },
    );
  });

  group('cancel', () {
    Future<List<HostEvent>> cancelWhen(
      World w,
      bool Function(HostEvent e) when, {
      Host? host,
      HostKeyPrompt? prompt,
    }) => runAll(
      w.engine(prompt: prompt),
      [w.plan(host ?? w.host())],
      onEvent: (engine, ev) {
        if (when(ev.last)) engine.cancel();
      },
    );

    test('while checking if up', () async {
      final w = World();
      w.reach.blackholes.add(w.server.postboot);
      final events = await cancelWhen(
        w,
        (e) => e.phase == HostPhase.checkingIfUp,
        host: w.host(check: PostBootCheck.tcp),
      );
      expect(resultOf(events), FinalState.cancelled);
      expect(w.clock.elapsed, Duration.zero);
    });

    test('while waiting for pre-boot', () async {
      final w = World()..server.absent = true;
      final events = await cancelWhen(
        w,
        (e) => e.phase == HostPhase.waitingForPreboot,
      );
      expect(resultOf(events), FinalState.cancelled);
      expect(w.clock.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('while waiting for host-key confirmation', () async {
      final w = World();
      final events = await cancelWhen(
        w,
        (e) => e.message.contains('waiting for confirmation'),
        host: w.host(pinned: false),
        prompt: FakePrompt(null),
      );
      expect(resultOf(events), FinalState.cancelled);
      expect(w.server.authAttempts, 0);
    });

    test(
      'while waiting for the unlock prompt: command killed before EOF',
      () async {
        final w = World();
        FakeExec? exec;
        w.server.overrides[0] = (e) async {
          exec = e;
          e.out('waiting for askpass\n');
        };
        final events = await cancelWhen(
          w,
          (e) => e.message == 'stdout: waiting for askpass',
        );
        expect(resultOf(events), FinalState.cancelled);
        expect(exec!.killedBeforeEof, isTrue);
        expect(w.server.received, isEmpty);
      },
    );

    test('while waiting for the result', () async {
      final w = World()..server.unlockDelay = const Duration(seconds: 20);
      final events = await cancelWhen(
        w,
        (e) => e.message.contains('sending passphrase'),
      );
      expect(resultOf(events), FinalState.cancelled);
      expect(w.clock.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('while retrying a not-ready server', () async {
      final w = World()..server.notReadyFor = const Duration(minutes: 5);
      final events = await cancelWhen(
        w,
        (e) => e.message.startsWith('not ready'),
      );
      expect(resultOf(events), FinalState.cancelled);
      expect(w.server.execs, 1);
    });

    test('while waiting for boot', () async {
      final w = World()..server.neverBoots = true;
      final events = await cancelWhen(
        w,
        (e) => e.phase == HostPhase.waitingForBoot,
      );
      expect(resultOf(events), FinalState.cancelled);
      expect(w.clock.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('one host only', () async {
      final w = World(servers: 2)..servers[0].absent = true;
      final events = await runAll(
        w.engine(),
        [w.plan(w.host(index: 0)), w.plan(w.host(index: 1))],
        onEvent: (engine, ev) {
          if (ev.last.hostId == 'h0' &&
              ev.last.phase == HostPhase.waitingForPreboot) {
            engine.cancelHost('h0');
          }
        },
      );
      expect(resultOf(events, 'h0'), FinalState.cancelled);
      expect(resultOf(events, 'h1'), FinalState.unlocked);
    });
  });
}
