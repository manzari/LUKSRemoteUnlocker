import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unlock_core/vault.dart';

import '../data/drift_vault_store.dart';
import '../data/settings_repository.dart';
import 'biometric_slot.dart';

/// Delay before a wrong password is reported, by the number of consecutive failures.
typedef PasswordBackoff = Duration Function(int consecutiveFailures);

/// None for the first two failures, then 1 s doubling up to 30 s.
Duration defaultPasswordBackoff(int failures) => failures < 3
    ? Duration.zero
    : Duration(seconds: math.min(30, 1 << math.min(failures - 3, 5)));

/// Everything the vault controller depends on; tests swap in fakes.
final class VaultDeps {
  const VaultDeps({
    required this.store,
    required this.biometrics,
    required this.settings,
    this.kdf = argon2idInIsolate,
    this.params = Argon2Params.defaults,
    this.autoLockAfter = const Duration(minutes: 2),
    this.passwordBackoff = defaultPasswordBackoff,
  });

  final ResettableVaultStore store;
  final BiometricSlotPlatform biometrics;
  final VaultSettings settings;
  final PasswordKdf kdf;
  final Argon2Params params;
  final Duration autoLockAfter;
  final PasswordBackoff passwordBackoff;
}

enum VaultPhase { loading, needsSetup, locked, unlocked, failed }

@immutable
final class VaultStatus {
  const VaultStatus({
    required this.phase,
    this.hasPasswordSlot = false,
    this.biometricEnrolled = false,
    this.biometricAvailable = false,
    this.biometricInvalidated = false,
    this.allowDeviceCredential = false,
    this.error,
  });

  final VaultPhase phase;
  final bool hasPasswordSlot;
  final bool biometricEnrolled;

  /// The platform can do biometric authentication right now.
  final bool biometricAvailable;

  /// A biometric read failed because the platform invalidated the slot.
  final bool biometricInvalidated;
  final bool allowDeviceCredential;

  /// Why loading failed; shown through describeError, never raw.
  final Object? error;

  bool get isUnlocked => phase == VaultPhase.unlocked;

  bool get canUseBiometrics =>
      biometricEnrolled && biometricAvailable && !biometricInvalidated;

  VaultStatus copyWith({
    VaultPhase? phase,
    bool? hasPasswordSlot,
    bool? biometricEnrolled,
    bool? biometricAvailable,
    bool? biometricInvalidated,
    bool? allowDeviceCredential,
  }) => VaultStatus(
    phase: phase ?? this.phase,
    hasPasswordSlot: hasPasswordSlot ?? this.hasPasswordSlot,
    biometricEnrolled: biometricEnrolled ?? this.biometricEnrolled,
    biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    biometricInvalidated: biometricInvalidated ?? this.biometricInvalidated,
    allowDeviceCredential: allowDeviceCredential ?? this.allowDeviceCredential,
  );

  @override
  bool operator ==(Object other) =>
      other is VaultStatus &&
      other.phase == phase &&
      other.hasPasswordSlot == hasPasswordSlot &&
      other.biometricEnrolled == biometricEnrolled &&
      other.biometricAvailable == biometricAvailable &&
      other.biometricInvalidated == biometricInvalidated &&
      other.allowDeviceCredential == allowDeviceCredential &&
      other.error == error;

  @override
  int get hashCode => Object.hash(
    phase,
    hasPasswordSlot,
    biometricEnrolled,
    biometricAvailable,
    biometricInvalidated,
    allowDeviceCredential,
    error,
  );
}

/// Owns the one in-memory [Vault]: setup, unlock, auto-lock and slot management.
class VaultController extends Notifier<VaultStatus> {
  VaultController(this._depsProvider);

  final Provider<VaultDeps> _depsProvider;
  late VaultDeps _deps;
  Vault? _vault;
  Timer? _idle;
  int _busy = 0;
  BiometricStoreRef _storeRef = const BiometricStoreRef(
    allowDeviceCredential: false,
  );
  int _passwordFailures = 0;
  Future<void>? _penalty;

  @override
  VaultStatus build() {
    _deps = ref.watch(_depsProvider);
    ref.onDispose(() {
      _idle?.cancel();
      _vault?.lock();
      _vault = null;
    });
    unawaited(_load());
    return const VaultStatus(phase: VaultPhase.loading);
  }

