import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:luks_remote_unlocker/vault/vault_controller.dart';
import 'package:luks_remote_unlocker/version.dart';
import 'package:material_ui/material_ui.dart';

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

  testWidgets('change the master password', (tester) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Settings');
    expect(find.text('Master password'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
    expect(find.text('Biometric unlock'), findsNothing);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'FAKE-next-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      'FAKE-next-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Password saved'), findsOneWidget);

    app.vault.lock();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Unlock'));
    await tester.pumpAndSettle();
    await unlockViaDialog(tester, password: 'FAKE-next-password');
    expect(app.status.isUnlocked, isTrue);
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
