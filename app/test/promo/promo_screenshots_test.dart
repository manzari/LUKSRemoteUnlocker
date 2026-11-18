import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/key_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:luks_remote_unlocker/run/run_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/fake_network.dart';
import '../support/harness.dart';
import '../ui/run_ui_test.dart'
    show enterVaultPassword, inCard, pumpFrames, pumpUntil, finished;

// Set by `--dart-define=PROMO_SHOTS=1`; a normal test run writes nothing.
const _promo = String.fromEnvironment('PROMO_SHOTS') == '1';

const _physical = Size(720, 1616);
const _ratio = 2.0;
const _statusBar = 32.0;

final _flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
final _fonts = '$_flutterRoot/bin/cache/artifacts/material_fonts';
final _monoDir =
    '$_flutterRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto_Mono';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final p in paths) {
    final f = File(p);
    if (!f.existsSync()) continue;
    any = true;
    loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  if (any) await loader.load();
}

Future<void> _loadFonts() async {
  const weights = ['Light', 'Regular', 'Medium', 'Bold'];
  await _loadFont('Roboto', [for (final w in weights) '$_fonts/Roboto-$w.ttf']);
  await _loadFont('MaterialIcons', ['$_fonts/MaterialIcons-Regular.otf']);
  final mono = [
    for (final w in ['Regular', 'Medium', 'Bold'])
      '$_monoDir/RobotoMono-$w.ttf',
  ];
  const dejavu = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf';
  await _loadFont(
    'monospace',
    mono.any((p) => File(p).existsSync())
        ? mono
        : [
            if (File(dejavu).existsSync())
              dejavu
            else
              '$_fonts/Roboto-Regular.ttf',
          ],
  );
}

HostKey _key(int seed) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final r = Random(seed);
  final body = List.generate(43, (_) => chars[r.nextInt(64)]).join();
  return HostKey('ssh-ed25519', 'SHA256:$body');
}

class _Spec {
  const _Spec(this.name, this.address, this.group, this.secret);

  final String name;
  final String address;
  final String group;
  final String secret;
}

const _specs = [
  _Spec('nas', 'nas.lan', 'home', 'nas disk'),
  _Spec('backup', 'backup.lan', 'home', 'nas disk'),
  _Spec('web-01', '192.0.2.10', 'rack', 'rack disks'),
  _Spec('db-01', '192.0.2.11', 'rack', 'rack disks'),
];

Map<String, FakeTarget> _targets() => {
  for (var i = 0; i < _specs.length; i++)
    _specs[i].name: FakeTarget(
      _specs[i].address,
      prebootKey: _key(10 + i),
      postbootKey: _key(20 + i),
    ),
};

/// Seeds two keys, two passphrases and the four hosts, then locks the vault.
Future<void> _seed(
  TestApp app,
  Map<String, FakeTarget> targets, {
  Set<String> unpinned = const {},
  Set<String> disabled = const {},
}) async {
  final vault = app.vault.unlockedVault!;
  final hosts = HostRepository(app.db);
  final keys = KeyRepository(app.db, hosts);
  final secrets = SecretRepository(app.db, hosts);
  final phone = await keys.add(
    vault,
    const SshKeyService().generateEd25519(),
    label: 'phone',
  );
  await keys.add(
    vault,
    const SshKeyService().generateEd25519(),
    label: 'laptop',
  );
  final secretIds = {
    for (final label in {'nas disk', 'rack disks'})
      label: (await secrets.add(
        vault,
        label: label,
        passphrase: bytesOf(fakeServerPassphrase),
      )).id,
  };
  for (final s in _specs) {
    final t = targets[s.name]!;
    await hosts.save(
      Host(
        id: 'id-${s.name}',
        name: s.name,
        group: s.group,
        preboot: [t.preboot],
        keyId: phone.id,
        secretId: secretIds[s.secret],
        prebootKey: unpinned.contains(s.name) ? null : t.prebootKey,
        enabled: !disabled.contains(s.name),
      ),
    );
  }
  app.vault.lock();
}

