import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/profile_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:luks_remote_unlocker/ui/secrets/secret_detail_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/harness.dart';

Future<void> enterTwice(
  WidgetTester tester,
  String text, [
  String? again,
]) async {
  await tester.enterText(find.byKey(const ValueKey('new-password')), text);
  await tester.enterText(
    find.byKey(const ValueKey('confirm-password')),
    again ?? text,
  );
}

void main() {
  group('passphrases', () {
    testWidgets(
      'add: label and confirmation are checked; bytes stored exactly',
      (tester) async {
        final app = await pumpApp(tester);
        final secrets = SecretRepository(app.db, HostRepository(app.db));
        await openTab(tester, 'Passphrases');
        await tester.tap(find.text('Add passphrase'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a label'), findsOneWidget);
        expect(find.text('Enter a passphrase'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('secret-label')),
          'root disk',
        );
        await enterTwice(
          tester,
          fakePassphraseText,
          'FAKE luks passphrase äöü',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(find.text('The entries do not match'), findsOneWidget);
        expect(await secrets.all(), isEmpty);

        await enterTwice(tester, fakePassphraseText);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(find.text('root disk'), findsOneWidget);
        expect(find.text('Not used'), findsOneWidget);
        final stored = (await secrets.all()).single;
        expect(
          await secrets.reveal(app.vault.unlockedVault!, stored.id),
          bytesOf(fakePassphraseText),
        );
      },
    );

    testWidgets(
      'replace, then reveal after a fresh unlock; hidden after 30 s',
      (tester) async {
        final app = await pumpApp(tester);
        final secrets = SecretRepository(app.db, HostRepository(app.db));
        final s = await secrets.add(
          app.vault.unlockedVault!,
          label: 'data disk',
          passphrase: bytesOf('FAKE-old'),
        );
        await openTab(tester, 'Passphrases');
        await tester.tap(find.text('data disk'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Replace'));
        await tester.pumpAndSettle();
        expect(find.text('Replace "data disk"'), findsOneWidget);
        await enterTwice(tester, 'FAKE-new passphrase');
        await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
        await tester.pumpAndSettle();
        expect(
          await secrets.reveal(app.vault.unlockedVault!, s.id),
          bytesOf('FAKE-new passphrase'),
        );

        await tester.tap(find.text('Reveal'));
        await tester.pumpAndSettle();
        expect(
          app.status.isUnlocked,
          isFalse,
          reason: 'reveal re-authenticates',
        );
        await unlockViaDialog(tester);
        expect(find.text('FAKE-new passphrase'), findsOneWidget);
        expect(find.text('Copy'), findsNothing);
        expect(find.byType(SelectableText), findsNothing);

        await tester.pump(revealDuration - const Duration(seconds: 2));
        expect(find.text('FAKE-new passphrase'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('FAKE-new passphrase'), findsNothing);
        expect(find.text('Reveal'), findsOneWidget);
      },
    );

    testWidgets('delete: refused while a host uses it as disk override', (
      tester,
    ) async {
      final app = await pumpApp(tester);
      final hosts = HostRepository(app.db);
      final secrets = SecretRepository(app.db, hosts);
      final s = await secrets.add(
        app.vault.unlockedVault!,
        label: 'data disk',
        passphrase: bytesOf('FAKE-x'),
      );
      await hosts.save(
        Host(
          id: 'h',
          name: 'alpha',
          preboot: [const Endpoint('a', 2222)],
          diskOverrides: {'sdb': s.id},
        ),
      );
      await openTab(tester, 'Passphrases');
      expect(find.text('Used by 1 host'), findsOneWidget);
      await tester.tap(find.text('data disk'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete passphrase'));
      await tester.pumpAndSettle();
      expect(find.textContaining('is used by alpha'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await hosts.delete('h');
      await tester.tap(find.byTooltip('Delete passphrase'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(await secrets.get(s.id), isNull);
    });
  });

  group('profiles', () {
    testWidgets('built-in is read-only; copy and edit the command', (
      tester,
    ) async {
      final app = await pumpApp(tester);
      await openTab(tester, 'Profiles');
      await tester.tap(find.text(UnlockProfile.debian.name));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Built-in profiles are read-only'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Save'), findsNothing);
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('profile-command')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.readOnly, isTrue);

      await tester.tap(find.text('Copy and edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('profile-command')),
        ' ',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a command'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('profile-command')),
        '/usr/bin/cryptroot-unlock',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Mine',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Mine'), findsOneWidget);

      final all = await ProfileRepository(app.db, HostRepository(app.db)).all();
      expect(all, hasLength(2));
      expect(all.first, UnlockProfile.debian);
      expect(all.last.name, 'Mine');
      expect(all.last.command, '/usr/bin/cryptroot-unlock');
      expect(all.last.builtIn, isFalse);
    });
  });
}
