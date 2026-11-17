import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/key_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:luks_remote_unlocker/services/config_file.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/harness.dart';

const _pin = 'SHA256:TEvtlX/GczN0Jf70vMKaeCELsAQ3MJIrRfoKEG+DgbM';

ConfigHost _fileHost(
  String name, {
  HostKey? pin,
  KeyReference? key,
  String? passphrase,
}) => ConfigHost(
  host: Host(
    id: '',
    name: name,
    preboot: [const Endpoint('192.0.2.1', 2222)],
    prebootKey: pin,
  ),
  key: key,
  passphrase: passphrase,
  profileRef: UnlockProfile.debian.id,
);

Uint8List _file(List<ConfigHost> hosts) => ConfigFile(
  exportedAt: DateTime.utc(2026, 11, 16, 12),
  profiles: const [],
  hosts: hosts,
).encode();

Future<void> _tapEntry(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('export saves the hosts without any secret', (tester) async {
    final app = await pumpApp(tester);
    final hosts = HostRepository(app.db);
    final vault = app.vault.unlockedVault!;
    final secret = await SecretRepository(
      app.db,
      hosts,
    ).add(vault, label: 'root disk', passphrase: bytesOf(fakePassphraseText));
    final key = await KeyRepository(app.db, hosts).add(
      vault,
      const SshKeyService().generateEd25519(comment: 'fake'),
      label: 'laptop',
    );
    await hosts.save(
      Host(
        id: 'h',
        name: 'alpha',
        preboot: [const Endpoint('192.0.2.1', 2222)],
        keyId: key.id,
        secretId: secret.id,
      ),
    );
    await openTab(tester, 'Settings');
    expect(find.textContaining('never included'), findsOneWidget);

    app.services.saveConfirmed = false;
    await _tapEntry(tester, 'Export configuration');
    expect(app.services.savedConfigs, isEmpty);
    expect(find.textContaining('Exported'), findsNothing);

    app.services.saveConfirmed = true;
    await _tapEntry(tester, 'Export configuration');
    final saved = app.services.savedConfigs.single;
    expect(
      saved.name,
      matches(RegExp(r'^luks-unlocker-config-\d{4}-\d\d-\d\d\.json$')),
    );
    expect(find.text('Exported 1 host and 0 profiles.'), findsOneWidget);
    final hostJson =
        ((jsonDecode(utf8.decode(saved.bytes)) as Map)['hosts'] as List).single
            as Map;
    expect(hostJson['name'], 'alpha');
    expect(hostJson['passphrase'], {'label': 'root disk'});
    expectNotInBytes(saved.bytes, bytesOf(fakePassphraseText), 'passphrase');
  });

  testWidgets('import shows a summary and writes only after Import', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    final hosts = HostRepository(app.db);
    final root = await SecretRepository(app.db, hosts).add(
      app.vault.unlockedVault!,
      label: 'root disk',
      passphrase: bytesOf(fakePassphraseText),
    );
    await hosts.save(
      Host(id: 'mine', name: 'beta', preboot: [const Endpoint('b', 2222)]),
    );
    final other = const SshKeyService().generateEd25519(comment: 'fake');
    app.services.nextConfigFile = (
      name: 'config.json',
      bytes: _file([
        _fileHost(
          'alpha',
          pin: HostKey('ssh-ed25519', _pin),
          passphrase: 'Root Disk',
          key: KeyReference(
            label: 'old laptop',
            type: 'ssh-ed25519',
            publicLine: other.publicLine,
            fingerprint: other.fingerprint,
          ),
        ),
        _fileHost('beta'),
      ]),
    );
    await openTab(tester, 'Settings');

    await _tapEntry(tester, 'Import configuration');
    expect(find.text('Import configuration?'), findsOneWidget);
    expect(find.textContaining('Exported 2026-11-16'), findsOneWidget);
    expect(find.text('Hosts to add (1)'), findsOneWidget);
    expect(find.text('• alpha · 192.0.2.1:2222 · pinned key'), findsOneWidget);
    expect(find.text('Skipped, name already in use (1)'), findsOneWidget);
    expect(find.text('• beta'), findsOneWidget);
    expect(find.textContaining('It stays unchanged'), findsOneWidget);
    expect(
      find.text('• "Root Disk" to your passphrase "root disk", used by alpha'),
      findsOneWidget,
    );
    expect(find.text('Not relinked, left unassigned (1)'), findsOneWidget);
    expect(
      find.text('• SSH key "old laptop" (${other.fingerprint}), used by alpha'),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 of the hosts to add carries a pinned pre-boot'),
      findsOneWidget,
    );
    final trust = find.byKey(const ValueKey('import-trust-pins'));
    expect(tester.widget<CheckboxListTile>(trust).value, isFalse);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect((await hosts.all()).map((h) => h.name), ['beta']);

    await _tapEntry(tester, 'Import configuration');
    await tester.ensureVisible(trust);
    await tester.tap(trust);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();
    expect(find.text('Imported 1 host.'), findsOneWidget);
    final alpha = (await hosts.all()).singleWhere((h) => h.name == 'alpha');
    expect(alpha.prebootKey, HostKey('ssh-ed25519', _pin));
    expect(alpha.secretId, root.id);
    expect(alpha.keyId, isNull);
    expect(alpha.profileId, UnlockProfile.debian.id);
    expect((await hosts.get('mine'))!.preboot.single.host, 'b');
  });

  testWidgets('pinned keys are dropped unless trusted', (tester) async {
    final app = await pumpApp(tester);
    app.services.nextConfigFile = (
      name: 'config.json',
      bytes: _file([_fileHost('alpha', pin: HostKey(null, _pin))]),
    );
    await openTab(tester, 'Settings');
    await _tapEntry(tester, 'Import configuration');
    expect(
      find.text('Trust the pinned host key from this file'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();
    final alpha = (await HostRepository(app.db).all()).single;
    expect(alpha.name, 'alpha');
    expect(alpha.prebootKey, isNull);
  });

  testWidgets('a file with nothing new offers only Close', (tester) async {
    final app = await pumpApp(tester);
    final hosts = HostRepository(app.db);
    await hosts.save(
      Host(id: 'mine', name: 'alpha', preboot: [const Endpoint('a', 2222)]),
    );
    app.services.nextConfigFile = (
      name: 'config.json',
      bytes: _file([_fileHost('Alpha')]),
    );
    await openTab(tester, 'Settings');
    await _tapEntry(tester, 'Import configuration');
    expect(find.text('Nothing to import'), findsOneWidget);
    expect(find.text('Hosts to add (0)'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Import'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(await hosts.all(), hasLength(1));
  });

  testWidgets('invalid files show why and write nothing', (tester) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Settings');

    final json = jsonDecode(
      utf8.decode(_file([_fileHost('alpha')])),
    ) as Map<String, Object?>;
    final host = (json['hosts']! as List).single as Map<String, Object?>;
    host['postbootCheck'] = 'tcp';
    host['postbootPort'] = 2222;
    app.services.nextConfigFile = (
      name: 'config.json',
      bytes: utf8.encode(jsonEncode(json)),
    );
    await _tapEntry(tester, 'Import configuration');
    expect(find.text('Cannot import this file'), findsOneWidget);
    expect(
      find.textContaining(
        'the tcp check needs a post-boot port that differs from every '
        'pre-boot port',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    json['version'] = 7;
    app.services.nextConfigFile = (
      name: 'config.json',
      bytes: utf8.encode(jsonEncode(json)),
    );
    await _tapEntry(tester, 'Import configuration');
    expect(
      find.text(
        'The file was made by a newer version of the app (format 7). '
        'Update the app to import it.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    app.services.pickConfigError = const FormatException(
      'The file is too large to be a configuration export.',
    );
    await _tapEntry(tester, 'Import configuration');
    expect(
      find.text('The file is too large to be a configuration export.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(await HostRepository(app.db).all(), isEmpty);
  });
}