  Vault? get unlockedVault => (_vault?.isUnlocked ?? false) ? _vault : null;

  VaultKeyStore get _keyStore => _deps.biometrics.keyStore(_storeRef);

  Future<void> _load() async {
    try {
      _storeRef = await _deps.settings.biometricStore();
      final available = await _deps.biometrics.isAvailable();
      final base = VaultStatus(
        phase: VaultPhase.needsSetup,
        biometricAvailable: available,
        allowDeviceCredential: _storeRef.allowDeviceCredential,
      );
      if (!await Vault.exists(_deps.store)) {
        _set(base);
        return;
      }
      final vault = await Vault.open(_deps.store, kdf: _deps.kdf);
      if (!vault.hasPasswordSlot && !vault.biometricSlotEnrolled) {
        _set(base);
        return;
      }
      _vault = vault;
      _set(_fromVault(base.copyWith(phase: VaultPhase.locked)));
    } on Object catch (e) {
      _set(VaultStatus(phase: VaultPhase.failed, error: e));
    }
  }

  /// Re-reads whether the biometric slot can be offered (e.g. after enrolling a fingerprint).
  Future<void> refreshCapabilities() async {
    final available = await _deps.biometrics.isAvailable();
    _set(state.copyWith(biometricAvailable: available));
  }

  Future<void> setUp({Uint8List? password, required bool biometric}) =>
      _guard(() async {
        if (state.phase != VaultPhase.needsSetup) {
          throw StateError('The vault is already set up');
        }
        if (password == null && !biometric) {
          throw ArgumentError('A password or biometric slot is required');
        }
        if (await Vault.exists(_deps.store)) await _deps.store.reset();
        final vault = await Vault.create(_deps.store, kdf: _deps.kdf);
        try {
          if (biometric) await _enrollInto(vault, _storeRef);
          if (password != null) {
            await vault.setPassword(password, params: _deps.params);
          }
        } catch (_) {
          vault.lock();
          await _deps.store.reset();
          rethrow;
        }
        _vault = vault;
        _onUnlocked(biometricInvalidated: false);
      });

  Future<void> unlockWithPassword(Uint8List password) => _guard(() async {
    final vault = _requireVault();
    await _passwordAttempt(() => vault.unlockWithPassword(password));
    _onUnlocked();
  });

  /// Shows the platform prompt; marks the slot invalidated when the platform dropped it.
  Future<void> unlockWithBiometrics() => _guard(() async {
    try {
      await _requireVault().unlockWithKeyStore(_keyStore);
    } on VaultKeyInvalidatedException {
      _set(state.copyWith(biometricInvalidated: true));
      rethrow;
    }
    _onUnlocked(biometricInvalidated: false);
  });

  /// Opens with the recovery password, then enrolls a new biometric slot.
  Future<void> recover(Uint8List password) => _guard(() async {
    final vault = _requireVault();
    await _passwordAttempt(() => vault.unlockWithPassword(password));
    _onUnlocked();
    await enrollBiometrics();
  });

  void lock() {
    _idle?.cancel();
    _vault?.lock();
    if (state.phase == VaultPhase.unlocked) {
      _set(state.copyWith(phase: VaultPhase.locked));
    }
  }

  /// Locks unless a prompt or vault operation is in progress (a PIN screen pauses the app).
  void appBackgrounded() {
    if (_busy == 0) lock();
  }

  void touch() {
    if (state.isUnlocked) _restartIdle();
  }

  /// Adds the missing password slot; replacing one goes through [changePassword].
  Future<void> addPassword(Uint8List password) => _guard(() async {
    final vault = _requireUnlocked();
    if (vault.hasPasswordSlot) {
      throw StateError('A password is already set; change it instead');
    }
    await vault.setPassword(password, params: _deps.params);
    _set(_fromVault(state));
  });

  /// Needs the current password, which also unlocks a locked vault.
  Future<void> changePassword(Uint8List current, Uint8List next) =>
      _guard(() async {
        final vault = _requireVault();
        await _passwordAttempt(() => vault.unlockWithPassword(current));
        _onUnlocked();
        await vault.changePassword(next, params: _deps.params);
        _set(_fromVault(state));
      });

