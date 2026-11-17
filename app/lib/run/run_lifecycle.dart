import 'package:flutter/foundation.dart';

/// What a lifecycle hook learns about a run: no host details, no secrets.
@immutable
final class RunActivity {
  const RunActivity({
    required this.runId,
    required this.title,
    required this.hostCount,
    this.finishedCount = 0,
  });

  final String runId;
  final String title;

  /// Hosts the engine works on; skipped hosts are not counted.
  final int hostCount;
  final int finishedCount;

  RunActivity withFinished(int finished) => RunActivity(
    runId: runId,
    title: title,
    hostCount: hostCount,
    finishedCount: finished,
  );
}

/// Hooks around a run's engine part, e.g. to keep the device awake; errors thrown here are ignored.
abstract class RunLifecycle {
  const RunLifecycle();

  /// Before the vault prompt of a run that has hosts, e.g. to ask for a permission.
  Future<void> runRequested() async {}

  /// A short note for the run screen, read when a run starts; null for none.
  String? get notice => null;

  /// Awaited before the engine starts.
  Future<void> runStarted(RunActivity run) async {}

  /// After each host reached its final state.
  Future<void> runProgress(RunActivity run) async {}

  /// Once per started run, also after a cancel or an error, when the secrets are wiped.
  Future<void> runEnded(RunActivity run) async {}
}

final class NoRunLifecycle extends RunLifecycle {
  const NoRunLifecycle();
}
