import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:unlock_core/unlock_core.dart';

import 'database.dart';

final class HostRepository {
  HostRepository(this._db);

  final AppDatabase _db;

  Stream<List<Host>> watchAll() =>
      _db.select(_db.hosts).watch().map((rows) => _sorted(rows.map(toHost)));

  Future<List<Host>> all() async =>
      _sorted((await _db.select(_db.hosts).get()).map(toHost));

  Future<Host?> get(String id) async {
    final row = await (_db.select(
      _db.hosts,
    )..where((h) => h.id.equals(id))).getSingleOrNull();
    return row == null ? null : toHost(row);
  }

  /// Inserts or updates; throws [ArgumentError] when [Host.validate] finds problems.
  Future<void> save(Host host) async {
    final problems = host.validate();
    if (problems.isNotEmpty) {
      throw ArgumentError.value(host.name, 'host', problems.join('; '));
    }
    final values = _companion(host);
    await _db.transaction(() async {
      final updated = await (_db.update(
        _db.hosts,
      )..where((h) => h.id.equals(host.id))).write(values);
      if (updated == 0) {
        await _db
            .into(_db.hosts)
            .insert(values.copyWith(createdAt: Value(DateTime.now())));
      }
    });
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.hosts)..where((h) => h.id.equals(id))).go();

  Future<void> setEnabled(String id, bool enabled) =>
      _patch(id, HostsCompanion(enabled: Value(enabled)));

  /// Pins (or with null, clears) the pre-boot key, e.g. after a run accepted a new key.
  Future<void> setPrebootKey(String id, HostKey? key) =>
      _patch(id, HostsCompanion(prebootKeyJson: Value(_keyJson(key))));

  Future<void> setPostbootKey(String id, HostKey? key) =>
      _patch(id, HostsCompanion(postbootKeyJson: Value(_keyJson(key))));

  Future<List<String>> namesUsingKey(String keyId) async => [
    for (final h in await all())
      if (h.keyId == keyId) h.name,
  ];

  /// Hosts using the secret as default or as a per-disk override.
  Future<List<String>> namesUsingSecret(String secretId) async => [
    for (final h in await all())
      if (h.secretId == secretId || h.diskOverrides.containsValue(secretId))
        h.name,
  ];

  Future<List<String>> namesUsingProfile(String profileId) async => [
    for (final h in await all())
      if (h.profileId == profileId) h.name,
  ];

  Future<void> _patch(String id, HostsCompanion values) async {
    await (_db.update(_db.hosts)..where((h) => h.id.equals(id))).write(values);
  }

  static List<Host> _sorted(Iterable<Host> hosts) => hosts.toList()
    ..sort((a, b) {
      final g = (a.group ?? '').toLowerCase().compareTo(
        (b.group ?? '').toLowerCase(),
      );
      return g != 0 ? g : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  static Host toHost(HostRow r) => Host(
    id: r.id,
    name: r.name,
    group: r.groupName,
    preboot: [
      for (final e in jsonDecode(r.prebootJson) as List<Object?>)
        Endpoint.fromJson((e! as Map<Object?, Object?>).cast()),
    ],
    user: r.loginUser,
    keyId: r.keyId,
    secretId: r.secretId,
    diskOverrides: (jsonDecode(r.diskOverridesJson) as Map<Object?, Object?>)
        .cast(),
    profileId: r.profileId,
    postbootHost: r.postbootHost,
    postbootPort: r.postbootPort,
    postbootCheck: PostBootCheck.fromId(r.postbootCheck),
    waitTimeout: Duration(seconds: r.waitTimeoutSeconds),
    bootTimeout: Duration(seconds: r.bootTimeoutSeconds),
    prebootKey: _key(r.prebootKeyJson),
    postbootKey: _key(r.postbootKeyJson),
    legacyAlgorithms: r.legacyAlgorithms,
    enabled: r.enabled,
  );

  static HostKey? _key(String? json) => json == null
      ? null
      : HostKey.fromJson((jsonDecode(json) as Map<Object?, Object?>).cast());

  static String? _keyJson(HostKey? key) =>
      key == null ? null : jsonEncode(key.toJson());

  static HostsCompanion _companion(Host h) => HostsCompanion(
    id: Value(h.id),
    name: Value(h.name.trim()),
    groupName: Value(_blankToNull(h.group)),
    prebootJson: Value(jsonEncode([for (final e in h.preboot) e.toJson()])),
    loginUser: Value(h.user.trim()),
    keyId: Value(h.keyId),
    secretId: Value(h.secretId),
    diskOverridesJson: Value(jsonEncode(h.diskOverrides)),
    profileId: Value(h.profileId),
    postbootHost: Value(_blankToNull(h.postbootHost)),
    postbootPort: Value(h.postbootPort),
    postbootCheck: Value(h.postbootCheck.id),
    waitTimeoutSeconds: Value(h.waitTimeout.inSeconds),
    bootTimeoutSeconds: Value(h.bootTimeout.inSeconds),
    prebootKeyJson: Value(_keyJson(h.prebootKey)),
    postbootKeyJson: Value(_keyJson(h.postbootKey)),
    legacyAlgorithms: Value(h.legacyAlgorithms),
    enabled: Value(h.enabled),
  );

  static String? _blankToNull(String? s) =>
      s == null || s.trim().isEmpty ? null : s.trim();
}
