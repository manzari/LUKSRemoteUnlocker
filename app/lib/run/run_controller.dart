import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unlock_core/unlock_core.dart';

import '../data/host_repository.dart';
import '../data/ids.dart';
import '../data/run_repository.dart';
import '../services/run_preparation.dart';
import 'run_lifecycle.dart';

typedef RunEngineFactory = UnlockEngine Function(HostKeyPrompt prompt);

/// Shows the vault prompt; null when the user cancelled it.
typedef VaultUnlocker = Future<Vault?> Function();

UnlockEngine networkEngine(HostKeyPrompt prompt) => UnlockEngine(
  reachability: const TcpReachability(),
  ssh: const DartSsh2Connector(),
  hostKeyPrompt: prompt,
);

/// Which hosts a run covers.
sealed class RunSelection {
  const RunSelection();

  List<Host> pick(List<Host> hosts);

  String title(List<Host> picked);
}

/// One host, also when it is disabled.
final class OneHost extends RunSelection {
  const OneHost(this.hostId);

  final String hostId;

  @override
  List<Host> pick(List<Host> hosts) => [
    for (final h in hosts)
      if (h.id == hostId) h,
  ];

  @override
  String title(List<Host> picked) => picked.single.name;
}

final class HostGroup extends RunSelection {
  const HostGroup(this.group);

  final String group;

  @override
  List<Host> pick(List<Host> hosts) => [
    for (final h in hosts)
      if (h.enabled && h.group == group) h,
  ];

  @override
  String title(List<Host> picked) => 'Group $group';
}

final class AllHosts extends RunSelection {
  const AllHosts();

  @override
  List<Host> pick(List<Host> hosts) => [
    for (final h in hosts)
      if (h.enabled) h,
  ];

  @override
  String title(List<Host> picked) => 'All hosts';
}

@immutable
final class HostRunView {
  const HostRunView({
    required this.hostId,
    required this.name,
    this.phase,
    this.result,
    this.skipReason,
    this.log = const [],
  });

  final String hostId;
  final String name;

  /// Null before the first event and for a skipped host.
  final HostPhase? phase;
  final FinalState? result;
  final String? skipReason;

  /// Sanitized events, oldest first.
  final List<HostEvent> log;

  bool get skipped => skipReason != null;

  bool get done => skipped || result != null;

  HostRunView withEvent(HostEvent e) => HostRunView(
    hostId: hostId,
    name: name,
    phase: e.phase,
    result: e.result ?? result,
    skipReason: skipReason,
    log: [...log, e],
  );
}

/// An unpinned pre-boot key waiting for the user; only its host is paused.
@immutable
final class HostKeyRequest {
  const HostKeyRequest({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.key,
  });

  final int id;
  final String hostId;
  final String hostName;
  final HostKey key;
}

@immutable
final class RunState {
  const RunState({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.hosts,
    this.finishedAt,
    this.hostKeyRequests = const [],
    this.cancelling = false,
    this.warning,
    this.notice,
  });

  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<HostRunView> hosts;
  final List<HostKeyRequest> hostKeyRequests;
  final bool cancelling;

  /// Set when the history or a host key could not be saved.
  final String? warning;

  /// From [RunLifecycle.notice], e.g. that progress notifications are off.
  final String? notice;

  bool get running => finishedAt == null;

  RunState copyWith({
    DateTime? finishedAt,
    List<HostRunView>? hosts,
    List<HostKeyRequest>? hostKeyRequests,
    bool? cancelling,
    String? warning,
  }) => RunState(
    id: id,
    title: title,
    startedAt: startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    hosts: hosts ?? this.hosts,
    hostKeyRequests: hostKeyRequests ?? this.hostKeyRequests,
    cancelling: cancelling ?? this.cancelling,
    warning: warning ?? this.warning,
    notice: notice,
  );

  RunState withEvent(HostEvent e) => copyWith(
    hosts: [for (final h in hosts) h.hostId == e.hostId ? h.withEvent(e) : h],
  );
}

enum RunStart { started, busy, noHosts, vaultLocked }

/// Everything the run controller depends on; tests swap in fakes.
final class RunDeps {
  const RunDeps({
    required this.hosts,
    required this.runs,
    required this.preparation,
    this.newEngine = networkEngine,
    this.lifecycle = const NoRunLifecycle(),
  });

