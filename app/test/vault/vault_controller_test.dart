import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/providers.dart';
import 'package:luks_remote_unlocker/vault/biometric_slot.dart';
import 'package:luks_remote_unlocker/vault/vault_controller.dart';
import 'package:unlock_core/vault.dart';

import '../support/harness.dart';

final class _Env {
  _Env({
    BiometricSlotPlatform? biometrics,
    MemoryVaultStore? store,
    MemorySettings? settings,
  }) : biometrics = biometrics ?? const NoBiometricSlot(),
       store = store ?? MemoryVaultStore(),
       settings = settings ?? MemorySettings() {
    container = ProviderContainer(
      overrides: [
        vaultDepsProvider.overrideWithValue(
          VaultDeps(
            store: this.store,
            biometrics: this.biometrics,
            settings: this.settings,
            kdf: fakeKdf,
            params: fastParams,
          ),
        ),
      ],
    );
    container.listen(vaultControllerProvider, (_, _) {});
  }

  final BiometricSlotPlatform biometrics;
  final MemoryVaultStore store;
  final MemorySettings settings;
  late final ProviderContainer container;

  VaultController get vault => container.read(vaultControllerProvider.notifier);
  VaultStatus get status => container.read(vaultControllerProvider);
  FakeBiometricSlot get fake => biometrics as FakeBiometricSlot;

  Future<void> loaded() async {
    for (var i = 0; i < 100 && status.phase == VaultPhase.loading; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  late List<_Env> envs;

  setUp(() => envs = []);
  tearDown(() {
    for (final e in envs) {
      e.container.dispose();
    }
  });

  Future<_Env> env({
    BiometricSlotPlatform? biometrics,
    MemoryVaultStore? store,
    MemorySettings? settings,
  }) async {
    final e = _Env(biometrics: biometrics, store: store, settings: settings);
    envs.add(e);
    await e.loaded();
    return e;
  }

  group('password-only platform (Linux)', () {
    test('setup, lock, wrong and right password', () async {
      final e = await env();
      expect(e.status.phase, VaultPhase.needsSetup);
      expect(e.status.biometricAvailable, isFalse);

      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: false,
      );
      expect(e.status.phase, VaultPhase.unlocked);
      expect(e.status.hasPasswordSlot, isTrue);
      expect(e.status.biometricEnrolled, isFalse);
      expect(e.vault.unlockedVault, isNotNull);

      e.vault.lock();
      expect(e.status.phase, VaultPhase.locked);
      expect(e.vault.unlockedVault, isNull);
      await expectLater(
        e.vault.unlockWithPassword(bytesOf('FAKE-wrong-password')),
        throwsA(isA<VaultWrongPasswordException>()),
      );
      expect(e.status.phase, VaultPhase.locked);
      await e.vault.unlockWithPassword(bytesOf(fakeMasterPassword));
      expect(e.status.phase, VaultPhase.unlocked);
    });

    test('setup needs a password when there is no biometric slot', () async {
      final e = await env();
      await expectLater(
        e.vault.setUp(password: null, biometric: false),
        throwsArgumentError,
      );
      expect(e.status.phase, VaultPhase.needsSetup);
    });

    test('an existing vault opens locked after restart', () async {
      final store = MemoryVaultStore();
      final first = await env(store: store);
      await first.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: false,
      );
      final second = await env(store: store);
      expect(second.status.phase, VaultPhase.locked);
      expect(second.status.hasPasswordSlot, isTrue);
    });

    test('a vault without any slot is set up again', () async {
      final store = MemoryVaultStore();
      await Vault.create(store, kdf: fakeKdf);
      final e = await env(store: store);
      expect(e.status.phase, VaultPhase.needsSetup);
      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: false,
      );
      expect(e.status.phase, VaultPhase.unlocked);
    });

    test('change password needs the current one', () async {
      final e = await env();
      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: false,
      );
      await expectLater(
        e.vault.changePassword(
          bytesOf('FAKE-wrong-password'),
          bytesOf('FAKE-new-master-password'),
        ),
        throwsA(isA<VaultWrongPasswordException>()),
      );
      await e.vault.changePassword(
        bytesOf(fakeMasterPassword),
        bytesOf('FAKE-new-master-password'),
      );
      e.vault.lock();
      await expectLater(
        e.vault.unlockWithPassword(bytesOf(fakeMasterPassword)),
        throwsA(isA<VaultWrongPasswordException>()),
      );
      await e.vault.unlockWithPassword(bytesOf('FAKE-new-master-password'));
      expect(e.status.isUnlocked, isTrue);
    });

