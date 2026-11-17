import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:luks_remote_unlocker/app.dart';
import 'package:luks_remote_unlocker/data/open_database.dart';
import 'package:luks_remote_unlocker/providers.dart';
import 'package:luks_remote_unlocker/run/foreground_service_lifecycle.dart';
import 'package:luks_remote_unlocker/run/run_providers.dart';
import 'package:luks_remote_unlocker/services/plugin_foreground_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

// Set by `make test-app-bench` and `make test-android-bench`, which reset the targets to this passphrase.
const _bench = String.fromEnvironment('BENCH') == '1';
const _passphrase = String.fromEnvironment(
  'BENCH_PASSPHRASE',
  defaultValue: 'fake-bench-pass',
);

/// "target1=SHA256:..,SHA256:..;target2=..": the targets' pre-boot fingerprints.
const _prebootKeys = String.fromEnvironment('BENCH_PREBOOT_KEYS');

/// The bench fixture key as base64, for devices without the checkout (Android).
const _benchKeyBase64 = String.fromEnvironment('BENCH_KEY');
const _password = 'FAKE-bench-master-password';
const _targets = ['target1', 'target2', 'target3'];

Map<String, Set<String>> _expectedKeys() => {
  for (final entry in _prebootKeys.split(';'))
    if (entry.contains('='))
      entry.split('=').first: entry.split('=').last.split(',').toSet(),
};

Uint8List _benchKey() {
  if (_benchKeyBase64.isNotEmpty) return base64Decode(_benchKeyBase64);
  var d = Directory.current.absolute;
  while (!File('${d.path}/bench/fixtures/id_ed25519_bench').existsSync()) {
    if (d.parent.path == d.path) throw StateError('bench fixtures not found');
    d = d.parent;
  }
  return File('${d.path}/bench/fixtures/id_ed25519_bench').readAsBytesSync();
}

/// Pumps until [done]; on Android `make test-android-bench` answers system prompts from outside.
Future<void> _pumpUntil(
  WidgetTester tester,
  Future<bool> Function() done,
  String what,
) async {
  final deadline = DateTime.now().add(const Duration(minutes: 2));
  while (!await done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app unlocks the three bench targets in parallel and the history '
      'shows each final state', (tester) async {
    final dir = await Directory.systemTemp.createTemp('luks_bench_');
    addTearDown(() => dir.delete(recursive: true));
    final db = await openAppDatabase(directory: dir.path);
    addTearDown(db.close);
    final lifecycle = platformRunLifecycle();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (lifecycle != null)
            runLifecycleProvider.overrideWithValue(lifecycle),
        ],
        child: const LuksRemoteUnlockerApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LuksRemoteUnlockerApp)),
    );
    final vaults = container.read(vaultControllerProvider.notifier);
    final biometric = container
        .read(vaultControllerProvider)
        .biometricAvailable;
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      _password,
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      _password,
    );
    await tester.tap(
      find.text(biometric ? 'Set up biometric unlock' : 'Create vault'),
    );
    await _pumpUntil(
      tester,
      () async => vaults.unlockedVault != null,
      'the vault setup',
    );
    await tester.pumpAndSettle();

    final vault = vaults.unlockedVault!;
    final key = await container
        .read(keyRepositoryProvider)
        .add(
          vault,
          const SshKeyService().importOpenSsh(_benchKey()),
          label: 'bench',
        );
    final secret = await container
        .read(secretRepositoryProvider)
        .add(vault, label: 'bench disks', passphrase: utf8.encode(_passphrase));
    for (final t in _targets) {
      await container
          .read(hostRepositoryProvider)
          .save(
            Host(
              id: 'id-$t',
              name: t,
              group: 'bench',
              preboot: [Endpoint(t, 2222)],
              keyId: key.id,
              secretId: secret.id,
              waitTimeout: const Duration(minutes: 1),
              bootTimeout: const Duration(minutes: 1),
            ),
          );
    }
    vaults.lock();
    await tester.pumpAndSettle();

    final service = lifecycle == null ? null : PluginForegroundService();
    if (service != null) {
      await _pumpUntil(
        tester,
        () async =>
            await service.notificationAccess() == NotificationAccess.granted,
        'POST_NOTIFICATIONS, granted by the harness',
      );
    }
    await tester.tap(find.byKey(const ValueKey('unlock-all')));
    if (biometric) {
      // The dialog starts the biometric prompt; the harness touches the sensor.
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('unlock-password')),
        _password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    }

    final expected = _expectedKeys();
    expect(
      expected.keys.toSet(),
      _targets.toSet(),
      reason: 'BENCH_PREBOOT_KEYS',
    );
    final accepted = <String, String>{};
    var serviceSeen = false;
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (find.textContaining('Finished ').evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) fail('the run did not finish');
      if (service != null && !serviceSeen) {
        serviceSeen = await service.isRunning();
      }
      final title = find.textContaining('New host key for ');
      if (title.evaluate().isNotEmpty) {
        final name = tester
            .widget<Text>(title)
            .data!
            .substring('New host key for '.length);
        final fingerprint = tester
            .widget<Text>(find.byKey(const ValueKey('host-key-fingerprint')))
            .data!;
        expect(expected[name], contains(fingerprint), reason: name);
        accepted[name] = fingerprint;
        await tester.tap(find.text('Accept and pin'));
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
    expect(accepted.keys.toSet(), _targets.toSet());
    if (service != null) {
      expect(serviceSeen, isTrue, reason: 'foreground service during run');
      expect(await service.isRunning(), isFalse, reason: 'stopped at end');
    }

    final run = container.read(runControllerProvider)!;
    for (final h in run.hosts) {
      expect(h.result, FinalState.unlocked, reason: h.log.join('\n'));
    }
    final starts = run.hosts.map((h) => h.log.first.time);
    final ends = run.hosts.map((h) => h.log.last.time);
    expect(
      starts
          .reduce((a, b) => a.isAfter(b) ? a : b)
          .isBefore(ends.reduce((a, b) => a.isBefore(b) ? a : b)),
      isTrue,
      reason: 'the hosts ran at the same time',
    );
    for (final t in _targets) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('run-host-id-$t')),
          matching: find.text('Unlocked'),
        ),
        findsOneWidget,
      );
      final host = (await container.read(hostRepositoryProvider).get('id-$t'))!;
      expect(host.prebootKey?.fingerprint, accepted[t]);
      expect(host.postbootKey, isNotNull);
      expect(host.postbootKey!.matches(host.prebootKey!), isFalse);
    }

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('History').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Unlocked 3'), findsOneWidget);
    await tester.tap(find.text('All hosts'));
    await tester.pumpAndSettle();
    for (final t in _targets) {
      final card = find.byKey(ValueKey('history-host-id-$t'));
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(of: card, matching: find.text('Unlocked')),
        findsOneWidget,
      );
    }
    final events = await container
        .read(runRepositoryProvider)
        .watchEvents(run.id)
        .first;
    expect(events.where((e) => e.isFinal), hasLength(3));
    for (final e in events) {
      expect(e.message, isNot(contains(_passphrase)));
    }
  }, skip: !_bench);
}
