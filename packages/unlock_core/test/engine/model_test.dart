import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:unlock_core/engine.dart';

import 'fakes.dart';

T roundTrip<T>(
  Map<String, Object?> json,
  T Function(Map<String, Object?>) from,
) => from((jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>());

void main() {
  group('Endpoint', () {
    test('parses host, host:port and IPv6', () {
      expect(Endpoint.parse('srv'), const Endpoint('srv', 22));
      expect(Endpoint.parse('srv:2222'), const Endpoint('srv', 2222));
      expect(Endpoint.parse('10.0.0.1:2222'), const Endpoint('10.0.0.1', 2222));
      expect(Endpoint.parse('[fd00::1]:2222'), const Endpoint('fd00::1', 2222));
      expect(Endpoint.parse('fd00::1'), const Endpoint('fd00::1', 22));
      expect(Endpoint.parse('[fd00::1]:2222').toString(), '[fd00::1]:2222');
    });

    test('rejects bad input', () {
      for (final s in ['', ':22', 'srv:0', 'srv:99999', 'srv:x', '[::1']) {
        expect(() => Endpoint.parse(s), throwsFormatException, reason: s);
      }
    });
  });

  group('HostKey', () {
    test('parses with and without type, normalizes RSA signature names', () {
      expect(HostKey.parse('ssh-ed25519 ${preKey.fingerprint}'), preKey);
      expect(HostKey.parse(preKey.fingerprint).type, isNull);
      expect(HostKey('rsa-sha2-256', preKey.fingerprint).type, 'ssh-rsa');
      expect(() => HostKey.parse('SHA256:short'), throwsFormatException);
    });

    test('matches ignores a missing type', () {
      final bare = HostKey(null, preKey.fingerprint);
      expect(bare.matches(preKey), isTrue);
      expect(preKey.matches(bare), isTrue);
      expect(HostKey('ssh-rsa', preKey.fingerprint).matches(preKey), isFalse);
      expect(preKey.matches(postKey), isFalse);
    });
  });

  test('Host round-trips through JSON', () {
    final h = Host(
      id: 'h1',
      name: 'nas',
      group: 'home',
      preboot: [const Endpoint('nas', 2222), const Endpoint('10.0.0.5', 2222)],
      user: 'root',
      keyId: 'k1',
      secretId: 's1',
      diskOverrides: {'sdb1_crypt': 's2'},
      profileId: UnlockProfile.debian.id,
      postbootHost: 'nas.lan',
      postbootPort: 22,
      postbootCheck: PostBootCheck.tcp,
      waitTimeout: const Duration(minutes: 3),
      bootTimeout: const Duration(minutes: 2),
      prebootKey: preKey,
      postbootKey: postKey,
      legacyAlgorithms: true,
      enabled: false,
    );
    expect(roundTrip(h.toJson(), Host.fromJson), h);
    expect(h.postboot, const Endpoint('nas.lan', 22));
    expect(h.validate(), isEmpty);
  });

  test('Host defaults and validation', () {
    final h = Host(id: 'x', name: 'x', preboot: [const Endpoint('a', 22)]);
    expect(h.postboot, const Endpoint('a', 22));
    expect(h.postbootCheck, PostBootCheck.sshHostKey);
    expect(h.waitTimeout, const Duration(minutes: 10));
    expect(h.bootTimeout, const Duration(minutes: 5));
    expect(roundTrip(h.toJson(), Host.fromJson), h);
    expect(h.copyWith(postbootCheck: PostBootCheck.tcp).validate(), [
      contains('tcp check'),
    ]);
    expect(
      () => Host(id: 'x', name: 'x', preboot: const []),
      throwsArgumentError,
    );
  });

  test('UnlockProfile round-trips; Debian is the stdin built-in', () {
    expect(UnlockProfile.debian.driver, UnlockDriverKind.stdin);
    expect(UnlockProfile.debian.command, 'cryptroot-unlock');
    expect(
      roundTrip(UnlockProfile.debian.toJson(), UnlockProfile.fromJson),
      UnlockProfile.debian,
    );
    final copy = UnlockProfile.debian.copyWith(
      id: 'mine',
      builtIn: false,
      command: 'unlock',
    );
    expect(roundTrip(copy.toJson(), UnlockProfile.fromJson), copy);
  });

  test('HostEvent round-trips', () {
    final e = HostEvent(
      hostId: 'h1',
      time: DateTime.utc(2026, 11, 14, 12),
      phase: HostPhase.finished,
      message: 'booted',
      result: FinalState.unlocked,
      newPostbootKey: postKey,
    );
    final back = roundTrip(e.toJson(), HostEvent.fromJson);
    expect(back.toJson(), e.toJson());
    expect(back.isFinal, isTrue);
  });

  group('RunControl', () {
    test('guard returns, times out or is cancelled', () async {
      final clock = FakeClock();
      final c = RunControl(clock);
      expect(
        await c.guard(Future.value(1), timeout: const Duration(seconds: 1)),
        1,
      );
      await expectLater(
        c.guard(Completer<int>().future, timeout: const Duration(seconds: 5)),
        throwsA(isA<RunTimeout>()),
      );
      expect(clock.elapsed, const Duration(seconds: 5));
      final pending = c.guard(Completer<int>().future);
      c.cancel();
      await expectLater(pending, throwsA(isA<RunCancelled>()));
      await expectLater(
        c.sleep(const Duration(seconds: 1)),
        throwsA(isA<RunCancelled>()),
      );
    });

    test('errors pass through', () async {
      final c = RunControl(FakeClock());
      await expectLater(
        c.guard(
          Future<int>.error(const SshAuthFailed('no')),
          timeout: const Duration(seconds: 1),
        ),
        throwsA(isA<SshAuthFailed>()),
      );
    });
  });

  group('DartSsh2Connector.algorithms', () {
    List<String> names(String? only, {bool legacy = false, String? prefer}) =>
        DartSsh2Connector.algorithms(
          legacy: legacy,
          offerOnlyType: only,
          preferType: prefer,
        ).hostkey.map((a) => a.name).toList();

    test('restricts to the pinned type', () {
      expect(names('ssh-ed25519'), ['ssh-ed25519']);
      expect(names('ssh-rsa'), ['rsa-sha2-512', 'rsa-sha2-256']);
      expect(names('ssh-rsa', legacy: true), [
        'rsa-sha2-512',
        'rsa-sha2-256',
        'ssh-rsa',
      ]);
      expect(names('ecdsa-sha2-nistp256'), ['ecdsa-sha2-nistp256']);
    });

    test('prefers a type without dropping others', () {
      expect(
        names(null, prefer: 'ecdsa-sha2-nistp256').first,
        'ecdsa-sha2-nistp256',
      );
      expect(names(null, prefer: 'ecdsa-sha2-nistp256'), hasLength(6));
    });

    test('legacy adds SHA-1 host keys and kex, and CBC', () {
      final a = DartSsh2Connector.algorithms(legacy: true);
      expect(a.hostkey.map((e) => e.name), contains('ssh-rsa'));
      expect(a.kex.map((e) => e.name), contains('diffie-hellman-group14-sha1'));
      expect(a.cipher.map((e) => e.name), contains('aes128-cbc'));
      final modern = DartSsh2Connector.algorithms(legacy: false);
      expect(modern.hostkey.map((e) => e.name), isNot(contains('ssh-rsa')));
      expect(modern.cipher.map((e) => e.name), isNot(contains('aes128-cbc')));
    });
  });
}
