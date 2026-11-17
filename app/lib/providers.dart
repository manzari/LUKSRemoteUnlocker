import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unlock_core/unlock_core.dart';

import 'data/database.dart';
import 'data/drift_vault_store.dart';
import 'data/host_repository.dart';
import 'data/key_repository.dart';
import 'data/profile_repository.dart';
import 'data/secret_repository.dart';
import 'data/settings_repository.dart';
import 'services/config_transfer.dart';
import 'services/key_import.dart';
import 'services/platform_services.dart';
import 'services/run_preparation.dart';
import 'vault/biometric_slot.dart';
import 'vault/vault_controller.dart';

/// Opened in main(); tests override it with an in-memory database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final hostRepositoryProvider = Provider(
  (ref) => HostRepository(ref.watch(databaseProvider)),
);

final keyRepositoryProvider = Provider(
  (ref) => KeyRepository(
    ref.watch(databaseProvider),
    ref.watch(hostRepositoryProvider),
  ),
);

final secretRepositoryProvider = Provider(
  (ref) => SecretRepository(
    ref.watch(databaseProvider),
    ref.watch(hostRepositoryProvider),
  ),
);

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(
    ref.watch(databaseProvider),
    ref.watch(hostRepositoryProvider),
  ),
);

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final vaultStoreProvider = Provider<ResettableVaultStore>(
  (ref) => DriftVaultStore(ref.watch(databaseProvider)),
);

final biometricSlotProvider = Provider<BiometricSlotPlatform>(
  (ref) => BiometricVaultSlot(),
);

final vaultKdfProvider = Provider<PasswordKdf>((ref) => argon2idInIsolate);

final argon2ParamsProvider = Provider<Argon2Params>(
  (ref) => Argon2Params.defaults,
);

final autoLockAfterProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 2),
);

final vaultDepsProvider = Provider(
  (ref) => VaultDeps(
    store: ref.watch(vaultStoreProvider),
    biometrics: ref.watch(biometricSlotProvider),
    settings: ref.watch(settingsRepositoryProvider),
    kdf: ref.watch(vaultKdfProvider),
    params: ref.watch(argon2ParamsProvider),
    autoLockAfter: ref.watch(autoLockAfterProvider),
  ),
);

final vaultControllerProvider = NotifierProvider<VaultController, VaultStatus>(
  () => VaultController(vaultDepsProvider),
);

final hostsProvider = StreamProvider(
  (ref) => ref.watch(hostRepositoryProvider).watchAll(),
);

final keysProvider = StreamProvider(
  (ref) => ref.watch(keyRepositoryProvider).watchAll(),
);

final secretsProvider = StreamProvider(
  (ref) => ref.watch(secretRepositoryProvider).watchAll(),
);

final profilesProvider = StreamProvider(
  (ref) => ref.watch(profileRepositoryProvider).watchAll(),
);

final keyProvider = StreamProvider.family<StoredKey?, String>(
  (ref, id) => ref.watch(keyRepositoryProvider).watch(id),
);

final secretProvider = StreamProvider.family<StoredSecret?, String>(
  (ref, id) => ref.watch(secretRepositoryProvider).watch(id),
);

final keyImporterProvider = Provider<KeyImporter>((ref) => importKeyInIsolate);

final platformServicesProvider = Provider<PlatformServices>(
  (ref) => const PluginPlatformServices(),
);

/// Phase 6 entry: decrypts what a run needs after one unlock.
final runPreparationProvider = Provider(
  (ref) => RunPreparation(
    ref.watch(keyRepositoryProvider),
    ref.watch(secretRepositoryProvider),
    ref.watch(profileRepositoryProvider),
    ref.watch(vaultStoreProvider),
  ),
);

final configTransferProvider = Provider(
  (ref) => ConfigTransfer(
    ref.watch(databaseProvider),
    ref.watch(hostRepositoryProvider),
    ref.watch(keyRepositoryProvider),
    ref.watch(secretRepositoryProvider),
    ref.watch(profileRepositoryProvider),
  ),
);
