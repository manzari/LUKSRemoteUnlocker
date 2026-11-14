import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/app.dart';
import 'package:luks_remote_unlocker/data/database.dart';
import 'package:luks_remote_unlocker/data/drift_vault_store.dart';
import 'package:luks_remote_unlocker/data/settings_repository.dart';
import 'package:luks_remote_unlocker/providers.dart';
import 'package:luks_remote_unlocker/services/key_import.dart';
import 'package:luks_remote_unlocker/services/platform_services.dart';
import 'package:luks_remote_unlocker/vault/biometric_slot.dart';
import 'package:luks_remote_unlocker/vault/vault_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/vault.dart';

const fastParams = Argon2Params(memoryKiB: 64, iterations: 1, parallelism: 1);

Uint8List bytesOf(String text) => utf8.encode(text);

const fakeMasterPassword = 'FAKE-master-password';
const fakePassphraseText = 'FAKE luks passphrase äöü ';

AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

AppDatabase fileDatabase(File file) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(NativeDatabase(file), closeStreamsSynchronously: true),
  );
}

/// Fast deterministic stand-in for Argon2id; different passwords give different keys.
Future<Uint8List> fakeKdf(
  Uint8List password,
  Uint8List salt,
  Argon2Params params,
) async {
  var h = 0x811c9dc5;
  void mix(int b) => h = ((h ^ b) * 0x01000193) & 0xffffffff;
  salt.forEach(mix);
  mix(0xff);
  password.forEach(mix);
  final out = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    mix(i);
    out[i] = h & 0xff;
  }
  return out;
}

final class MemorySettings implements VaultSettings {
  bool value = false;

  @override
  Future<bool> allowDeviceCredential() async => value;

  @override
  Future<void> setAllowDeviceCredential(bool v) async => value = v;
}

final class MemoryVaultStore implements ResettableVaultStore {
  InMemoryVaultStore _inner = InMemoryVaultStore();

  @override
  Future<void> reset() async => _inner = InMemoryVaultStore();

  @override
  Future<VaultMetadata?> readMetadata() => _inner.readMetadata();

  @override
  Future<void> writeMetadata(VaultMetadata m) => _inner.writeMetadata(m);

  @override
  Future<PasswordSlot?> readPasswordSlot() => _inner.readPasswordSlot();

  @override
  Future<void> writePasswordSlot(PasswordSlot s) => _inner.writePasswordSlot(s);

  @override
  Future<void> deletePasswordSlot() => _inner.deletePasswordSlot();

  @override
  Future<VaultRecord?> readRecord(String id) => _inner.readRecord(id);

  @override
  Future<List<String>> listRecordIds() => _inner.listRecordIds();

  @override
  Future<void> writeRecord(VaultRecord r) => _inner.writeRecord(r);

  @override
  Future<void> deleteRecord(String id) => _inner.deleteRecord(id);
}

/// Biometric slot backed by in-memory key stores, one per fallback option.
final class FakeBiometricSlot implements BiometricSlotPlatform {
  FakeBiometricSlot({this.available = true});

  bool available;

  /// When set, writes fail as if the user cancelled the prompt.
  bool cancelWrites = false;

  /// When set, reads wait for it (a prompt the user has not answered yet).
  Future<void>? readGate;

  final Map<bool, InMemoryVaultKeyStore> stores = {
    false: InMemoryVaultKeyStore(),
    true: InMemoryVaultKeyStore(),
  };

  @override
  Future<bool> isAvailable() async => available;

  @override
  VaultKeyStore keyStore({required bool allowDeviceCredential}) =>
      _FakeKeyStore(this, stores[allowDeviceCredential]!);

  @override
  Future<void> deleteAll() async {
    for (final s in stores.values) {
      await s.delete();
    }
  }
}

final class _FakeKeyStore implements VaultKeyStore {
  _FakeKeyStore(this._slot, this._inner);

  final FakeBiometricSlot _slot;
  final InMemoryVaultKeyStore _inner;

  @override
  Future<Uint8List?> read() async {
    await _slot.readGate;
    return _inner.read();
  }

  @override
  Future<void> write(Uint8List key) async {
    if (_slot.cancelWrites) {
      throw VaultKeyUnavailableException(
        VaultKeyUnavailableReason.userCancelled,
      );
    }
    await _inner.write(key);
  }

  @override
  Future<void> delete() => _inner.delete();
}

final class FakePlatformServices implements PlatformServices {
  PickedFile? nextFile;
  final shared = <String>[];

  @override
  Future<PickedFile?> pickKeyFile() async => nextFile;

  @override
  Future<void> sharePublicKey(String line, {required String subject}) async =>
      shared.add(line);
}

final class TestApp {
  TestApp(this.db, this.container, this.biometrics, this.services);

  final AppDatabase db;
  final ProviderContainer container;
  final BiometricSlotPlatform biometrics;
  final FakePlatformServices services;

  VaultController get vault => container.read(vaultControllerProvider.notifier);

  VaultStatus get status => container.read(vaultControllerProvider);
}

List<Override> appOverrides(
  AppDatabase db, {
  required BiometricSlotPlatform biometrics,
  required FakePlatformServices services,
}) => [
  databaseProvider.overrideWithValue(db),
  biometricSlotProvider.overrideWithValue(biometrics),
  vaultKdfProvider.overrideWithValue(fakeKdf),
  argon2ParamsProvider.overrideWithValue(fastParams),
  keyImporterProvider.overrideWithValue(importKeyInline),
  platformServicesProvider.overrideWithValue(services),
];

/// Pumps the whole app on an in-memory database; [setUpVault] creates a password vault and leaves it unlocked.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  BiometricSlotPlatform biometrics = const NoBiometricSlot(),
  bool setUpVault = true,
  Size size = const Size(1000, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = memoryDatabase();
  final services = FakePlatformServices();
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(db, biometrics: biometrics, services: services),
      child: const LuksRemoteUnlockerApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LuksRemoteUnlockerApp)),
  );
  final app = TestApp(db, container, biometrics, services);
  if (setUpVault) {
    await app.vault.setUp(
      password: bytesOf(fakeMasterPassword),
      biometric: false,
    );
    await tester.pumpAndSettle();
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
  return app;
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

/// Types into the password field of the unlock dialog and submits it.
Future<void> unlockViaDialog(
  WidgetTester tester, {
  String password = fakeMasterPassword,
}) async {
  expect(find.text('Unlock the vault'), findsOneWidget);
  await tester.enterText(
    find.byKey(const ValueKey('unlock-password')),
    password,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
  await tester.pumpAndSettle();
}

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Index of [needle] in [haystack], or -1.
int indexOfBytes(Uint8List haystack, List<int> needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

/// Fails when [secret] appears raw, as hex or as base64 (any alignment).
void expectNotInBytes(Uint8List haystack, Uint8List secret, String what) {
  expect(indexOfBytes(haystack, secret), -1, reason: '$what found raw');
  final hex = secret.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  expect(indexOfBytes(haystack, ascii.encode(hex)), -1, reason: '$what hex');
  for (var offset = 0; offset < 3; offset++) {
    final part = secret.sublist(offset);
    final stable = base64.encode(part).substring(0, (part.length ~/ 3) * 4);
    expect(
      indexOfBytes(haystack, ascii.encode(stable)),
      -1,
      reason: '$what base64',
    );
  }
}
