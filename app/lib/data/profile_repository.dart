import 'package:unlock_core/unlock_core.dart';

import 'database.dart';
import 'errors.dart';
import 'host_repository.dart';
import 'ids.dart';

final class ProfileRepository {
  ProfileRepository(this._db, this._hosts);

  final AppDatabase _db;
  final HostRepository _hosts;

  Stream<List<UnlockProfile>> watchAll() =>
      _db.select(_db.profiles).watch().map(_sorted);

  Future<List<UnlockProfile>> all() async =>
      _sorted(await _db.select(_db.profiles).get());

  Future<UnlockProfile?> get(String id) async {
    final row = await (_db.select(
      _db.profiles,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null ? null : toProfile(row);
  }

  Future<UnlockProfile> copy(String id) async {
    final source =
        await get(id) ?? (throw const NotFoundException('Profile not found.'));
    final copy = source.copyWith(
      id: newId(),
      name: '${source.name} (copy)',
      builtIn: false,
    );
    await _db.into(_db.profiles).insert(AppDatabase.profileCompanion(copy));
    return copy;
  }

  /// Inserts or updates a custom profile; built-ins are refused.
  Future<void> save(UnlockProfile profile) => _db.transaction(() async {
    final existing = await get(profile.id);
    if (profile.builtIn || (existing?.builtIn ?? false)) {
      throw const ReadOnlyProfileException();
    }
    await _db
        .into(_db.profiles)
        .insertOnConflictUpdate(AppDatabase.profileCompanion(profile));
  });

  Future<void> delete(String id) => _db.transaction(() async {
    final profile = await get(id);
    if (profile == null) return;
    if (profile.builtIn) throw const ReadOnlyProfileException();
    final users = await _hosts.namesUsingProfile(id);
    if (users.isNotEmpty) throw InUseException('Profile', profile.name, users);
    await (_db.delete(_db.profiles)..where((p) => p.id.equals(id))).go();
  });

  static List<UnlockProfile> _sorted(List<ProfileRow> rows) =>
      rows.map(toProfile).toList()..sort((a, b) {
        if (a.builtIn != b.builtIn) return a.builtIn ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

  static UnlockProfile toProfile(ProfileRow r) => UnlockProfile(
    id: r.id,
    name: r.name,
    command: r.command,
    driver: UnlockDriverKind.fromId(r.driver),
    builtIn: r.builtIn,
    promptRegex: r.promptRegex,
    successRegex: r.successRegex,
    failureRegex: r.failureRegex,
  );
}