Future<TestApp> _pump(
  WidgetTester tester,
  Brightness brightness,
  Map<String, FakeTarget> targets, {
  Set<String> unpinned = const {},
  Set<String> disabled = const {},
}) async {
  WidgetsApp.debugAllowBannerOverride = false;
  // The test binding draws shadows as hard black outlines otherwise.
  debugDisableShadows = false;
  addTearDown(() => debugDisableShadows = true);
  addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final net = FakeNetwork(targets.values.toList());
  final app = await pumpApp(
    tester,
    size: _physical,
    devicePixelRatio: _ratio,
    overrides: [runEngineFactoryProvider.overrideWithValue(net.engine)],
  );
  tester.view.padding = const FakeViewPadding(top: _statusBar * _ratio);
  tester.view.viewPadding = tester.view.padding;
  await _seed(app, targets, unpinned: unpinned, disabled: disabled);
  await tester.pumpAndSettle();
  return app;
}

Future<void> _shot(WidgetTester tester, String name, Brightness b) async {
  await tester.pump(const Duration(milliseconds: 50));
  final boundary = find
      .byType(RepaintBoundary)
      .evaluate()
      .map((e) => e.renderObject!)
      .whereType<RenderRepaintBoundary>()
      .firstWhere((r) => r.size == _physical / _ratio);
  final suffix = b == Brightness.dark ? 'dark' : 'light';
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    expect((image.width, image.height), (720, 1616));
    final dir = Directory('../build/promo-shots')..createSync(recursive: true);
    File('${dir.path}/$name-$suffix.png')
        .writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _finishRun(WidgetTester tester) async {
  final cancel = find.byKey(const ValueKey('cancel-run'));
  if (cancel.evaluate().isNotEmpty) await tester.tap(cancel);
  await pumpUntil(tester, finished);
}

Future<void> _backToTabs(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

void _scene(
  String name,
  Future<void> Function(WidgetTester tester, Brightness b) body,
) {
  for (final b in Brightness.values) {
    testWidgets('$name ${b.name}', (tester) => body(tester, b));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  group('promo screenshots', skip: !_promo, () {
    _scene('hosts', (tester, b) async {
      await _pump(tester, b, _targets());
      await _shot(tester, 'hosts', b);
    });

    _scene('run', (tester, b) async {
      final targets = _targets();
      targets['db-01']!.postbootKey = targets['db-01']!.prebootKey;
      targets['web-01']!.present = false;
      await _pump(tester, b, targets, disabled: {'backup'});
      await tester.tap(find.byKey(const ValueKey('unlock-all')));
      await enterVaultPassword(tester);
      await pumpUntil(tester, inCard('nas', find.text('Unlocked')));
      await pumpUntil(tester, inCard('db-01', find.text('Waiting for boot')));
      await pumpUntil(
        tester,
        inCard('web-01', find.text('Waiting for pre-boot')),
      );
      await pumpFrames(tester, 20);
      await _shot(tester, 'run', b);
      await _finishRun(tester);
    });

    _scene('host-key', (tester, b) async {
      await _pump(tester, b, _targets(), unpinned: {'web-01'});
      await tester.tap(find.byTooltip('Unlock web-01'));
      await enterVaultPassword(tester);
      await pumpUntil(tester, find.text('New host key for web-01'));
      await _shot(tester, 'host-key', b);
      await tester.tap(find.text('Decline'));
      await pumpUntil(tester, finished);
    });

    _scene('key', (tester, b) async {
      await _pump(tester, b, _targets());
      await openTab(tester, 'Credentials');
      await tester.tap(find.text('phone').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('QR code'));
      await tester.pumpAndSettle();
      await _shot(tester, 'key', b);
    });

    _scene('history', (tester, b) async {
      final targets = _targets();
      await _pump(tester, b, targets);

      Future<void> run(Finder trigger) async {
        await tester.tap(trigger);
        await enterVaultPassword(tester);
        await pumpUntil(tester, finished);
        await _backToTabs(tester);
        await tester.pump(const Duration(hours: 7));
        for (final t in targets.values) {
          t.booted = false;
          t.unlocked.clear();
        }
      }

      await run(find.byKey(const ValueKey('unlock-all')));
      targets['web-01']!.prebootKey = _key(99);
      targets['db-01']!.passphrase = 'FAKE-other-passphrase';
      await run(find.byKey(const ValueKey('unlock-group-rack')));
      targets['web-01']!.prebootKey = _key(12);
      targets['db-01']!.passphrase = fakeServerPassphrase;
      await run(find.byTooltip('Unlock nas'));
      await openTab(tester, 'History');
      await _shot(tester, 'history', b);
    });

    _scene('host-form', (tester, b) async {
      await _pump(tester, b, _targets());
      await tester.tap(find.byKey(const ValueKey('host-id-web-01')));
      await tester.pumpAndSettle();
      await _shot(tester, 'host-form', b);
    });
  });
}
