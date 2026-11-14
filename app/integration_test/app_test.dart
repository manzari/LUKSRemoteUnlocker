import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:luks_remote_unlocker/app.dart';
import 'package:luks_remote_unlocker/data/database.dart';
import 'package:luks_remote_unlocker/data/open_database.dart';
import 'package:luks_remote_unlocker/providers.dart';
import 'package:material_ui/material_ui.dart';

const _password = 'FAKE-integration-master-password';
const _passphrase = 'FAKE integration passphrase';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first run, add passphrase, restart, unlock, reveal', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('luks_it_');
    addTearDown(() => dir.delete(recursive: true));

    Future<AppDatabase> start() async {
      final db = await openAppDatabase(directory: dir.path);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const LuksRemoteUnlockerApp(),
        ),
      );
      await tester.pumpAndSettle();
      return db;
    }

    var db = await start();
    expect(find.text('Set up the vault'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      _password,
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      _password,
    );
    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();
    expect(find.text('Add host'), findsOneWidget);

    await tester.tap(find.text('Passphrases').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add passphrase'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('secret-label')), 'root');
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      _passphrase,
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      _passphrase,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await db.close();
    db = await start();
    addTearDown(db.close);
    expect(find.text('Set up the vault'), findsNothing);
    expect(find.byTooltip('Unlock vault'), findsOneWidget);

    await tester.tap(find.text('Passphrases').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reveal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('unlock-password')),
      _password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();
    expect(find.text(_passphrase), findsOneWidget);
  });
}
