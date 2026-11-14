import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unlock_core/vault.dart';

import '../data/drift_vault_store.dart';
import '../data/settings_repository.dart';
import 'biometric_slot.dart';

/// Everything the vault controller depends on; tests swap in fakes.
final class VaultDeps {
  const VaultDeps({
    required this.store,
    required this.biometrics,
    required this.settings,
    this.kdf = argon2idInIsolate,
    this.params = Argon2Params.defaults,
    this.autoLockAfter = const Duration(minutes: 2),
  });

  final ResettableVaultStore store;
  final BiometricSlotPlatform biometrics;
  final VaultSettings settings;
  final PasswordKdf kdf;
  final Argon2Params params;
  final Duration autoLockAfter;
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
  final String? error;

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

  VaultKeyStore get _keyStore => _deps.biometrics.keyStore(
    allowDeviceCredential: state.allowDeviceCredential,
  );

  Future<void> _load() async {
    try {
      final allow = await _deps.settings.allowDeviceCredential();
      final available = await _deps.biometrics.isAvailable();
      final base = VaultStatus(
        phase: VaultPhase.needsSetup,
        biometricAvailable: available,
        allowDeviceCredential: allow,
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
      _set(VaultStatus(phase: VaultPhase.failed, error: '$e'));
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
          if (biometric) await vault.enrollKeyStore(_keyStore);
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
    await _requireVault().unlockWithPassword(password);
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
    await _requireVault().unlockWithPassword(password);
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

  Future<void> setPassword(Uint8List password) => _guard(() async {
    await _requireUnlocked().setPassword(password, params: _deps.params);
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

  /// Writes the vault key into the biometric slot (new or after invalidation).
  Future<void> enrollBiometrics() => _guard(() async {
    await _requireUnlocked().enrollKeyStore(_keyStore);
    _set(_fromVault(state).copyWith(biometricInvalidated: false));
  });

  /// Moves the vault key into the store variant with the other fallback option.
  Future<void> setAllowDeviceCredential(bool value) => _guard(() async {
    if (value == state.allowDeviceCredential) return;
    final vault = _requireUnlocked();
    if (vault.biometricSlotEnrolled) {
      final old = _keyStore;
      await vault.enrollKeyStore(
        _deps.biometrics.keyStore(allowDeviceCredential: value),
      );
      await old.delete();
    }
    await _deps.settings.setAllowDeviceCredential(value);
    _set(
      _fromVault(state)
          .copyWith(allowDeviceCredential: value, biometricInvalidated: false),
    );
  });

  /// Wipes the vault, all keys and passphrases; hosts stay but lose their assignments.
  Future<void> reset() => _guard(() async {
    lock();
    _vault = null;
    await _deps.store.reset();
    await _deps.biometrics.deleteAll();
    _set(const VaultStatus(phase: VaultPhase.loading));
    await _load();
  });

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