  /// Removing needs the biometric slot to prove it still opens the vault.
  Future<void> removePassword() => _guard(() async {
    final vault = _requireUnlocked();
    if (!vault.biometricSlotEnrolled) {
      throw const VaultNoSlotException('refusing to remove the last slot');
    }
    await vault.removePasswordSlot(_keyStore);
    _set(_fromVault(state));
  });

  /// Writes the vault key into the other store; a working current store stays until that succeeded.
  Future<void> enrollBiometrics() => _guard(() async {
    final vault = _requireUnlocked();
    // An invalidated store opens nothing, so it is rewritten in place, which also renews its platform key.
    final live = vault.biometricSlotEnrolled && !state.biometricInvalidated;
    await _enrollInto(vault, live ? _storeRef.other : _storeRef);
    _set(_fromVault(state).copyWith(biometricInvalidated: false));
  });

  /// Moves the vault key into a store with the other fallback option.
  Future<void> setAllowDeviceCredential(bool value) => _guard(() async {
    if (value == _storeRef.allowDeviceCredential) return;
    final vault = _requireUnlocked();
    final target = BiometricStoreRef(
      allowDeviceCredential: value,
      alternate: _storeRef.alternate,
    );
    if (vault.biometricSlotEnrolled) {
      await _enrollInto(vault, target);
    } else {
      await _deps.settings.setBiometricStore(target);
      _storeRef = target;
    }
    _set(
      _fromVault(state)
          .copyWith(allowDeviceCredential: value, biometricInvalidated: false),
    );
  });

  /// Wipes the vault, all keys and passphrases; hosts stay but lose their assignments.
  Future<void> reset() => _guard(() async {
    lock();
    _vault = null;
    _passwordFailures = 0;
    await _deps.store.reset();
    await _deps.biometrics.deleteAll();
    _set(const VaultStatus(phase: VaultPhase.loading));
    await _load();
  });

  /// Write [target], point the settings at it, then drop the old store; [target] must not be a working store.
  Future<void> _enrollInto(Vault vault, BiometricStoreRef target) async {
    final previous = _storeRef;
    final store = _deps.biometrics.keyStore(target);
    await store.delete();
    await vault.enrollKeyStore(store);
    await _deps.settings.setBiometricStore(target);
    _storeRef = target;
    if (previous == target) return;
    try {
      await _deps.biometrics.keyStore(previous).delete();
    } on Object {
      // The new store already works; a leftover is deleted before that store is used again.
    }
  }

  /// Consecutive wrong passwords delay the error; later attempts wait for a pending delay first.
  Future<void> _passwordAttempt(Future<void> Function() check) async {
    final pending = _penalty;
    if (pending != null) await pending;
    try {
      await check();
      _passwordFailures = 0;
    } on VaultWrongPasswordException {
      final delay = _deps.passwordBackoff(++_passwordFailures);
      if (delay > Duration.zero) {
        final penalty = _penalty = Future<void>.delayed(delay);
        await penalty;
        if (identical(_penalty, penalty)) _penalty = null;
      }
      rethrow;
    }
  }

  Vault _requireVault() =>
      _vault ?? (throw const VaultNotInitializedException());

  Vault _requireUnlocked() =>
      unlockedVault ?? (throw const VaultLockedException());

  void _onUnlocked({bool? biometricInvalidated}) {
    _set(
      _fromVault(state).copyWith(
        phase: VaultPhase.unlocked,
        biometricInvalidated: biometricInvalidated,
      ),
    );
    _restartIdle();
  }

  VaultStatus _fromVault(VaultStatus s) {
    final vault = _vault;
    if (vault == null) return s;
    return s.copyWith(
      hasPasswordSlot: vault.hasPasswordSlot,
      biometricEnrolled: vault.biometricSlotEnrolled,
    );
  }

  void _restartIdle() {
    _idle?.cancel();
    _idle = Timer(_deps.autoLockAfter, lock);
  }

  void _set(VaultStatus s) {
    if (ref.mounted) state = s;
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    _busy++;
    try {
      return await body();
    } finally {
      _busy--;
    }
  }
}