  final HostRepository hosts;
  final RunRepository runs;
  final RunPreparation preparation;
  final RunEngineFactory newEngine;
  final RunLifecycle lifecycle;
}

/// Runs one selection at a time: one vault prompt, live state, history, wiping.
class RunController extends Notifier<RunState?> {
  RunController(this._depsProvider);

  final Provider<RunDeps> _depsProvider;
  UnlockEngine? _engine;
  var _starting = false;
  var _nextRequest = 0;
  final _answers = <int, ({String hostId, Completer<bool> answer})>{};
  Future<void> _finished = Future.value();

  @override
  RunState? build() {
    ref.onDispose(() {
      _engine?.cancel();
      for (final p in _answers.values) {
        if (!p.answer.isCompleted) p.answer.complete(false);
      }
      _answers.clear();
    });
    return null;
  }

  /// True from [start] until the run is over.
  bool get busy => _starting || (state?.running ?? false);

  /// Completes when the last run is over: history written, secrets wiped.
  Future<void> get finished => _finished;

  /// Picks the hosts, shows [unlockVault] once, then runs in the background.
  Future<RunStart> start(
    RunSelection selection, {
    required VaultUnlocker unlockVault,
  }) async {
    if (busy) return RunStart.busy;
    _starting = true;
    PreparedRun? prepared;
    try {
      final deps = ref.read(_depsProvider);
      final hosts = selection.pick(await deps.hosts.all());
      if (hosts.isEmpty) return RunStart.noHosts;
      try {
        await deps.lifecycle.runRequested();
      } on Object catch (e) {
        debugPrint('Run lifecycle hook failed: ${e.runtimeType}');
      }
      if (!ref.mounted) return RunStart.busy;
      final vault = await unlockVault();
      if (vault == null || !ref.mounted) return RunStart.vaultLocked;
      prepared = await deps.preparation.prepare(vault, hosts);
      if (!ref.mounted) return RunStart.busy;
      _finished = _run(deps, prepared, selection.title(hosts), hosts);
      prepared = null;
      return RunStart.started;
    } finally {
      prepared?.wipe();
      _starting = false;
    }
  }

  void cancel() {
    if (!(state?.running ?? false)) return;
    _update((s) => s.copyWith(cancelling: true));
    _engine?.cancel();
    _declineWhere((_) => true);
  }

  void cancelHost(String hostId) {
    _engine?.cancelHost(hostId);
    _declineWhere((id) => id == hostId);
  }

  /// The user's answer to a [HostKeyRequest]; declining ends that host as Cancelled.
  void answerHostKey(int requestId, {required bool accept}) {
    final pending = _answers.remove(requestId);
    _update(
      (s) => s.copyWith(
        hostKeyRequests: [
          for (final r in s.hostKeyRequests)
            if (r.id != requestId) r,
        ],
      ),
    );
    if (pending != null && !pending.answer.isCompleted) {
      pending.answer.complete(accept);
    }
  }

  Future<bool> _confirmHostKey(Host host, HostKey key) {
    if (!ref.mounted || !(state?.running ?? false)) return Future.value(false);
    final request = HostKeyRequest(
      id: _nextRequest++,
      hostId: host.id,
      hostName: host.name,
      key: key,
    );
    final answer = Completer<bool>();
    _answers[request.id] = (hostId: host.id, answer: answer);
    _update(
      (s) => s.copyWith(hostKeyRequests: [...s.hostKeyRequests, request]),
    );
    return answer.future;
  }

  void _declineWhere(bool Function(String hostId) test) {
    final ids = [
      for (final e in _answers.entries)
        if (test(e.value.hostId)) e.key,
    ];
    for (final id in ids) {
      answerHostKey(id, accept: false);
    }
  }

