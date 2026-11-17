import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/key_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:luks_remote_unlocker/run/foreground_service_lifecycle.dart';
import 'package:luks_remote_unlocker/run/run_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/fake_foreground_service.dart';
import '../support/fake_network.dart';
import '../support/harness.dart';

Future<TestApp> pumpRunApp(WidgetTester tester, FakeNetwork net) => pumpApp(
  tester,
  overrides: [runEngineFactoryProvider.overrideWithValue(net.engine)],
);

/// Stores a key, a passphrase and one host per target, then locks the vault.
Future<void> seed(
  TestApp app,
  List<FakeTarget> targets, {
  Map<String, HostKey> pins = const {},
  Set<String> withoutKey = const {},
  String? group,
}) async {
  final vault = app.vault.unlockedVault!;
  final hosts = HostRepository(app.db);
  final key = await KeyRepository(
    app.db,
    hosts,
  ).add(vault, const SshKeyService().generateEd25519(), label: 'k');
  final secret = await SecretRepository(
    app.db,
    hosts,
  ).add(vault, label: 's', passphrase: bytesOf(fakeServerPassphrase));
  for (final t in targets) {
    await hosts.save(
      Host(
        id: 'id-${t.name}',
        name: t.name,
        group: group,
        preboot: [t.preboot],
        keyId: withoutKey.contains(t.name) ? null : key.id,
        secretId: secret.id,
        prebootKey: pins[t.name],
      ),
    );
  }
  app.vault.lock();
}

/// Advances fake time frame by frame, with a real async gap after each frame.
Future<void> pumpFrames(WidgetTester tester, [int frames = 50]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    // A finished stream subscription's cancel() completes in the root zone, outside fake time.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
}

/// Pumps until [finder] matches, then lets route transitions finish.
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 500; i++) {
    if (finder.evaluate().isNotEmpty) return pumpFrames(tester);
    await pumpFrames(tester, 1);
  }
  fail('not found: $finder');
}

