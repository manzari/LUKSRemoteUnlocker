import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/drift_vault_store.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/key_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/harness.dart';

const _fixtureFingerprint =
    'SHA256:TEvtlX/GczN0Jf70vMKaeCELsAQ3MJIrRfoKEG+DgbM';

Future<void> openAdd(WidgetTester tester, String choice) async {
  await openTab(tester, 'Keys');
  await tester.tap(find.text('Add key'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(choice));
  await tester.pumpAndSettle();
}

Future<void> tapImport(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Import'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'generate: label required, then public parts with copy, share, QR',
    (tester) async {
      final app = await pumpApp(tester);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      await openAdd(tester, 'Generate Ed25519 key');
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a label'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('key-label')), 'phone');
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.pumpAndSettle();

      final stored = (await KeyRepository(
        app.db,
        HostRepository(app.db),
      ).all()).single;
      expect(stored.label, 'phone');
      expect(stored.publicLine, startsWith('ssh-ed25519 AAAA'));
      expect(stored.publicLine, endsWith(' luks-remote-unlocker'));
      expect(find.text('phone'), findsOneWidget);
      expect(find.text(stored.publicLine), findsOneWidget);
      expect(find.text(stored.fingerprint), findsOneWidget);
      expect(find.textContaining('PRIVATE KEY'), findsNothing);

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard, stored.publicLine);
      expect(find.text('Public key copied'), findsOneWidget);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(app.services.shared, [stored.publicLine]);

      await tester.tap(find.text('QR code'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
    },
  );

  testWidgets('a key label already in use is refused in the form and on '
      'rename', (tester) async {
    final app = await pumpApp(tester);
    final repo = KeyRepository(app.db, HostRepository(app.db));
    await repo.add(
      app.vault.unlockedVault!,
      const SshKeyService().generateEd25519(),
      label: 'Laptop',
    );
    await openAdd(tester, 'Generate Ed25519 key');
    await tester.enterText(find.byKey(const ValueKey('key-label')), 'laptop ');
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();
    expect(find.text('This label is already used'), findsOneWidget);
    expect(await repo.all(), hasLength(1));

    await tester.enterText(find.byKey(const ValueKey('key-label')), 'phone');
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('label-dialog-field')),
      'LAPTOP',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('This label is already used'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('label-dialog-field')),
      'Phone',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      (await repo.all()).map((k) => k.label),
      containsAll(['Laptop', 'Phone']),
    );
  });

  testWidgets('import shows the core errors as readable messages', (
    tester,
  ) async {
    await pumpApp(tester);
    await openAdd(tester, 'Import existing key');
    await tester.enterText(find.byKey(const ValueKey('key-label')), 'old');

    await tapImport(tester);
    expect(find.text('Choose a key file or paste a key.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('key-paste')),
      'not a key',
    );
    await tapImport(tester);
    expect(find.text('The file is not a valid private key.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('key-paste')),
      fixture('id_ed25519_fake_encrypted.pub'),
    );
    await tapImport(tester);
    expect(find.textContaining('This is a public key.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('key-paste')),
      fixture('id_ed25519_fake_encrypted'),
    );
    await tapImport(tester);
    expect(find.text('The key is protected by a passphrase.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('key-passphrase')),
      'FAKE-wrong-key-passphrase',
    );
    await tapImport(tester);
    expect(find.text('The key passphrase is wrong.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('key-passphrase')),
      'FAKE-key-passphrase',
    );
    await tapImport(tester);
    expect(find.text(_fixtureFingerprint), findsOneWidget);
    expect(find.text('Ed25519'), findsOneWidget);
  });

  testWidgets('import from a file, unlocking first; duplicates are refused', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    final generated = const SshKeyService().generateEd25519(comment: 'f');
    app.vault.lock();
    await tester.pumpAndSettle();
    await openAdd(tester, 'Import existing key');
    app.services.nextFile = (
      name: 'id_ed25519',
      bytes: Uint8List.fromList(generated.privateKeyPem),
    );
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(find.text('File: id_ed25519'), findsOneWidget);

    await tapImport(tester);
    await unlockViaDialog(tester);
    expect(find.text(generated.fingerprint), findsOneWidget);
    final store = DriftVaultStore(app.db);
    expect(await store.listRecordIds(), hasLength(1));
    final keys = KeyRepository(app.db, HostRepository(app.db));
    expect((await keys.all()).single.label, 'id_ed25519');

    Navigator.of(tester.element(find.text(generated.fingerprint))).pop();
    await tester.pumpAndSettle();
    await openAdd(tester, 'Import existing key');
    app.services.nextFile = (
      name: 'again',
      bytes: Uint8List.fromList(generated.privateKeyPem),
    );
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    await tapImport(tester);
    expect(
      find.text('This key is already stored as "id_ed25519".'),
      findsOneWidget,
    );
    expect(await store.listRecordIds(), hasLength(1));
  });

  testWidgets('delete: refused while in use, naming the host; then removed', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    final hosts = HostRepository(app.db);
    final keys = KeyRepository(app.db, hosts);
    final key = await keys.add(
      app.vault.unlockedVault!,
      const SshKeyService().generateEd25519(),
      label: 'laptop',
    );
    await hosts.save(
      Host(
        id: 'h',
        name: 'alpha',
        preboot: [const Endpoint('a', 2222)],
        keyId: key.id,
      ),
    );
    await openTab(tester, 'Keys');
    await tester.tap(find.text('laptop'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete key'));
    await tester.pumpAndSettle();
    expect(find.text('Key in use'), findsOneWidget);
    expect(find.textContaining('is used by alpha'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(await keys.get(key.id), isNotNull);

    await hosts.delete('h');
    await tester.tap(find.byTooltip('Delete key'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await keys.get(key.id), isNull);
    expect(await DriftVaultStore(app.db).listRecordIds(), isEmpty);
    expect(find.textContaining('No SSH keys yet'), findsOneWidget);
  });
}