  Future<void> _run(
    RunDeps deps,
    PreparedRun prepared,
    String title,
    List<Host> order,
  ) async {
    final skipped = {for (final s in prepared.skipped) s.host.id: s.reason};
    final planned = {for (final p in prepared.plans) p.host.id};
    final views = [
      for (final h in order)
        if (planned.contains(h.id) || skipped.containsKey(h.id))
          HostRunView(hostId: h.id, name: h.name, skipReason: skipped[h.id]),
    ];
    final id = newId();
    final startedAt = DateTime.now();
    String? notice;
    if (planned.isNotEmpty) {
      try {
        notice = deps.lifecycle.notice;
      } on Object catch (e) {
        debugPrint('Run lifecycle notice failed: ${e.runtimeType}');
      }
    }
    if (ref.mounted) {
      state = RunState(
        id: id,
        title: title,
        startedAt: startedAt,
        hosts: views,
        notice: notice,
      );
    }

    final writes = _Serial(
      () => _warn('Part of the run history could not be saved.'),
    );
    final hooks = _Serial(() {});
    var activity = RunActivity(
      runId: id,
      title: title,
      hostCount: prepared.plans.length,
    );
    writes.add(
      () => deps.runs.create(
        RunRecord(
          id: id,
          title: title,
          startedAt: startedAt,
          hosts: [
            for (final v in views)
              RunHostRecord(
                hostId: v.hostId,
                hostName: v.name,
                skipReason: v.skipReason,
              ),
          ],
        ),
      ),
    );

    void onEvent(HostEvent e) {
      _update((s) => s.withEvent(e));
      writes.add(() => deps.runs.addEvent(id, e));
      if (e.newPrebootKey case final k?) {
        writes.add(() async {
          if (!await deps.hosts.pinPrebootKeyIfUnset(e.hostId, k)) {
            _warn(
              'The accepted pre-boot key was not saved because another key '
              'was pinned during the run.',
            );
          }
        });
      }
      if (e.newPostbootKey case final k?) {
        writes.add(() => deps.hosts.recordPostbootKeyIfUnset(e.hostId, k));
      }
      if (e.isFinal) {
        _declineWhere((id) => id == e.hostId);
        final done = activity = activity.withFinished(
          activity.finishedCount + 1,
        );
        hooks.add(() => deps.lifecycle.runProgress(done));
      }
    }

    final unfinished = {...planned};
    try {
      if (planned.isNotEmpty) {
        final engine = _engine = deps.newEngine(_Prompt(this));
        // Registered before the hook runs, so a cancel in the meantime still applies.
        final events = engine.run(prepared.plans);
        hooks.add(() => deps.lifecycle.runStarted(activity));
        await hooks.idle;
        await for (final e in events) {
          if (e.isFinal) unfinished.remove(e.hostId);
          onEvent(e);
        }
      }
    } on Object catch (e) {
      debugPrint('Run ended with ${e.runtimeType}');
    } finally {
      _engine = null;
      _declineWhere((_) => true);
      prepared.wipe();
    }
    for (final hostId in unfinished) {
      onEvent(
        HostEvent(
          hostId: hostId,
          time: DateTime.now(),
          phase: HostPhase.finished,
          message: 'the run ended unexpectedly',
          result: FinalState.error,
        ),
      );
    }
    final finishedAt = DateTime.now();
    writes.add(() => deps.runs.finish(id, finishedAt));
    if (planned.isNotEmpty) hooks.add(() => deps.lifecycle.runEnded(activity));
    await Future.wait([writes.idle, hooks.idle]);
    _update((s) => s.copyWith(finishedAt: finishedAt, cancelling: false));
  }

  void _warn(String message) =>
      _update((s) => s.warning == null ? s.copyWith(warning: message) : s);

  void _update(RunState Function(RunState s) change) {
    if (!ref.mounted) return;
    final s = state;
    if (s != null) state = change(s);
  }
}

final class _Prompt implements HostKeyPrompt {
  _Prompt(this._controller);

  final RunController _controller;

  @override
  Future<bool> confirm(Host host, HostKey key) =>
      _controller._confirmHostKey(host, key);
}

/// Runs async operations one after another; a failure calls [onError] and the next one still runs.
final class _Serial {
  _Serial(this.onError);

  final void Function() onError;
  Future<void> _tail = Future.value();

  Future<void> get idle => _tail;

  void add(Future<void> Function() op) {
    _tail = _tail.then((_) => op()).catchError((Object e) {
      debugPrint('Run bookkeeping failed: ${e.runtimeType}');
      onError();
    });
  }
}
