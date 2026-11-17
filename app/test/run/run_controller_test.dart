import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/database.dart';
import 'package:luks_remote_unlocker/data/drift_vault_store.dart';
import 'package:luks_remote_unlocker/data/host_repository.dart';
import 'package:luks_remote_unlocker/data/key_repository.dart';
import 'package:luks_remote_unlocker/data/run_repository.dart';
import 'package:luks_remote_unlocker/data/secret_repository.dart';
import 'package:luks_remote_unlocker/providers.dart';
import 'package:luks_remote_unlocker/run/run_controller.dart';
import 'package:luks_remote_unlocker/run/run_lifecycle.dart';
import 'package:luks_remote_unlocker/run/run_providers.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/fake_network.dart';
import '../support/harness.dart';

final class RecordingLifecycle extends RunLifecycle {
  final calls = <String>[];
  bool fail = false;
  int requested = 0;
  void Function()? onRequested;
  String? noticeText;

  void _record(String call) {
    calls.add(call);
    if (fail) throw StateError('FAKE hook failure');
  }

  @override
  Future<void> runRequested() async {
    requested++;
    onRequested?.call();
    if (fail) throw StateError('FAKE hook failure');
  }

  @override
  String? get notice {
    if (fail) throw StateError('FAKE hook failure');
    return noticeText;
  }

  @override
  Future<void> runStarted(RunActivity run) async =>
      _record('started ${run.hostCount}');

  @override
  Future<void> runProgress(RunActivity run) async =>
      _record('progress ${run.finishedCount}/${run.hostCount}');

  @override
  Future<void> runEnded(RunActivity run) async =>
      _record('ended ${run.finishedCount}/${run.hostCount}');
}

final class World {
  World(List<FakeTarget> targets, {AppDatabase? db})
    : db = db ?? memoryDatabase(),
      net = FakeNetwork(targets) {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(this.db),
        runEngineFactoryProvider.overrideWithValue(net.engine),
        runLifecycleProvider.overrideWithValue(lifecycle),
      ],
    );
    container.listen(runControllerProvider, (_, _) {});
  }

  final AppDatabase db;
  final FakeNetwork net;
  final lifecycle = RecordingLifecycle();
  late final ProviderContainer container;
  late final Vault vault;
  late final StoredKey key;
  late final StoredSecret secret;
  int prompts = 0;

  HostRepository get hosts => container.read(hostRepositoryProvider);
  RunRepository get runs => container.read(runRepositoryProvider);
  RunController get controller =>
      container.read(runControllerProvider.notifier);
  RunState get state => container.read(runControllerProvider)!;

  HostRunView view(String name) =>
      state.hosts.firstWhere((h) => h.name == name);

  Future<void> init() async {
    vault = await Vault.create(DriftVaultStore(db), kdf: fakeKdf);
    await vault.setPassword(bytesOf(fakeMasterPassword), params: fastParams);
    key = await container
        .read(keyRepositoryProvider)
        .add(vault, const SshKeyService().generateEd25519(), label: 'k');
    secret = await container
        .read(secretRepositoryProvider)
        .add(vault, label: 's', passphrase: bytesOf(fakeServerPassphrase));
  }

  Future<Host> addHost(
    FakeTarget t, {
    String? group,
    bool pinned = false,
    HostKey? pin,
    bool enabled = true,
    bool withKey = true,
  }) async {
    final h = Host(
      id: 'id-${t.name}',
      name: t.name,
      group: group,
      preboot: [t.preboot],
      keyId: withKey ? key.id : null,
      secretId: secret.id,
      prebootKey: pin ?? (pinned ? t.prebootKey : null),
      enabled: enabled,
    );
    await hosts.save(h);
    return h;
  }

  Future<RunStart> start(RunSelection selection, {bool unlock = true}) =>
      controller.start(
        selection,
        unlockVault: () async {
          prompts++;
          return unlock ? vault : null;
        },
      );

  Future<void> until(bool Function() condition, String what) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  Future<HostKeyRequest> request(String hostName) async {
    await until(
      () => state.hostKeyRequests.any((r) => r.hostName == hostName),
      'a host key request for $hostName',
    );
    return state.hostKeyRequests.firstWhere((r) => r.hostName == hostName);
  }

  Future<List<HostEvent>> storedEvents() async =>
      runs.watchEvents(state.id).first;

  Future<RunRecord> storedRun() async => (await runs.watch(state.id).first)!;

  void expectWiped() {
    expect(net.keyBuffers, isNotEmpty);
    for (final b in [...net.keyBuffers, ...net.passphraseBuffers]) {
      expect(b.every((x) => x == 0), isTrue, reason: 'buffer not wiped');
    }
  }

  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
    await db.close();
  }
}

