import 'package:test/test.dart';
import 'package:unlock_core/engine.dart';

import 'fakes.dart';

void main() {
  group('step 1, checking if up', () {
    test(
      'ssh-hostkey check passes on a non-pre-boot key: Already up',
      () async {
        final w = World();
        w.server.bootNow();
        final events = await runAll(w.engine(), [w.plan(w.host())]);
        expect(
          resultOf(events),
          FinalState.alreadyUp,
          reason: messages(events),
        );
        expect(w.ssh.connectedTo, isEmpty);
        expect(events.where((e) => e.newPostbootKey == postKey), hasLength(1));
      },
    );

    test('tcp check passes: Already up', () async {
      final w = World();
      w.server.bootNow();
      final events = await runAll(w.engine(), [
        w.plan(w.host(check: PostBootCheck.tcp)),
      ]);
      expect(resultOf(events), FinalState.alreadyUp);
      expect(w.ssh.probed, isEmpty);
      expect(w.ssh.connectedTo, isEmpty);
    });

    test('pre-boot key at the post-boot address is not up', () async {
      final w = World();
      w.server.postboot = w.server.preboot.first;
      final host = w.host(postbootPort: 2222);
      final events = await runAll(w.engine(), [w.plan(host)]);
      expect(
        events.map((e) => e.message),
        contains(contains('still presents the pre-boot key')),
      );
      expect(resultOf(events), FinalState.unlocked, reason: messages(events));
    });

    test(
      'a recorded post-boot key that changed is a warning, not up',
      () async {
        final w = World();
        w.server.bootNow();
        w.server.postbootKey = otherKey;
        final events = await runAll(w.engine(), [
          w.plan(
            w.host(
              postbootKey: postKey,
              waitTimeout: const Duration(seconds: 5),
            ),
          ),
        ]);
        expect(events.first.phase, HostPhase.checkingIfUp);
        expect(events.map((e) => e.message), contains(startsWith('warning:')));
        expect(resultOf(events), FinalState.prebootTimeout);
      },
    );

    test(
      'check none skips steps 1 and 6: Unlocked, boot not confirmed',
      () async {
        final w = World();
        final events = await runAll(w.engine(), [
          w.plan(w.host(check: PostBootCheck.none)),
        ]);
        expect(resultOf(events), FinalState.unlockedBootNotConfirmed);
        expect(w.ssh.probed, isEmpty);
        expect(
          events.map((e) => e.phase),
          isNot(contains(HostPhase.checkingIfUp)),
        );
        expect(
          events.map((e) => e.phase),
          isNot(contains(HostPhase.waitingForBoot)),
        );
      },
    );

    test(
      'without any known key a shared pre/post-boot address is not trusted',
      () async {
        final w = World();
        w.server.postboot = w.server.preboot.first;
        final host = w.host(pinned: false, postbootPort: 2222);
        final events = await runAll(w.engine(prompt: FakePrompt(true)), [
          w.plan(host),
        ]);
        expect(
          events[1].message,
          contains('no key is known to tell them apart'),
        );
        expect(events[1].phase, HostPhase.checkingIfUp);
        expect(resultOf(events), FinalState.unlocked, reason: messages(events));
      },
    );
  });

  group('step 2, waiting for pre-boot', () {
    test(
      'timeout: Pre-boot timeout, polling backs off from 2 s to 5 s',
      () async {
        final w = World()..server.absent = true;
        final events = await runAll(w.engine(), [
          w.plan(w.host(waitTimeout: const Duration(seconds: 30))),
        ]);
        expect(resultOf(events), FinalState.prebootTimeout);
        final times = w.reach.calls
            .where((c) => c.$1.port == 2222)
            .map((c) => c.$2.inMilliseconds / 1000)
            .toList();
        expect(times.take(6), [0, 2, 5, 9.5, 14.5, 19.5]);
        expect(times.last, 30);
        expect(w.clock.elapsed, const Duration(seconds: 30));
        expect(
          w.reach.calls.every((c) => c.$2 <= const Duration(seconds: 30)),
          isTrue,
        );
      },
    );

    test('each TCP check gets a 3 s timeout', () async {
      final w = World()..server.absent = true;
      w.reach.blackholes.add(w.server.preboot.first);
      final events = await runAll(w.engine(), [
        w.plan(w.host(waitTimeout: const Duration(seconds: 10))),
      ]);
      expect(resultOf(events), FinalState.prebootTimeout);
      final times = w.reach.calls
          .where((c) => c.$1.port == 2222)
          .map((c) => c.$2.inSeconds)
          .toList();
      expect(times, [0, 5, 10]);
    });

    test('waits until Dropbear listens, then unlocks', () async {
      final w = World()..server.prebootDelay = const Duration(seconds: 30);
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(resultOf(events), FinalState.unlocked, reason: messages(events));
      expect(w.clock.elapsed, greaterThan(const Duration(seconds: 30)));
    });

    test('fallback addresses are tried in order', () async {
      final w = World();
      final a = w.server.preboot.first;
      const b = Endpoint('srv0-b', 2222);
      const down = Endpoint('down', 2222);
      w.server.preboot.add(b);
      final events = await runAll(w.engine(), [
        w.plan(w.host(preboot: [down, b, a], postbootHost: 'srv0')),
      ]);
      expect(resultOf(events), FinalState.unlocked);
      expect(w.reach.calls.map((c) => c.$1).take(2), [down, b]);
      expect(w.ssh.connectedTo.first, b);
    });
  });

  group('step 3, verifying host key', () {
    test('differs: Host key mismatch, no login, nothing sent', () async {
      final w = World()..server.prebootKey = otherKey;
      final events = await runAll(w.engine(), [
        w.plan(w.host(prebootKey: preKey)),
      ]);
      final last = events.last;
      expect(last.result, FinalState.hostKeyMismatch);
      expect(last.presentedKey, otherKey);
      expect(w.server.authAttempts, 0);
      expect(w.server.received, isEmpty);
      expect(
        events.map((e) => e.phase),
        isNot(contains(HostPhase.authenticating)),
      );
    });

    test('pinned: only the pinned key type is offered', () async {
      final w = World();
      await runAll(w.engine(), [w.plan(w.host())]);
      expect(w.ssh.offeredTypes.first, 'ssh-ed25519');
    });

    test('server lacks the pinned key type: Host key mismatch', () async {
      final w = World()
        ..server.prebootKey = HostKey(
          'ecdsa-sha2-nistp256',
          preKey.fingerprint,
        );
      final events = await runAll(w.engine(), [
        w.plan(w.host(prebootKey: preKey)),
      ]);
      expect(resultOf(events), FinalState.hostKeyMismatch);
      expect(events.last.message, contains('offers no ssh-ed25519'));
      expect(w.server.authAttempts, 0);
    });

    test('equals the known post-boot key: Already up', () async {
      final w = World();
      w.server.bootNow();
      w.server.postboot = w.server.preboot.first;
      final host = w.host(
        check: PostBootCheck.none,
        postbootPort: 2222,
        postbootKey: postKey,
      );
      final events = await runAll(w.engine(), [w.plan(host)]);
      expect(w.ssh.connectedTo, isNotEmpty);
      expect(resultOf(events), FinalState.alreadyUp, reason: messages(events));
      expect(w.server.authAttempts, 0);
    });

    test('not pinned, confirmed: continues and reports the new key', () async {
      final w = World();
      final prompt = FakePrompt(true);
      final events = await runAll(w.engine(prompt: prompt), [
        w.plan(w.host(pinned: false)),
      ]);
      expect(prompt.asked, [preKey]);
      expect(w.ssh.offeredTypes.first, isNull);
      expect(events.where((e) => e.newPrebootKey == preKey), hasLength(1));
      expect(resultOf(events), FinalState.unlocked);
    });

    test('not pinned, declined: Cancelled', () async {
      final w = World();
      final events = await runAll(w.engine(prompt: FakePrompt(false)), [
        w.plan(w.host(pinned: false)),
      ]);
      expect(resultOf(events), FinalState.cancelled);
      expect(w.server.authAttempts, 0);
    });

    test(
      'not pinned and nobody to ask: refused as Host key mismatch',
      () async {
        final w = World();
        final events = await runAll(w.engine(), [
          w.plan(w.host(pinned: false)),
        ]);
        expect(resultOf(events), FinalState.hostKeyMismatch);
        expect(events.last.message, contains('not pinned'));
        expect(events.last.presentedKey, preKey);
        expect(w.server.authAttempts, 0);
      },
    );

    test('other hosts keep running while one waits for confirmation', () async {
      final w = World(servers: 2);
      final events = await runAll(
        w.engine(prompt: FakePrompt(null)),
        [w.plan(w.host(index: 0, pinned: false)), w.plan(w.host(index: 1))],
        onEvent: (engine, ev) {
          if (ev.last.hostId == 'h1' && ev.last.isFinal) {
            engine.cancelHost('h0');
          }
        },
      );
      expect(resultOf(events, 'h1'), FinalState.unlocked);
      expect(resultOf(events, 'h0'), FinalState.cancelled);
    });

    test('unreachable during key exchange keeps waiting', () async {
      final w = World();
      w.ssh.forcedFailures.addAll([
        const SshUnreachable('reset'),
        const SshTimedOut('slow'),
        const SshConnectionLost('closed'),
      ]);
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(resultOf(events), FinalState.unlocked, reason: messages(events));
      expect(w.ssh.connectedTo, hasLength(greaterThanOrEqualTo(4)));
    });

    test('protocol failure: Error', () async {
      final w = World();
      w.ssh.forcedFailures.add(const SshProtocolFailure('no common cipher'));
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(resultOf(events), FinalState.error);
      expect(events.last.message, contains('no common cipher'));
    });
  });

  group('step 4, authenticating', () {
    test('rejected: Auth failed, nothing sent', () async {
      final w = World()..server.authorized = false;
      final events = await runAll(w.engine(), [w.plan(w.host())]);
      expect(resultOf(events), FinalState.authFailed);
      expect(w.server.received, isEmpty);
      expect(w.server.execs, 0);
    });
  });

  group('step 6, waiting for boot', () {
    test(
      'boot confirmed by a new key: Unlocked, post-boot key reported',
      () async {
        final w = World();
        final events = await runAll(w.engine(), [w.plan(w.host())]);
        expect(resultOf(events), FinalState.unlocked);
        final recorded = events.where((e) => e.newPostbootKey != null).toList();
        expect(recorded.single.newPostbootKey, postKey);
        expect(recorded.single.newPostbootKey, isNot(preKey));
        expect(recorded.single.phase, HostPhase.waitingForBoot);
      },
    );

    test('a known post-boot key must match', () async {
      final w = World();
      final events = await runAll(w.engine(), [
        w.plan(w.host(postbootKey: postKey)),
      ]);
      expect(resultOf(events), FinalState.unlocked);
      expect(events.where((e) => e.newPostbootKey != null), isEmpty);
    });

    test('a different post-boot key: warning, boot not confirmed', () async {
      final w = World()..server.postbootKey = otherKey;
      final events = await runAll(w.engine(), [
        w.plan(
          w.host(
            postbootKey: postKey,
            bootTimeout: const Duration(seconds: 20),
          ),
        ),
      ]);
      expect(resultOf(events), FinalState.unlockedBootNotConfirmed);
      expect(
        events.where((e) => e.message.startsWith('warning:')),
        hasLength(1),
      );
    });

    test(
      'never boots: Unlocked, boot not confirmed after the boot timeout',
      () async {
        final w = World()..server.neverBoots = true;
        final events = await runAll(w.engine(), [
          w.plan(w.host(bootTimeout: const Duration(minutes: 5))),
        ]);
        expect(resultOf(events), FinalState.unlockedBootNotConfirmed);
        final start = events
            .firstWhere((e) => e.phase == HostPhase.waitingForBoot)
            .time;
        expect(events.last.time.difference(start), const Duration(minutes: 5));
      },
    );

    test('tcp check confirms the boot', () async {
      final w = World();
      final events = await runAll(w.engine(), [
        w.plan(w.host(check: PostBootCheck.tcp)),
      ]);
      expect(resultOf(events), FinalState.unlocked);
      expect(w.ssh.probed, isEmpty);
    });
  });

  group('parallel hosts', () {
    test('run concurrently with their own results', () async {
      final w = World(servers: 3);
      w.servers[1].passphrase = 'other-fake-pass';
      w.servers[2].absent = true;
      final events = await runAll(w.engine(), [
        w.plan(w.host(index: 0)),
        w.plan(w.host(index: 1)),
        w.plan(w.host(index: 2, waitTimeout: const Duration(seconds: 20))),
      ]);
      expect(resultOf(events, 'h0'), FinalState.unlocked);
      expect(resultOf(events, 'h1'), FinalState.wrongPassphrase);
      expect(resultOf(events, 'h2'), FinalState.prebootTimeout);
      expect(w.clock.elapsed, lessThan(const Duration(seconds: 30)));
    });

    test('duplicate host ids are refused', () {
      final w = World();
      expect(
        () => w.engine().run([w.plan(w.host()), w.plan(w.host())]),
        throwsArgumentError,
      );
    });
  });
}
