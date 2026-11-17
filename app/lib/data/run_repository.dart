import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:unlock_core/unlock_core.dart';

import 'database.dart';

@immutable
final class RunHostRecord {
  const RunHostRecord({
    required this.hostId,
    required this.hostName,
    this.finalState,
    this.skipReason,
  });

  final String hostId;

  /// Name at the time of the run; the host may be renamed or deleted since.
  final String hostName;

  /// Null while running, for a skipped host, or when the run was interrupted.
  final FinalState? finalState;
  final String? skipReason;
}

@immutable
final class RunRecord {
  const RunRecord({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.hosts,
    this.finishedAt,
  });

  final String id;
  final String title;
  final DateTime startedAt;

  /// Null while running, or when the app stopped during the run.
  final DateTime? finishedAt;
  final List<RunHostRecord> hosts;
}

/// Run history. Stores only sanitized engine messages, never a secret.
final class RunRepository {
  RunRepository(this._db, {this.keep = 100});

  final AppDatabase _db;

  /// Starting a run deletes all but the newest [keep] runs.
  final int keep;

  Future<void> create(RunRecord run) => _db.transaction(() async {
    await _db
        .into(_db.runs)
        .insert(
          RunsCompanion.insert(
            id: run.id,
            title: run.title,
            startedAt: run.startedAt,
          ),
        );
    for (final (i, h) in run.hosts.indexed) {
      await _db
          .into(_db.runHosts)
          .insert(
            RunHostsCompanion.insert(
              runId: run.id,
              hostId: h.hostId,
              hostName: h.hostName,
              position: Value(i),
              skipReason: Value(h.skipReason),
            ),
          );
    }
    final ids =
        await (_db.selectOnly(_db.runs)
              ..addColumns([_db.runs.id])
              ..orderBy([
                OrderingTerm.desc(_db.runs.startedAt),
                OrderingTerm.desc(_db.runs.rowId),
              ]))
            .map((r) => r.read(_db.runs.id)!)
            .get();
    if (ids.length > keep) {
      await (_db.delete(
        _db.runs,
      )..where((r) => r.id.isIn(ids.skip(keep)))).go();
    }
  });

  /// Stores [event]; a final event also sets the host's final state.
  Future<void> addEvent(String runId, HostEvent event) =>
      _db.transaction(() async {
        await _db
            .into(_db.runEvents)
            .insert(
              RunEventsCompanion.insert(
                runId: runId,
                hostId: event.hostId,
                time: event.time,
                phase: event.phase.id,
                message: event.message,
                result: Value(event.result?.id),
              ),
            );
        if (event.result case final result?) {
          await (_db.update(_db.runHosts)..where(
                (h) => h.runId.equals(runId) & h.hostId.equals(event.hostId),
              ))
              .write(RunHostsCompanion(finalState: Value(result.id)));
        }
      });

  Future<void> finish(String runId, DateTime finishedAt) async {
    await (_db.update(_db.runs)..where((r) => r.id.equals(runId))).write(
      RunsCompanion(finishedAt: Value(finishedAt)),
    );
  }

  /// Newest first.
  Stream<List<RunRecord>> watchAll() => _joined(null).watch().map(_group);

  Stream<RunRecord?> watch(String id) =>
      _joined(id).watch().map((rows) => _group(rows).firstOrNull);

  Stream<List<HostEvent>> watchEvents(String runId) =>
      (_db.select(_db.runEvents)
            ..where((e) => e.runId.equals(runId))
            ..orderBy([(e) => OrderingTerm.asc(e.id)]))
          .watch()
          .map((rows) => [for (final r in rows) ?_toEvent(r)]);

  /// Deletes every run but [except], e.g. the one in progress.
  Future<void> clear({String? except}) => (_db.delete(
    _db.runs,
  )..where((r) => r.id.equals(except ?? '').not())).go();

  JoinedSelectStatement<HasResultSet, dynamic> _joined(String? id) {
    final q =
        _db.select(_db.runs).join([
          leftOuterJoin(
            _db.runHosts,
            _db.runHosts.runId.equalsExp(_db.runs.id),
          ),
        ])..orderBy([
          OrderingTerm.desc(_db.runs.startedAt),
          OrderingTerm.desc(_db.runs.rowId),
          OrderingTerm.asc(_db.runHosts.position),
        ]);
    if (id != null) q.where(_db.runs.id.equals(id));
    return q;
  }

  List<RunRecord> _group(List<TypedResult> rows) {
    final runs = <String, RunRow>{};
    final hosts = <String, List<RunHostRecord>>{};
    for (final row in rows) {
      final run = row.readTable(_db.runs);
      runs[run.id] = run;
      final list = hosts[run.id] ??= [];
      if (row.readTableOrNull(_db.runHosts) case final h?) {
        list.add(
          RunHostRecord(
            hostId: h.hostId,
            hostName: h.hostName,
            finalState: _finalState(h.finalState),
            skipReason: h.skipReason,
          ),
        );
      }
    }
    return [
      for (final r in runs.values)
        RunRecord(
          id: r.id,
          title: r.title,
          startedAt: r.startedAt,
          finishedAt: r.finishedAt,
          hosts: hosts[r.id]!,
        ),
    ];
  }

  /// Null for a row this version cannot read.
  static HostEvent? _toEvent(RunEventRow r) {
    try {
      return HostEvent(
        hostId: r.hostId,
        time: r.time,
        phase: HostPhase.fromId(r.phase),
        message: r.message,
        result: _finalState(r.result),
      );
    } on FormatException {
      return null;
    }
  }

  static FinalState? _finalState(String? id) {
    if (id == null) return null;
    try {
      return FinalState.fromId(id);
    } on FormatException {
      return FinalState.error;
    }
  }
}