Future<void> enterVaultPassword(WidgetTester tester) async {
  await pumpUntil(tester, find.text('Unlock the vault'));
  await tester.enterText(
    find.byKey(const ValueKey('unlock-password')),
    fakeMasterPassword,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
}

Finder inCard(String hostName, Finder finder) => find.descendant(
  of: find.byKey(ValueKey('run-host-id-$hostName')),
  matching: finder,
);

final finished = find.textContaining('Finished ');

void main() {
  testWidgets('unlock all: one vault prompt, parallel cards, a new host key '
      'confirmed in a dialog, and the history shows each final state', (
    tester,
  ) async {
    final a = FakeTarget('alpha');
    final b = FakeTarget('bravo', prebootKey: fakeHostKey('B'));
    final c = FakeTarget('charlie');
    final net = FakeNetwork([a, b, c]);
    final app = await pumpRunApp(tester, net);
    await seed(
      app,
      [a, b, c],
      pins: {'alpha': a.prebootKey},
      withoutKey: {'charlie'},
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('unlock-all')));
    await enterVaultPassword(tester);
    await pumpUntil(tester, find.text('New host key for bravo'));

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('host-key-type'))).data,
      'ssh-ed25519',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('host-key-fingerprint')))
          .data,
      b.prebootKey.fingerprint,
    );
    await pumpUntil(tester, inCard('alpha', find.text('Unlocked')));
    expect(
      inCard('bravo', find.text('Waiting for your confirmation')),
      findsOneWidget,
    );
    expect(
      inCard('charlie', find.text('Skipped: No SSH key assigned')),
      findsOneWidget,
    );
    expect(b.received, isEmpty);

    await tester.tap(find.text('Accept and pin'));
    await pumpUntil(tester, finished);
    expect(find.text('New host key for bravo'), findsNothing);
    expect(inCard('bravo', find.text('Unlocked')), findsOneWidget);
    expect(inCard('bravo', find.textContaining('booted')), findsOneWidget);
    final bravoLog = app.container
        .read(runControllerProvider)!
        .hosts
        .firstWhere((h) => h.name == 'bravo')
        .log;
    expect(
      bravoLog.map((e) => e.message),
      contains('host key accepted: ${b.prebootKey}'),
    );
    expect(find.text('Unlock the vault'), findsNothing);
    expect(b.received, [fakeServerPassphrase]);
    expect(
      (await HostRepository(app.db).get('id-bravo'))!.prebootKey,
      b.prebootKey,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await openTab(tester, 'History');
    expect(find.text('All hosts'), findsOneWidget);
    expect(find.textContaining('Unlocked 2, Skipped 1'), findsOneWidget);
    await tester.tap(find.text('All hosts'));
    await tester.pumpAndSettle();
    for (final name in ['alpha', 'bravo']) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('history-host-id-$name')),
          matching: find.text('Unlocked'),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('history-host-id-charlie')),
        matching: find.text('Skipped: No SSH key assigned'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('booted'), findsNWidgets(2));
  });

  testWidgets('declining a new key cancels that host; a mismatch offers no '
      'way to accept the key', (tester) async {
    final a = FakeTarget('alpha');
    final b = FakeTarget('bravo');
    final net = FakeNetwork([a, b]);
    final app = await pumpRunApp(tester, net);
    await seed(app, [a, b], pins: {'bravo': fakeHostKey('Z')});
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('unlock-all')));
    await enterVaultPassword(tester);
    await pumpUntil(tester, find.text('New host key for alpha'));
    await pumpUntil(tester, inCard('bravo', find.text('Host key mismatch')));
    expect(find.text('New host key for bravo'), findsNothing);

    await tester.tap(find.text('Decline'));
    await pumpUntil(tester, finished);
    expect(inCard('alpha', find.text('Cancelled')), findsOneWidget);
    expect(
      inCard('bravo', find.textContaining('pin the new key in the host form')),
      findsOneWidget,
    );
    expect(find.textContaining('Accept'), findsNothing);
    expect(a.received, isEmpty);
    expect(b.received, isEmpty);
    expect((await HostRepository(app.db).get('id-alpha'))!.prebootKey, isNull);
    expect(
      (await HostRepository(app.db).get('id-bravo'))!.prebootKey,
      fakeHostKey('Z'),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await openTab(tester, 'History');
    expect(
      find.textContaining('Cancelled 1, Host key mismatch 1'),
      findsOneWidget,
    );
  });

  testWidgets('one host: the run goes on in the background and can be '
      'cancelled', (tester) async {
    final a = FakeTarget('alpha')..present = false;
    final net = FakeNetwork([a]);
    final app = await pumpRunApp(tester, net);
    await seed(app, [a], pins: {'alpha': a.prebootKey});
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Unlock alpha'));
    await enterVaultPassword(tester);
    await pumpUntil(tester, inCard('alpha', find.text('Waiting for pre-boot')));

    await tester.pageBack();
    await pumpFrames(tester);
    expect(find.text('Unlocking: alpha'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('unlock-all')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Unlocking: alpha'));
    await pumpUntil(tester, find.byKey(const ValueKey('cancel-run')));

    await tester.tap(find.byKey(const ValueKey('cancel-run')));
    await pumpUntil(tester, finished);
    expect(inCard('alpha', find.text('Cancelled')), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel-run')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Unlocking: alpha'), findsNothing);
  });

  testWidgets('with the Android lifecycle the foreground service covers the '
      'run; denied notifications are noted but do not block it', (
    tester,
  ) async {
    final a = FakeTarget('alpha')..present = false;
    final net = FakeNetwork([a]);
    final service = FakeForegroundService()..answer = NotificationAccess.denied;
    final app = await pumpApp(
      tester,
      overrides: [
        runEngineFactoryProvider.overrideWithValue(net.engine),
        runLifecycleProvider.overrideWithValue(
          ForegroundServiceLifecycle(service),
        ),
      ],
    );
    await seed(app, [a], pins: {'alpha': a.prebootKey});
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Unlock alpha'));
    await enterVaultPassword(tester);
    await pumpUntil(tester, inCard('alpha', find.text('Waiting for pre-boot')));
    expect(service.running, isTrue);
    expect(
      find.text(ForegroundServiceLifecycle.notificationsOffNotice),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('cancel-run')));
    await pumpUntil(tester, finished);
    expect(inCard('alpha', find.text('Cancelled')), findsOneWidget);
    expect(service.running, isFalse);
    expect(service.calls, [
      'check',
      'request',
      'start Unlocking: alpha | 0 of 1 host done',
      'update Unlocking: alpha | 1 of 1 host done',
      'stop',
    ]);
    expect(
      find.text(ForegroundServiceLifecycle.notificationsOffNotice),
      findsNothing,
    );
  });

  testWidgets('a group button runs only the enabled hosts of that group', (
    tester,
  ) async {
    final a = FakeTarget('alpha');
    final b = FakeTarget('bravo');
    final net = FakeNetwork([a, b]);
    final app = await pumpRunApp(tester, net);
    await seed(app, [a], pins: {'alpha': a.prebootKey}, group: 'home');
    await HostRepository(app.db).save(
      Host(id: 'id-bravo', name: 'bravo', group: 'work', preboot: [b.preboot]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('unlock-group-home')));
    await enterVaultPassword(tester);
    await pumpUntil(tester, finished);
    expect(find.text('Group home'), findsOneWidget);
    expect(inCard('alpha', find.text('Unlocked')), findsOneWidget);
    expect(find.byKey(const ValueKey('run-host-id-bravo')), findsNothing);
    expect(b.connects, 0);
  });

  testWidgets('dismissing the vault prompt starts nothing', (tester) async {
    final a = FakeTarget('alpha');
    final net = FakeNetwork([a]);
    final app = await pumpRunApp(tester, net);
    await seed(app, [a], pins: {'alpha': a.prebootKey});
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('unlock-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('run-host-id-alpha')), findsNothing);
    expect(a.connects, 0);
    await openTab(tester, 'History');
    expect(find.textContaining('No runs yet'), findsOneWidget);
  });

  testWidgets('history can be cleared', (tester) async {
    final a = FakeTarget('alpha');
    final net = FakeNetwork([a]);
    final app = await pumpRunApp(tester, net);
    await seed(app, [a], pins: {'alpha': a.prebootKey});
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Unlock alpha'));
    await enterVaultPassword(tester);
    await pumpUntil(tester, finished);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openTab(tester, 'History');
    expect(find.textContaining('Unlocked 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No runs yet'), findsOneWidget);
    expect(await app.db.select(app.db.runs).get(), isEmpty);
    expect(await app.db.select(app.db.runEvents).get(), isEmpty);
  });
}
