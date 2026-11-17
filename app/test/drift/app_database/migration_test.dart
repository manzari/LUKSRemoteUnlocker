import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/data/database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('every upgrade path ends in the current schema', () {
    const versions = GeneratedHelper.versions;
    for (final (i, from) in versions.indexed) {
      for (final to in versions.skip(i + 1)) {
        test('$from to $to', () async {
          final schema = await verifier.schemaAt(from);
          final db = AppDatabase(schema.newConnection());
          await verifier.migrateAndValidate(db, to);
          await db.close();
        });
      }
    }
  });

  test(
    'v1 to v2 keeps hosts and run history and fills the new columns',
    () async {
      const host = v1.HostsData(
        id: 'h1',
        name: 'alpha',
        groupName: 'home',
        prebootJson: '[{"host":"192.0.2.10","port":2222}]',
        loginUser: 'root',
        diskOverridesJson: '{}',
        postbootPort: 22,
        postbootCheck: 'ssh-hostkey',
        waitTimeoutSeconds: 600,
        bootTimeoutSeconds: 300,
        legacyAlgorithms: 0,
        enabled: 1,
        createdAt: 1700000000,
      );
      const run = v1.RunsData(
        id: 'r1',
        title: 'All hosts',
        startedAt: 1700000100,
        finishedAt: 1700000200,
      );
      const runHost = v1.RunHostsData(
        runId: 'r1',
        hostId: 'h1',
        hostName: 'alpha',
        finalState: 'unlocked',
      );
      const event = v1.RunEventsData(
        id: 1,
        runId: 'r1',
        hostId: 'h1',
        time: 1700000150,
        phase: 'finished',
        message: 'booted',
        result: 'unlocked',
      );

      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, old) {
          batch.insert(old.hosts, host);
          batch.insert(old.runs, run);
          batch.insert(old.runHosts, runHost);
          batch.insert(old.runEvents, event);
        },
        validateItems: (db) async {
          expect(await db.select(db.hosts).get(), [
            v2.HostsData.fromJson(host.toJson()),
          ]);
          expect(await db.select(db.runs).get(), [
            v2.RunsData.fromJson(run.toJson()),
          ]);
          expect(await db.select(db.runHosts).get(), [
            const v2.RunHostsData(
              runId: 'r1',
              hostId: 'h1',
              hostName: 'alpha',
              finalState: 'unlocked',
              position: 0,
            ),
          ]);
          expect(await db.select(db.runEvents).get(), [
            v2.RunEventsData.fromJson(event.toJson()),
          ]);
        },
      );
    },
  );
}