    test('change password works from a locked vault and unlocks it', () async {
      final e = await env();
      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: false,
      );
      e.vault.lock();
      await e.vault.changePassword(
        bytesOf(fakeMasterPassword),
        bytesOf('FAKE-new-master-password'),
      );
      expect(e.status.isUnlocked, isTrue);
      e.vault.lock();
      await e.vault.unlockWithPassword(bytesOf('FAKE-new-master-password'));
    });

    test('adding a password never replaces an existing one', () async {
      final e = await env();
      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: false,
      );
      await expectLater(
        e.vault.addPassword(bytesOf('FAKE-new-master-password')),
        throwsStateError,
      );
      e.vault.lock();
      await e.vault.unlockWithPassword(bytesOf(fakeMasterPassword));
    });

    test('the load error is kept as an object, not as text', () async {
      final e = await env(
        store: MemoryVaultStore()
          ..metadataError = const VaultCorruptException('FAKE unreadable'),
      );
      expect(e.status.phase, VaultPhase.failed);
      expect(e.status.error, isA<VaultCorruptException>());
    });
  });

  group('wrong-password backoff', () {
    test('delays from the third consecutive failure, resets on success', () {
      fakeAsync((async) {
        final e = _Env();
        envs.add(e);
        async.flushMicrotasks();
        unawaited(
          e.vault.setUp(
            password: bytesOf(fakeMasterPassword),
            biometric: false,
          ),
        );
        async.flushMicrotasks();
        e.vault.lock();

        Object? outcome;
        void attempt(String password) {
          outcome = null;
          unawaited(
            e.vault
                .unlockWithPassword(bytesOf(password))
                .then<void>(
                  (_) => outcome = 'ok',
                  onError: (Object error) => outcome = error,
                ),
          );
          async.flushMicrotasks();
        }

        final wrong = isA<VaultWrongPasswordException>();
        attempt('FAKE-wrong-1');
        expect(outcome, wrong);
        attempt('FAKE-wrong-2');
        expect(outcome, wrong);
        attempt('FAKE-wrong-3');
        expect(outcome, isNull);
        async.elapse(const Duration(milliseconds: 999));
        expect(outcome, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(outcome, wrong);
        attempt('FAKE-wrong-4');
        async.elapse(const Duration(milliseconds: 1999));
        expect(outcome, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(outcome, wrong);

        attempt(fakeMasterPassword);
        expect(outcome, 'ok');
        expect(e.status.isUnlocked, isTrue);
        e.vault.lock();
        attempt('FAKE-wrong-5');
        expect(outcome, wrong);
      });
    });

    test('the schedule grows and is capped', () {
      expect(defaultPasswordBackoff(1), Duration.zero);
      expect(defaultPasswordBackoff(2), Duration.zero);
      expect(defaultPasswordBackoff(3), const Duration(seconds: 1));
      expect(defaultPasswordBackoff(5), const Duration(seconds: 4));
      expect(defaultPasswordBackoff(8), const Duration(seconds: 30));
      expect(defaultPasswordBackoff(1000), const Duration(seconds: 30));
    });
  });

  group('biometric platform (Android)', () {
    test('setup enrolls the slot and keeps the recovery password', () async {
      final e = await env(biometrics: FakeBiometricSlot());
      expect(e.status.biometricAvailable, isTrue);
      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: true,
      );
      expect(e.status.biometricEnrolled, isTrue);
      expect(e.status.hasPasswordSlot, isTrue);
      expect(e.fake.stores[false]!.hasKey, isTrue);

      e.vault.lock();
      await e.vault.unlockWithBiometrics();
      expect(e.status.isUnlocked, isTrue);
      expect(e.fake.stores[false]!.readCount, 1);
    });

    test('setup without recovery password', () async {
      final e = await env(biometrics: FakeBiometricSlot());
      await e.vault.setUp(password: null, biometric: true);
      expect(e.status.hasPasswordSlot, isFalse);
      expect(e.status.biometricEnrolled, isTrue);
      await e.vault.addPassword(bytesOf(fakeMasterPassword));
      expect(e.status.hasPasswordSlot, isTrue);
    });

    group('re-enrolment keeps the only slot until the new one is written', () {
      Future<_Env> biometricOnly() async {
        final e = await env(biometrics: FakeBiometricSlot());
        await e.vault.setUp(password: null, biometric: true);
        return e;
      }

      Future<void> expectOldSlotStillOpens(_Env e) async {
        expect(e.status.biometricEnrolled, isTrue);
        expect(e.fake.stores[false]!.hasKey, isTrue);
        expect(e.settings.alternate, isFalse);
        e.vault.lock();
        await e.vault.unlockWithBiometrics();
        expect(e.status.isUnlocked, isTrue);
        final restarted = await env(
          biometrics: e.biometrics,
          store: e.store,
          settings: e.settings,
        );
        await restarted.vault.unlockWithBiometrics();
        expect(restarted.status.isUnlocked, isTrue);
      }

      test('cancelled prompt', () async {
        final e = await biometricOnly();
        e.fake.cancelWrites = true;
        await expectLater(
          e.vault.enrollBiometrics(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        e.fake.cancelWrites = false;
        await expectOldSlotStillOpens(e);
      });

      test('failed write', () async {
        final e = await biometricOnly();
        e.fake.writeError = VaultKeyUnavailableException(
          VaultKeyUnavailableReason.unavailable,
        );
        await expectLater(
          e.vault.enrollBiometrics(),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        e.fake.writeError = null;
        await expectOldSlotStillOpens(e);
      });

      test('crash after the write, before the settings moved', () async {
        final e = await biometricOnly();
        e.settings.writeError = StateError('FAKE crash');
        await expectLater(e.vault.enrollBiometrics(), throwsStateError);
        e.settings.writeError = null;
        await expectOldSlotStillOpens(e);
      });

      test('success moves to the other store and drops the old one', () async {
        final e = await biometricOnly();
        await e.vault.enrollBiometrics();
        expect(e.settings.alternate, isTrue);
        expect(e.fake.alternates[false]!.hasKey, isTrue);
        expect(e.fake.stores[false]!.hasKey, isFalse);

        final restarted = await env(
          biometrics: e.biometrics,
          store: e.store,
          settings: e.settings,
        );
        await restarted.vault.unlockWithBiometrics();
        expect(restarted.status.isUnlocked, isTrue);

        await restarted.vault.enrollBiometrics();
        expect(e.settings.alternate, isFalse);
        expect(e.fake.stores[false]!.hasKey, isTrue);
        expect(e.fake.alternates[false]!.hasKey, isFalse);
      });

      test('an old store that cannot be deleted is left behind, then cleared '
          'before reuse', () async {
        final e = await biometricOnly();
        const primary = BiometricStoreRef(allowDeviceCredential: false);
        e.fake.failingDeletes.add(primary);
        await e.vault.enrollBiometrics();
        expect(e.settings.alternate, isTrue);
        expect(e.fake.stores[false]!.hasKey, isTrue);

        await expectLater(e.vault.enrollBiometrics(), throwsStateError);
        expect(e.settings.alternate, isTrue);
        e.vault.lock();
        await e.vault.unlockWithBiometrics();
        expect(e.fake.alternates[false]!.readCount, 1);

        e.fake.failingDeletes.clear();
        await e.vault.enrollBiometrics();
        expect(e.settings.alternate, isFalse);
        expect(e.fake.alternates[false]!.hasKey, isFalse);
      });
    });

    test('a cancelled enrollment leaves no half-made vault', () async {
      final e = await env(biometrics: FakeBiometricSlot());
      e.fake.cancelWrites = true;
      await expectLater(
        e.vault.setUp(password: bytesOf(fakeMasterPassword), biometric: true),
        throwsA(isA<VaultKeyUnavailableException>()),
      );
      expect(e.status.phase, VaultPhase.needsSetup);
      expect(await Vault.exists(e.store), isFalse);
      e.fake.cancelWrites = false;
      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: true,
      );
      expect(e.status.isUnlocked, isTrue);
    });

    test(
      'invalidated slot: explain, recover with password, re-enroll',
      () async {
        final e = await env(biometrics: FakeBiometricSlot());
        await e.vault.setUp(
          password: bytesOf(fakeMasterPassword),
          biometric: true,
        );
        e.vault.lock();
        e.fake.stores[false]!.invalidate();

        await expectLater(
          e.vault.unlockWithBiometrics(),
          throwsA(isA<VaultKeyInvalidatedException>()),
        );
        expect(e.status.biometricInvalidated, isTrue);
        expect(e.status.canUseBiometrics, isFalse);
        expect(e.status.phase, VaultPhase.locked);

        await e.vault.recover(bytesOf(fakeMasterPassword));
        expect(e.status.isUnlocked, isTrue);
        expect(e.status.biometricInvalidated, isFalse);
        expect(e.settings.alternate, isFalse, reason: 'dead store rewritten');
        expect(e.fake.alternates[false]!.hasKey, isFalse);

        e.vault.lock();
        await e.vault.unlockWithBiometrics();
        expect(e.status.isUnlocked, isTrue);
      },
    );

    test('cancelled prompt keeps the vault locked', () async {
      final e = await env(biometrics: FakeBiometricSlot());
      await e.vault.setUp(password: null, biometric: true);
      e.vault.lock();
      e.fake.stores[false]!.unavailable =
          VaultKeyUnavailableReason.userCancelled;
      await expectLater(
        e.vault.unlockWithBiometrics(),
        throwsA(isA<VaultKeyUnavailableException>()),
      );
      expect(e.status.phase, VaultPhase.locked);
      expect(e.status.biometricInvalidated, isFalse);
    });

    test('PIN fallback switch moves the key to the other store', () async {
      final e = await env(biometrics: FakeBiometricSlot());
      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: true,
      );
      await e.vault.setAllowDeviceCredential(true);
      expect(e.status.allowDeviceCredential, isTrue);
      expect(e.settings.value, isTrue);
      expect(e.fake.stores[true]!.hasKey, isTrue);
      expect(e.fake.stores[false]!.hasKey, isFalse);

      e.vault.lock();
      await e.vault.unlockWithBiometrics();
      expect(e.fake.stores[true]!.readCount, 1);

      await e.vault.setAllowDeviceCredential(false);
      expect(e.fake.stores[false]!.hasKey, isTrue);
      expect(e.fake.stores[true]!.hasKey, isFalse);
    });

    test(
      'PIN fallback switch: every failure point leaves a working slot',
      () async {
        final e = await env(biometrics: FakeBiometricSlot());
        await e.vault.setUp(password: null, biometric: true);

        e.fake.cancelWrites = true;
        await expectLater(
          e.vault.setAllowDeviceCredential(true),
          throwsA(isA<VaultKeyUnavailableException>()),
        );
        e.fake.cancelWrites = false;
        expect(e.status.allowDeviceCredential, isFalse);
        expect(e.settings.value, isFalse);
        expect(e.fake.stores[false]!.hasKey, isTrue);

        e.settings.writeError = StateError('FAKE crash');
        await expectLater(
          e.vault.setAllowDeviceCredential(true),
          throwsStateError,
        );
        e.settings.writeError = null;
        expect(e.settings.value, isFalse);
        expect(e.fake.stores[false]!.hasKey, isTrue);
        final restarted = await env(
          biometrics: e.biometrics,
          store: e.store,
          settings: e.settings,
        );
        await restarted.vault.unlockWithBiometrics();
        expect(restarted.status.allowDeviceCredential, isFalse);

        e.fake.failingDeletes.add(
          const BiometricStoreRef(allowDeviceCredential: false),
        );
        await e.vault.setAllowDeviceCredential(true);
        expect(e.status.allowDeviceCredential, isTrue);
        expect(e.settings.value, isTrue);
        e.vault.lock();
        await e.vault.unlockWithBiometrics();
        expect(e.fake.stores[true]!.readCount, 1);
      },
    );

    test('removing the recovery password needs the biometric slot', () async {
      final e = await env(biometrics: FakeBiometricSlot());
      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: true,
      );
      await e.vault.removePassword();
      expect(e.status.hasPasswordSlot, isFalse);
      expect(e.fake.stores[false]!.readCount, 1);
    });

    test('the only slot cannot be removed', () async {
      final e = await env();
      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: false,
      );
      await expectLater(
        e.vault.removePassword(),
        throwsA(isA<VaultNoSlotException>()),
      );
    });

    test('reset wipes vault and biometric stores', () async {
      final e = await env(biometrics: FakeBiometricSlot());
      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: true,
      );
      await e.vault.reset();
      expect(e.status.phase, VaultPhase.needsSetup);
      expect(await Vault.exists(e.store), isFalse);
      expect(e.fake.stores[false]!.hasKey, isFalse);
    });
  });

  group('auto-lock', () {
    test('locks after 2 minutes without activity; activity restarts', () {
      fakeAsync((async) {
        final e = _Env();
        envs.add(e);
        async.flushMicrotasks();
        expect(e.status.phase, VaultPhase.needsSetup);
        unawaited(
          e.vault.setUp(
            password: bytesOf(fakeMasterPassword),
            biometric: false,
          ),
        );
        async.flushMicrotasks();
        expect(e.status.isUnlocked, isTrue);

        async.elapse(const Duration(seconds: 90));
        e.vault.touch();
        async.elapse(const Duration(seconds: 90));
        expect(e.status.isUnlocked, isTrue);
        async.elapse(const Duration(seconds: 31));
        expect(e.status.phase, VaultPhase.locked);
        expect(e.vault.unlockedVault, isNull);
      });
    });

    test('going to the background locks', () async {
      final e = await env();
      await e.vault.setUp(
        password: bytesOf(fakeMasterPassword),
        biometric: false,
      );
      e.vault.appBackgrounded();
      expect(e.status.phase, VaultPhase.locked);
    });

    test(
      'a prompt in progress (PIN screen pauses the app) is not interrupted',
      () async {
        final e = await env(biometrics: FakeBiometricSlot());
        await e.vault.setUp(password: null, biometric: true);
        e.vault.lock();
        final gate = Completer<void>();
        e.fake.readGate = gate.future;
        final unlocking = e.vault.unlockWithBiometrics();
        await Future<void>.delayed(Duration.zero);
        e.vault.appBackgrounded();
        gate.complete();
        await unlocking;
        expect(e.status.isUnlocked, isTrue);
        e.vault.appBackgrounded();
        expect(e.status.phase, VaultPhase.locked);
      },
    );
  });
}
