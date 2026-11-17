import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:unlock_core/unlock_core.dart';

import 'database.dart';

final class HostRepository {
  HostRepository(this._db);

  final AppDatabase _db;

  /// Rows that cannot be read are left out instead of failing the whole list.
  Stream<List<Host>> watchAll() => _db.select(_db.hosts).watch().map(_readable);

  Future<List<Host>> all() async =>
      _readable(await _db.select(_db.hosts).get());

  /// Null when missing or unreadable.
  Future<Host?> get(String id) async {
    final row = await (_db.select(
      _db.hosts,
    )..where((h) => h.id.equals(id))).getSingleOrNull();
    return row == null ? null : tryToHost(row);
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

  /// Pins a key accepted in a run; false when a key is pinned already, which a run never replaces.
  Future<bool> pinPrebootKeyIfUnset(String id, HostKey key) async =>
      await (_db.update(_db.hosts)
            ..where((h) => h.id.equals(id) & h.prebootKeyJson.isNull()))
          .write(HostsCompanion(prebootKeyJson: Value(_keyJson(key)))) >
      0;

  /// Records the first post-boot key a run saw; false when one is recorded already.
  Future<bool> recordPostbootKeyIfUnset(String id, HostKey key) async =>
      await (_db.update(_db.hosts)
            ..where((h) => h.id.equals(id) & h.postbootKeyJson.isNull()))
          .write(HostsCompanion(postbootKeyJson: Value(_keyJson(key)))) >
      0;

  // The names* lookups read raw rows, so unreadable hosts still block deleting what they reference.
  Future<List<String>> namesUsingKey(String keyId) async => [
    for (final r in await _rows())
      if (r.keyId == keyId) r.name,
  ];

  /// Hosts using the secret as default or as a per-disk override.
  Future<List<String>> namesUsingSecret(String secretId) async => [
    for (final r in await _rows())
      if (r.secretId == secretId || _overrides(r).containsValue(secretId))
        r.name,
  ];

  Future<List<String>> namesUsingProfile(String profileId) async => [
    for (final r in await _rows())
      if (r.profileId == profileId) r.name,
  ];

  Future<List<HostRow>> _rows() async =>
      (await _db.select(_db.hosts).get())
        ..sort((a, b) => _order(a.groupName, a.name, b.groupName, b.name));

  static Map<String, String> _overrides(HostRow r) {
    try {
      return _decodeOverrides(r.diskOverridesJson);
    } on Object {
      return const {};
    }
  }

  static List<Host> _readable(List<HostRow> rows) =>
      _sorted([for (final r in rows) ?tryToHost(r)]);

  Future<void> _patch(String id, HostsCompanion values) async {
    await (_db.update(_db.hosts)..where((h) => h.id.equals(id))).write(values);
  }

  static List<Host> _sorted(Iterable<Host> hosts) =>
      hosts.toList()..sort((a, b) => _order(a.group, a.name, b.group, b.name));

  static int _order(
    String? groupA,
    String nameA,
    String? groupB,
    String nameB,
  ) {
    final g = (groupA ?? '').toLowerCase().compareTo(
      (groupB ?? '').toLowerCase(),
    );
    return g != 0 ? g : nameA.toLowerCase().compareTo(nameB.toLowerCase());
  }

  /// Null for a row whose stored JSON or values cannot be read.
  static Host? tryToHost(HostRow r) {
    try {
      return toHost(r);
    } on Object {
      debugPrint('Skipping unreadable host ${r.id}');
      return null;
    }
  }

  /// Throws on malformed stored data; see [tryToHost].
  static Host toHost(HostRow r) => Host(
    id: r.id,
    name: r.name,
    group: r.groupName,
    preboot: [
      for (final e in jsonDecode(r.prebootJson) as List<Object?>)
        Endpoint.fromJson(Map<String, Object?>.from(e! as Map)),
    ],
    user: r.loginUser,
    keyId: r.keyId,
    secretId: r.secretId,
    diskOverrides: _decodeOverrides(r.diskOverridesJson),
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

  static Map<String, String> _decodeOverrides(String json) =>
      Map<String, String>.from(jsonDecode(json) as Map);

  static HostKey? _key(String? json) => json == null
      ? null
      : HostKey.fromJson(Map<String, Object?>.from(jsonDecode(json) as Map));

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
