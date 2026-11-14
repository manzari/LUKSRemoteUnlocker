import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/key_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/harness.dart';

const _pinned = 'SHA256:TEvtlX/GczN0Jf70vMKaeCELsAQ3MJIrRfoKEG+DgbM';
const _other = 'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

Future<void> openNewHost(WidgetTester tester) async {
  await tester.tap(find.text('Add host'));
  await tester.pumpAndSettle();
  expect(find.text('New host'), findsOneWidget);
}

Future<void> enter(WidgetTester tester, String key, String text) =>
    tester.enterText(find.byKey(ValueKey(key)), text);

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Save'));
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, String fieldKey, String option) async {
  await tester.tap(find.byKey(ValueKey(fieldKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<List<Host>> savedHosts(TestApp app) => HostRepository(app.db).all();

void main() {
  testWidgets('name is required; the core validation is shown inline', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await openNewHost(tester);
    await enter(tester, 'preboot-host-0', '192.0.2.1');
    await save(tester);
    expect(find.text('Name is empty.'), findsOneWidget);
    expect(await savedHosts(app), isEmpty);

    await enter(tester, 'host-name', 'alpha');
    await enter(tester, 'host-user', ' ');
    await enter(tester, 'postboot-port', '70000');
    await enter(tester, 'wait-timeout', '0');
    await save(tester);
    expect(find.text('Name is empty.'), findsNothing);
    expect(find.text('User is empty.'), findsOneWidget);
    expect(find.text('Post-boot port is invalid.'), findsOneWidget);
    expect(find.text('Wait timeout must be positive.'), findsOneWidget);
    expect(await savedHosts(app), isEmpty);
  });

  testWidgets('pre-boot addresses: required, add, reorder, remove', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await openNewHost(tester);
    await enter(tester, 'host-name', 'alpha');
    await save(tester);
    expect(find.text('Enter a host name or IP'), findsOneWidget);

    await enter(tester, 'preboot-host-0', 'first.example');
    await tester.tap(find.text('Add address'));
    await tester.pumpAndSettle();
    await enter(tester, 'preboot-host-1', 'second.example');
    await enter(tester, 'preboot-port-1', '2223');
    await tester.tap(find.text('Add address'));
    await tester.pumpAndSettle();
    await enter(tester, 'preboot-host-2', 'third.example');

    await tester.tap(find.byKey(const ValueKey('preboot-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move up'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preboot-menu-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('third.example'), findsNothing);

    await save(tester);
    final host = (await savedHosts(app)).single;
    expect(host.preboot, const [
      Endpoint('second.example', 2223),
      Endpoint('first.example', 2222),
    ]);
    expect(host.user, 'root');
    expect(host.profileId, UnlockProfile.debian.id);
    expect(host.waitTimeout, const Duration(minutes: 10));
    expect(host.bootTimeout, const Duration(minutes: 5));
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets('tcp check needs a post-boot port unlike every pre-boot port', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await openNewHost(tester);
    await enter(tester, 'host-name', 'alpha');
    await enter(tester, 'preboot-host-0', 'alpha.lan');
    await enter(tester, 'preboot-port-0', '22');
    await tester.tap(find.text('Add address'));
    await tester.pumpAndSettle();
    await enter(tester, 'preboot-host-1', 'alpha.vpn');
    await pick(tester, 'host-check', 'TCP port open');
    await save(tester);
    expect(
      find.text(
        'The tcp check needs a post-boot port that differs from every '
        'pre-boot port.',
      ),
      findsOneWidget,
    );
    expect(find.text('Same as pre-boot'), findsOneWidget);
    expect(await savedHosts(app), isEmpty);

    await enter(tester, 'postboot-port', '2222');
    await save(tester);
    expect(find.textContaining('The tcp check needs'), findsOneWidget);

    await enter(tester, 'postboot-port', '443');
    await save(tester);
    final host = (await savedHosts(app)).single;
    expect(host.postbootCheck, PostBootCheck.tcp);
    expect(host.postbootPort, 443);
  });

  testWidgets('key, passphrase, per-disk passphrase, options and pinned key', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    final vault = app.vault.unlockedVault!;
    final hosts = HostRepository(app.db);
    final key = await KeyRepository(
      app.db,
      hosts,
    ).add(vault, const SshKeyService().generateEd25519(), label: 'laptop');
    final secrets = SecretRepository(app.db, hosts);
    final main = await secrets.add(
      vault,
      label: 'main',
      passphrase: bytesOf('FAKE-1'),
    );
    final data = await secrets.add(
      vault,
      label: 'data',
      passphrase: bytesOf('FAKE-2'),
    );
    await tester.pumpAndSettle();

    await openNewHost(tester);
    await enter(tester, 'host-name', 'beta');
    await enter(tester, 'host-group', 'rack 1');
    await enter(tester, 'preboot-host-0', '192.0.2.7');
    await pick(tester, 'host-key', 'laptop (Ed25519)');
    await pick(tester, 'host-secret', 'main');
    await tester.tap(find.text('Add disk'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(find.text('Enter the disk name'), findsOneWidget);
    expect(find.text('Pick one'), findsOneWidget);
    await enter(tester, 'disk-name-0', 'sdb_crypt');
    await pick(tester, 'disk-secret-0', 'data');
    await enter(tester, 'postboot-host', 'beta.lan');
    await enter(tester, 'boot-timeout', '9');
    await enter(tester, 'host-pin', 'not a key');
    await save(tester);
    expect(find.textContaining('Expected "SHA256:'), findsOneWidget);
    await enter(tester, 'host-pin', 'ssh-ed25519 $_pinned');
    await tester.tap(find.byKey(const ValueKey('host-legacy')));
    await tester.tap(find.byKey(const ValueKey('host-enabled')));
    await tester.pumpAndSettle();
    await save(tester);

    final host = (await savedHosts(app)).single;
    expect(host.group, 'rack 1');
    expect(host.keyId, key.id);
    expect(host.secretId, main.id);
    expect(host.diskOverrides, {'sdb_crypt': data.id});
    expect(host.postbootHost, 'beta.lan');
    expect(host.bootTimeout, const Duration(minutes: 9));
    expect(host.prebootKey, HostKey('ssh-ed25519', _pinned));
    expect(host.legacyAlgorithms, isTrue);
    expect(host.enabled, isFalse);
    expect(find.text('rack 1'), findsOneWidget);
  });

  testWidgets('re-pinning and clearing a pinned key need a fresh unlock', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await HostRepository(app.db).save(
      Host(
        id: 'h',
        name: 'gamma',
        preboot: [const Endpoint('192.0.2.9', 2222)],
        prebootKey: HostKey(null, _pinned),
        postbootKey: HostKey('ssh-ed25519', _other),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('gamma'));
    await tester.pumpAndSettle();
    expect(find.text(_pinned), findsOneWidget);
    expect(find.text('ssh-ed25519 $_other'), findsOneWidget);

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(app.status.isUnlocked, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text(_pinned), findsOneWidget);

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    await unlockViaDialog(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pin-dialog-field')),
      _other,
    );
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(find.text(_other), findsOneWidget);

    await tester.tap(find.text('Clear').last);
    await tester.pumpAndSettle();
    await save(tester);
    final host = (await HostRepository(app.db).get('h'))!;
    expect(host.prebootKey, HostKey(null, _other));
    expect(host.postbootKey, isNull);
  });

  testWidgets('enabled switch in the list and delete', (tester) async {
    final app = await pumpApp(tester);
    final hosts = HostRepository(app.db);
    await hosts.save(
      Host(id: 'h', name: 'delta', preboot: [const Endpoint('d', 2222)]),
    );
    await tester.pumpAndSettle();
    expect(find.text('No group'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await hosts.get('h'))!.enabled, isFalse);

    await tester.tap(find.text('delta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete host'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await hosts.get('h'), isNull);
    expect(find.text('delta'), findsNothing);
  });
}
