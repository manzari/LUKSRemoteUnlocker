import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/database.dart';
import 'package:luks_remote_unlocker/data/run_repository.dart';
import 'package:unlock_core/unlock_core.dart';

import '../support/harness.dart';

void main() {
  late AppDatabase db;
  late RunRepository runs;

  setUp(() {
    db = memoryDatabase();
    runs = RunRepository(db, keep: 2);
  });
  tearDown(() => db.close());

  RunRecord run(String id, int minute) => RunRecord(
    id: id,
    title: 'run $id',
    startedAt: DateTime(2026, 11, 16, 12, minute),
    hosts: const [
      RunHostRecord(hostId: 'b', hostName: 'bravo'),
      RunHostRecord(
        hostId: 'a',
        hostName: 'alpha',
        skipReason: 'No SSH key assigned',
      ),
    ],
  );

  HostEvent event(String hostId, {FinalState? result}) => HostEvent(
    hostId: hostId,
    time: DateTime(2026, 11, 16, 12),
    phase: result == null ? HostPhase.unlocking : HostPhase.finished,
    message: result == null ? 'running' : 'done',
    result: result,
  );

  test('hosts keep their order; a final event sets the final state', () async {
    await runs.create(run('r1', 0));
    await runs.addEvent('r1', event('b'));
    await runs.addEvent('r1', event('b', result: FinalState.wrongPassphrase));
    await runs.finish('r1', DateTime(2026, 11, 16, 12, 5));

    final stored = (await runs.watch('r1').first)!;
    expect(stored.hosts.map((h) => h.hostName), ['bravo', 'alpha']);
    expect(stored.hosts.map((h) => h.finalState), [
      FinalState.wrongPassphrase,
      null,
    ]);
    expect(stored.hosts.last.skipReason, 'No SSH key assigned');
    expect(stored.finishedAt, DateTime(2026, 11, 16, 12, 5));
    final events = await runs.watchEvents('r1').first;
    expect(events.map((e) => e.message), ['running', 'done']);
    expect(events.last.result, FinalState.wrongPassphrase);
  });

  test('only the newest runs are kept, with their events', () async {
    await runs.create(run('r1', 0));
    await runs.addEvent('r1', event('b'));
    await runs.create(run('r2', 1));
    await runs.create(run('r3', 2));

    expect((await runs.watchAll().first).map((r) => r.id), ['r3', 'r2']);
    expect(await db.select(db.runEvents).get(), isEmpty);
    expect((await db.select(db.runHosts).get()).map((h) => h.runId).toSet(), {
      'r2',
      'r3',
    });
  });

  test('clearing keeps the run in progress', () async {
    await runs.create(run('r1', 0));
    await runs.create(run('r2', 1));
    await runs.clear(except: 'r2');
    expect((await runs.watchAll().first).map((r) => r.id), ['r2']);
    await runs.clear();
    expect(await runs.watchAll().first, isEmpty);
  });
}