void main() {
  late World w;

  Future<World> world(List<FakeTarget> targets, {AppDatabase? db}) async {
    w = World(targets, db: db);
    await w.init();
    return w;
  }

  tearDown(() => w.dispose());

  test('a group runs in parallel after one vault prompt; a new key pauses only '
      'its host; keys and history are stored; buffers are wiped', () async {
    final a = FakeTarget('alpha');
    final b = FakeTarget('bravo', prebootKey: fakeHostKey('B'));
    final c = FakeTarget('charlie');
    final other = FakeTarget('delta');
    final off = FakeTarget('echo');
    await world([a, b, c, other, off]);
    await w.addHost(a, group: 'home', pinned: true);
    await w.addHost(b, group: 'home');
    await w.addHost(c, group: 'home', withKey: false);
    await w.addHost(other, group: 'work', pinned: true);
    await w.addHost(off, group: 'home', pinned: true, enabled: false);

    expect(await w.start(const HostGroup('home')), RunStart.started);
    expect(w.prompts, 1);
    expect(w.state.title, 'Group home');
    expect(w.state.hosts.map((h) => h.name), ['alpha', 'bravo', 'charlie']);
    expect(w.view('charlie').skipReason, 'No SSH key assigned');

    final request = await w.request('bravo');
    expect(request.key, b.prebootKey);
    await w.until(() => w.view('alpha').result != null, 'alpha to finish');
    expect(w.view('alpha').result, FinalState.unlocked);
    expect(w.view('bravo').result, isNull);
    expect(b.received, isEmpty, reason: 'nothing sent before the answer');

    w.controller.answerHostKey(request.id, accept: true);
    await w.controller.finished;
    expect(w.state.running, isFalse);
    expect(w.state.hostKeyRequests, isEmpty);
    expect(w.view('bravo').result, FinalState.unlocked);
    expect(other.received, isEmpty);
    expect(off.received, isEmpty);
    expect(w.prompts, 1);
    w.expectWiped();

    final bravo = (await w.hosts.get('id-bravo'))!;
    expect(bravo.prebootKey, b.prebootKey);
    expect(bravo.postbootKey, b.postbootKey);
    expect((await w.hosts.get('id-alpha'))!.postbootKey, a.postbootKey);
    expect((await w.hosts.get('id-charlie'))!.prebootKey, isNull);

    final run = await w.storedRun();
    expect(run.title, 'Group home');
    expect(run.finishedAt, isNotNull);
    expect(run.hosts.map((h) => h.hostName), ['alpha', 'bravo', 'charlie']);
    expect(run.hosts.map((h) => h.finalState), [
      FinalState.unlocked,
      FinalState.unlocked,
      null,
    ]);
    expect(run.hosts.last.skipReason, 'No SSH key assigned');
    final events = await w.storedEvents();
    expect(
      events.where((e) => e.isFinal).map((e) => (e.hostId, e.result)),
      unorderedEquals([
        ('id-alpha', FinalState.unlocked),
        ('id-bravo', FinalState.unlocked),
      ]),
    );
    expect(
      events.map((e) => e.message),
      contains('host key accepted: ${b.prebootKey}'),
    );
    expect(w.lifecycle.calls, [
      'started 2',
      'progress 1/2',
      'progress 2/2',
      'ended 2/2',
    ]);
  });

  test(
    'declining a new key ends that host as Cancelled and pins nothing',
    () async {
      final a = FakeTarget('alpha');
      await world([a]);
      await w.addHost(a);

      expect(await w.start(const OneHost('id-alpha')), RunStart.started);
      final request = await w.request('alpha');
      w.controller.answerHostKey(request.id, accept: false);
      await w.controller.finished;

      expect(w.view('alpha').result, FinalState.cancelled);
      expect(a.received, isEmpty);
      expect((await w.hosts.get('id-alpha'))!.prebootKey, isNull);
      expect(
        (await w.storedRun()).hosts.single.finalState,
        FinalState.cancelled,
      );
      w.expectWiped();
    },
  );

  test('a changed key is a mismatch without any prompt', () async {
    final a = FakeTarget('alpha');
    await world([a]);
    await w.addHost(a, pin: fakeHostKey('Z'));

    await w.start(const OneHost('id-alpha'));
    await w.controller.finished;

    expect(w.view('alpha').result, FinalState.hostKeyMismatch);
    expect(a.received, isEmpty);
    expect((await w.hosts.get('id-alpha'))!.prebootKey, fakeHostKey('Z'));
    expect(
      (await w.storedRun()).hosts.single.finalState,
      FinalState.hostKeyMismatch,
    );
  });

  test('cancel stops every host, answers open prompts and wipes', () async {
    final absent = FakeTarget('alpha')..present = false;
    final unpinned = FakeTarget('bravo');
    await world([absent, unpinned]);
    await w.addHost(absent, pinned: true);
    await w.addHost(unpinned);

    await w.start(const AllHosts());
    await w.request('bravo');
    await w.until(
      () => w.view('alpha').phase == HostPhase.waitingForPreboot,
      'alpha to wait',
    );
    w.controller.cancel();
    expect(w.state.hostKeyRequests, isEmpty);
    await w.controller.finished;

    expect(w.state.hosts.map((h) => h.result), [
      FinalState.cancelled,
      FinalState.cancelled,
    ]);
    expect(unpinned.received, isEmpty);
    expect((await w.hosts.get('id-bravo'))!.prebootKey, isNull);
    expect((await w.storedRun()).hosts.map((h) => h.finalState), [
      FinalState.cancelled,
      FinalState.cancelled,
    ]);
    w.expectWiped();
    expect(w.lifecycle.calls.last, 'ended 2/2');
  });

  test('one host can be cancelled while the others go on', () async {
    final absent = FakeTarget('alpha')..present = false;
    final b = FakeTarget('bravo');
    await world([absent, b]);
    await w.addHost(absent, pinned: true);
    await w.addHost(b, pinned: true);

    await w.start(const AllHosts());
    await w.until(
      () => w.view('alpha').phase == HostPhase.waitingForPreboot,
      'alpha to wait',
    );
    w.controller.cancelHost('id-alpha');
    await w.controller.finished;
    expect(w.view('alpha').result, FinalState.cancelled);
    expect(w.view('bravo').result, FinalState.unlocked);
  });

  test(
    'without hosts or without the vault nothing runs or is stored',
    () async {
      final a = FakeTarget('alpha');
      await world([a]);
      await w.addHost(a, pinned: true, enabled: false);

      expect(await w.start(const AllHosts()), RunStart.noHosts);
      expect(w.prompts, 0);
      expect(await w.start(const OneHost('missing')), RunStart.noHosts);
      expect(
        await w.start(const OneHost('id-alpha'), unlock: false),
        RunStart.vaultLocked,
      );
      expect(w.prompts, 1);
      expect(w.container.read(runControllerProvider), isNull);
      expect(await w.runs.watchAll().first, isEmpty);
      expect(a.received, isEmpty);
    },
  );

  test('a second start while a run is going is refused', () async {
    final a = FakeTarget('alpha')..present = false;
    await world([a]);
    await w.addHost(a, pinned: true);

    expect(await w.start(const AllHosts()), RunStart.started);
    expect(await w.start(const AllHosts()), RunStart.busy);
    expect(w.prompts, 1);
    w.controller.cancel();
    await w.controller.finished;
  });

  test(
    'a run of only skipped hosts is recorded without engine or hooks',
    () async {
      final a = FakeTarget('alpha');
      await world([a]);
      w.lifecycle.noticeText = 'FAKE notice';
      await w.addHost(a, withKey: false);

      await w.start(const AllHosts());
      await w.controller.finished;
      expect(w.view('alpha').skipReason, 'No SSH key assigned');
      expect(w.state.running, isFalse);
      expect(w.lifecycle.calls, isEmpty);
      expect(w.state.notice, isNull);
      final run = await w.storedRun();
      expect(run.hosts.single.skipReason, 'No SSH key assigned');
      expect(run.finishedAt, isNotNull);
    },
  );

  test('failing lifecycle hooks do not stop the run', () async {
    final a = FakeTarget('alpha');
    await world([a]);
    w.lifecycle.fail = true;
    await w.addHost(a, pinned: true);

    await w.start(const AllHosts());
    await w.controller.finished;
    expect(w.view('alpha').result, FinalState.unlocked);
    expect(w.lifecycle.requested, 1);
    expect(w.lifecycle.calls, ['started 1', 'progress 1/1', 'ended 1/1']);
    expect(w.state.warning, isNull);
    expect(w.state.notice, isNull);
  });

  test('the lifecycle is asked before the vault prompt and only when there '
      'are hosts; its notice goes into the run state', () async {
    final a = FakeTarget('alpha');
    await world([a]);
    var promptsAtRequest = -1;
    w.lifecycle.onRequested = () => promptsAtRequest = w.prompts;
    w.lifecycle.noticeText = 'FAKE notice';

    expect(await w.start(const AllHosts()), RunStart.noHosts);
    expect(w.lifecycle.requested, 0);

    await w.addHost(a, pinned: true);
    expect(
      await w.start(const AllHosts(), unlock: false),
      RunStart.vaultLocked,
    );
    expect(w.lifecycle.requested, 1);
    expect(promptsAtRequest, 0);

    expect(await w.start(const AllHosts()), RunStart.started);
    expect(promptsAtRequest, 1);
    expect(w.state.notice, 'FAKE notice');
    await w.controller.finished;
    expect(w.view('alpha').result, FinalState.unlocked);
    expect(w.state.notice, 'FAKE notice');
  });

  test('a key pinned during the run is never replaced', () async {
    final a = FakeTarget('alpha');
    await world([a]);
    await w.addHost(a);

    await w.start(const AllHosts());
    final request = await w.request('alpha');
    await w.hosts.setPrebootKey('id-alpha', fakeHostKey('Z'));
    w.controller.answerHostKey(request.id, accept: true);
    await w.controller.finished;

    expect((await w.hosts.get('id-alpha'))!.prebootKey, fakeHostKey('Z'));
    expect(w.state.warning, contains('not saved'));
  });

  test('the history never holds a run secret', () async {
    final dir = await Directory.systemTemp.createTemp('run_history_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');
    final a = FakeTarget('alpha')..echoesPassphrase = true;
    final b = FakeTarget('bravo', passphrase: 'FAKE-other-passphrase');
    await world([a, b], db: fileDatabase(file));
    await w.addHost(a, pinned: true);
    await w.addHost(b, pinned: true);

    await w.start(const AllHosts());
    await w.controller.finished;
    expect(a.received, [fakeServerPassphrase]);
    expect(w.view('alpha').result, FinalState.error);
    expect(w.view('bravo').result, FinalState.wrongPassphrase);

    final messages = [
      for (final e in await w.storedEvents()) e.message,
      for (final h in w.state.hosts)
        for (final e in h.log) e.message,
    ];
    expect(messages, contains(contains(redactedMarker)));
    for (final m in messages) {
      expect(m, isNot(contains(fakeServerPassphrase)));
    }
    await w.dispose();
    final bytes = file.readAsBytesSync();
    expectNotInBytes(bytes, bytesOf(fakeServerPassphrase), 'passphrase');
  });
}
