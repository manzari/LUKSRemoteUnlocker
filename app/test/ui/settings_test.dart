import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:luks_remote_unlocker/providers.dart';
import 'package:luks_remote_unlocker/ui/common/messages.dart';
import 'package:luks_remote_unlocker/vault/vault_controller.dart';
import 'package:luks_remote_unlocker/version.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/vault.dart';

import '../support/harness.dart';

void main() {
  test('app version matches the pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version: (\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!;
    expect(version.group(1), startsWith('$appVersion+'));
  });

  Future<void> changePassword(
    WidgetTester tester, {
    required String current,
    required String next,
  }) async {
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('current-password')),
      current,
    );
    await tester.enterText(find.byKey(const ValueKey('new-password')), next);
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      next,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('change the master password with the current one', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Settings');
    expect(find.text('Master password'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
    expect(find.text('Biometric unlock'), findsNothing);

    await changePassword(
      tester,
      current: fakeMasterPassword,
      next: 'FAKE-next-password',
    );
    expect(find.text('Password changed'), findsOneWidget);

    app.vault.lock();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Unlock'));
    await tester.pumpAndSettle();
    await unlockViaDialog(tester, password: 'FAKE-next-password');
    expect(app.status.isUnlocked, isTrue);
  });

  testWidgets('a wrong current password changes nothing, even when unlocked', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Settings');
    expect(app.status.isUnlocked, isTrue);
    await changePassword(
      tester,
      current: 'FAKE-wrong-password',
      next: 'FAKE-next-password',
    );
    expect(find.text('Wrong password.'), findsOneWidget);

    app.vault.lock();
    await app.vault.unlockWithPassword(bytesOf(fakeMasterPassword));
    expect(app.status.isUnlocked, isTrue);
  });

  testWidgets('the current password alone is enough while locked', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Settings');
    app.vault.lock();
    await tester.pumpAndSettle();
    await changePassword(
      tester,
      current: fakeMasterPassword,
      next: 'FAKE-next-password',
    );
    expect(find.text('Unlock the vault'), findsNothing);
    expect(find.text('Password changed'), findsOneWidget);
    expect(app.status.isUnlocked, isTrue);
  });

  testWidgets('adding a recovery password needs fresh biometric auth', (
    tester,
  ) async {
    final slot = FakeBiometricSlot();
    final app = await pumpApp(tester, biometrics: slot, setUpVault: false);
    await app.vault.setUp(password: null, biometric: true);
    await tester.pumpAndSettle();
    await openTab(tester, 'Settings');
    expect(app.status.isUnlocked, isTrue);
    final store = slot.stores[false]!;

    store.unavailable = VaultKeyUnavailableReason.userCancelled;
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock the vault'), findsOneWidget);
    expect(store.readCount, 1);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-password')), findsNothing);
    expect(app.status.isUnlocked, isFalse);

    store.unavailable = null;
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(store.readCount, 2);
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      fakeMasterPassword,
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      fakeMasterPassword,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Password saved'), findsOneWidget);
    expect(app.status.hasPasswordSlot, isTrue);
  });

  testWidgets('a cancelled re-enrolment keeps biometric unlock working', (
    tester,
  ) async {
    final slot = FakeBiometricSlot();
    final app = await pumpApp(tester, biometrics: slot, setUpVault: false);
    await app.vault.setUp(password: null, biometric: true);
    await tester.pumpAndSettle();
    await openTab(tester, 'Settings');

    slot.cancelWrites = true;
    await tester.tap(find.text('Re-enroll'));
    await tester.pumpAndSettle();
    expect(find.text('Biometric unlock set up'), findsNothing);
    expect(app.status.biometricEnrolled, isTrue);

    app.vault.lock();
    await app.vault.unlockWithBiometrics();
    expect(app.status.isUnlocked, isTrue);
  });

  testWidgets('the auto-lock text follows the configured delay', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: [
        autoLockAfterProvider.overrideWithValue(const Duration(minutes: 5)),
      ],
    );
    await openTab(tester, 'Settings');
    expect(
      find.text(
        'Locks when the app goes to the background or after 5 minutes '
        'without input',
      ),
      findsOneWidget,
    );
  });

  test('durations read naturally', () {
    expect(describeDuration(const Duration(minutes: 2)), '2 minutes');
    expect(describeDuration(const Duration(minutes: 1)), '1 minute');
    expect(describeDuration(const Duration(seconds: 90)), '90 seconds');
    expect(describeDuration(const Duration(hours: 1)), '1 hour');
  });

  testWidgets('biometric section: PIN fallback switch and removing recovery', (
    tester,
  ) async {
    final slot = FakeBiometricSlot();
    final app = await pumpApp(tester, biometrics: slot, setUpVault: false);
    await app.vault.setUp(
      password: bytesOf(fakeMasterPassword),
      biometric: true,
    );
    await tester.pumpAndSettle();
    await openTab(tester, 'Settings');
    expect(find.text('Recovery password'), findsOneWidget);
    expect(find.text('Re-enroll'), findsOneWidget);

    await tester.tap(find.text('Allow device PIN as fallback'));
    await tester.pumpAndSettle();
    expect(app.status.allowDeviceCredential, isTrue);
    expect(slot.stores[true]!.hasKey, isTrue);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(app.status.hasPasswordSlot, isFalse);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('reset needs typed confirmation, then setup starts again', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await SecretRepository(
      app.db,
      HostRepository(app.db),
    ).add(app.vault.unlockedVault!, label: 'x', passphrase: bytesOf('FAKE'));
    await openTab(tester, 'Settings');
    await tester.tap(find.text('Reset vault'));
    await tester.pumpAndSettle();
    final reset = find.widgetWithText(FilledButton, 'Reset');
    expect(tester.widget<FilledButton>(reset).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('reset-confirm')),
      'RESET',
    );
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(app.status.phase, VaultPhase.needsSetup);
    expect(find.text('Set up the vault'), findsOneWidget);
    expect(await app.db.select(app.db.secrets).get(), isEmpty);
  });

  testWidgets('privacy policy and terms open the landing page', (tester) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Settings');
    await tester.tap(find.text('Privacy policy'));
    await tester.tap(find.text('Terms of service'));
    await tester.pumpAndSettle();
    expect(app.services.openedLinks.map((u) => '$u'), [
      'https://luksremoteunlocker.manzari.dev/privacy/',
      'https://luksremoteunlocker.manzari.dev/terms/',
    ]);

    app.services.linksOpen = false;
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not open https://luksremoteunlocker.manzari.dev/privacy/',
      ),
      findsOneWidget,
    );
  });

  testWidgets('setup help shows the server-side advice', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Server setup help'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'DROPBEAR_OPTIONS="-p 2222 -s -j -k -I 180 -c cryptroot-unlock"',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'dropbearkey -y -f /etc/dropbear/initramfs/dropbear_ed25519_host_key',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('dedicated passphrase in its own LUKS key slot'),
      findsOneWidget,
    );
    expect(
      find.textContaining('separate SSH key on each device'),
      findsOneWidget,
    );
  });
}
