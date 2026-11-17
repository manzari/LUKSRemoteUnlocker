import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unlock_core/unlock_core.dart';

import '../data/run_repository.dart';
import '../providers.dart';
import 'run_controller.dart';
import 'run_lifecycle.dart';

final runRepositoryProvider = Provider(
  (ref) => RunRepository(ref.watch(databaseProvider)),
);

/// main() overrides it on Android with the foreground service lifecycle.
final runLifecycleProvider = Provider<RunLifecycle>(
  (ref) => const NoRunLifecycle(),
);

final runEngineFactoryProvider = Provider<RunEngineFactory>(
  (ref) => networkEngine,
);

final runDepsProvider = Provider(
  (ref) => RunDeps(
    hosts: ref.watch(hostRepositoryProvider),
    runs: ref.watch(runRepositoryProvider),
    preparation: ref.watch(runPreparationProvider),
    newEngine: ref.watch(runEngineFactoryProvider),
    lifecycle: ref.watch(runLifecycleProvider),
  ),
);

/// The current or last run of this app session; null before the first.
final runControllerProvider = NotifierProvider<RunController, RunState?>(
  () => RunController(runDepsProvider),
);

final runHistoryProvider = StreamProvider(
  (ref) => ref.watch(runRepositoryProvider).watchAll(),
);

final runRecordProvider = StreamProvider.autoDispose.family<RunRecord?, String>(
  (ref, id) => ref.watch(runRepositoryProvider).watch(id),
);

final runEventsProvider = StreamProvider.autoDispose
    .family<List<HostEvent>, String>(
      (ref, id) => ref.watch(runRepositoryProvider).watchEvents(id),
    );
