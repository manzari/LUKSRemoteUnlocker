import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/vault/vault_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';

Future<void> enterNewPassword(
  WidgetTester tester,
  String password, [
  String? confirmation,
]) async {
  await tester.enterText(find.byKey(const ValueKey('new-password')), password);
  await tester.enterText(
    find.byKey(const ValueKey('confirm-password')),
    confirmation ?? password,
  );
}

void main() {
  group('first-run setup', () {
    testWidgets(
      'Linux: master password is required, validated, then the shell opens',
      (tester) async {
        final app = await pumpApp(tester, setUpVault: false);
        expect(find.text('Set up the vault'), findsOneWidget);
        expect(find.text('Master password'), findsWidgets);
        expect(find.text('Continue without recovery password'), findsNothing);

        await tester.tap(find.text('Create vault'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a master password'), findsOneWidget);

        await enterNewPassword(tester, 'short');
        await tester.tap(find.text('Create vault'));
        await tester.pumpAndSettle();
        expect(find.text('Use at least 10 characters'), findsOneWidget);

        await enterNewPassword(
          tester,
          fakeMasterPassword,
          'FAKE-other-password',
        );
        await tester.tap(find.text('Create vault'));
        await tester.pumpAndSettle();
        expect(find.text('The entries do not match'), findsOneWidget);
        expect(app.status.phase, VaultPhase.needsSetup);

        await enterNewPassword(tester, fakeMasterPassword);
        await tester.tap(find.text('Create vault'));
        await tester.pumpAndSettle();
        expect(app.status.phase, VaultPhase.unlocked);
        expect(app.status.hasPasswordSlot, isTrue);
        expect(
          find.text('No hosts yet. Add the servers you want to unlock.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Android: skipping the recovery password needs the warning', (
      tester,
    ) async {
      final slot = FakeBiometricSlot();
      final app = await pumpApp(tester, biometrics: slot, setUpVault: false);
      expect(find.text('Recovery password (recommended)'), findsOneWidget);

      await tester.tap(find.text('Continue without recovery password'));
      await tester.pumpAndSettle();
      expect(find.textContaining('the vault is lost when the'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.status.phase, VaultPhase.needsSetup);

      await tester.tap(find.text('Continue without recovery password'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue without'));
      await tester.pumpAndSettle();
      expect(app.status.phase, VaultPhase.unlocked);
      expect(app.status.biometricEnrolled, isTrue);
      expect(app.status.hasPasswordSlot, isFalse);
      expect(slot.stores[false]!.hasKey, isTrue);
    });

    testWidgets(
      'Android: biometric slot plus recovery password; cancel is reported',
      (tester) async {
        final slot = FakeBiometricSlot()..cancelWrites = true;
        final app = await pumpApp(tester, biometrics: slot, setUpVault: false);
        await enterNewPassword(tester, fakeMasterPassword);
        await tester.tap(find.text('Set up biometric unlock'));
        await tester.pumpAndSettle();
        expect(
          find.text('Biometric setup was cancelled. Try again.'),
          findsOneWidget,
        );
        expect(app.status.phase, VaultPhase.needsSetup);

        slot.cancelWrites = false;
        await tester.tap(find.text('Set up biometric unlock'));
        await tester.pumpAndSettle();
        expect(app.status.phase, VaultPhase.unlocked);
        expect(app.status.biometricEnrolled, isTrue);
        expect(app.status.hasPasswordSlot, isTrue);
      },
    );
  });

  group('unlock gate', () {
    testWidgets(
      'lists work while locked; the lock button asks for the password',
      (tester) async {
        final app = await pumpApp(tester);
        app.vault.lock();
        await tester.pumpAndSettle();
        expect(
          find.text('No hosts yet. Add the servers you want to unlock.'),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Unlock vault'));
        await tester.pumpAndSettle();
        await unlockViaDialog(tester, password: 'FAKE-wrong-password');
        expect(find.text('Wrong password.'), findsOneWidget);
        expect(app.status.phase, VaultPhase.locked);

        await tester.enterText(
          find.byKey(const ValueKey('unlock-password')),
          fakeMasterPassword,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await tester.pumpAndSettle();
        expect(app.status.isUnlocked, isTrue);
        expect(find.text('Unlock the vault'), findsNothing);

        await tester.tap(find.byTooltip('Lock vault'));
        await tester.pumpAndSettle();
        expect(app.status.phase, VaultPhase.locked);
      },
    );

    testWidgets('biometric unlock is offered and tried right away', (
      tester,
    ) async {
      final slot = FakeBiometricSlot();
      final app = await pumpApp(tester, biometrics: slot, setUpVault: false);
      await app.vault.setUp(password: null, biometric: true);
      app.vault.lock();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Unlock vault'));
      await tester.pumpAndSettle();
      expect(app.status.isUnlocked, isTrue);
      expect(slot.stores[false]!.readCount, 1);
    });

    testWidgets(
      'invalidated biometrics: explanation, recovery password, re-enroll',
      (tester) async {
        final slot = FakeBiometricSlot();
        final app = await pumpApp(tester, biometrics: slot, setUpVault: false);
        await app.vault.setUp(
          password: bytesOf(fakeMasterPassword),
          biometric: true,
        );
        app.vault.lock();
        slot.stores[false]!.invalidate();
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Unlock vault'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('system switched off biometric unlock'),
          findsOneWidget,
        );
        expect(find.text('Use biometrics'), findsNothing);
        expect(find.text('Recovery password'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('unlock-password')),
          fakeMasterPassword,
        );
        await tester.tap(find.text('Recover'));
        await tester.pumpAndSettle();
        expect(app.status.isUnlocked, isTrue);
        expect(app.status.biometricInvalidated, isFalse);
        expect(slot.stores[false]!.hasKey, isTrue);
      },
    );

    testWidgets('going to the background locks the vault', (tester) async {
      final app = await pumpApp(tester);
      expect(app.status.isUnlocked, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(app.status.phase, VaultPhase.locked);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    });

    testWidgets('locks after 2 minutes without input', (tester) async {
      final app = await pumpApp(tester);
      await tester.pump(const Duration(seconds: 100));
      await tester.tap(find.text('Keys').first);
      await tester.pump(const Duration(seconds: 100));
      expect(app.status.isUnlocked, isTrue);
      await tester.pump(const Duration(seconds: 21));
      expect(app.status.phase, VaultPhase.locked);
    });
  });

  group('adaptive navigation', () {
    testWidgets('rail on wide screens', (tester) async {
      await pumpApp(tester, size: const Size(1000, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('bottom bar on phones; every tab opens', (tester) async {
      await pumpApp(tester, size: const Size(400, 800));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      for (final (tab, title) in [
        ('Keys', 'SSH keys'),
        ('Passphrases', 'Disk passphrases'),
        ('Profiles', 'Unlock profiles'),
        ('Settings', 'Vault'),
        ('Hosts', 'Add host'),
      ]) {
        await openTab(tester, tab);
        expect(find.text(title), findsWidgets);
      }
    });
  });
}
