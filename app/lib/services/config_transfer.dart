import 'dart:typed_data';

import 'package:unlock_core/unlock_core.dart';

import '../data/database.dart';
import '../data/errors.dart';
import '../data/host_repository.dart';
import '../data/ids.dart';
import '../data/key_repository.dart';
import '../data/profile_repository.dart';
import '../data/secret_repository.dart';
import 'config_file.dart';

final class ConfigExport {
  const ConfigExport({
    required this.bytes,
    required this.hosts,
    required this.profiles,
    required this.unreadable,
  });

  final Uint8List bytes;
  final int hosts;
  final int profiles;

  /// Host rows that could not be read and were left out.
  final int unreadable;
}

/// A key or passphrase from the file matched to one stored here.
final class Relink {
  const Relink({
    required this.fileLabel,
    required this.localLabel,
    required this.usedBy,
    this.fingerprint,
  });

  final String fileLabel;
  final String localLabel;
  final String? fingerprint;

  /// Host names, with the disk for per-disk passphrases.
  final List<String> usedBy;
}

enum ReferenceKind { sshKey, passphrase, profile }

/// A reference with no match here; the assignment is left empty.
final class Unlinked {
  const Unlinked({
    required this.kind,
    required this.label,
    required this.usedBy,
    this.fingerprint,
  });

  final ReferenceKind kind;
  final String label;
  final String? fingerprint;
  final List<String> usedBy;
}

/// What an import would change; nothing is written until [ConfigTransfer.apply].
final class ImportPlan {
  ImportPlan._({
    required this.exportedAt,
    required this.hosts,
    required this.clashes,
    required this.newProfiles,
    required this.existingProfiles,
    required this.renamedProfiles,
    required this.keys,
    required this.passphrases,
    required this.unlinked,
  });

  final DateTime exportedAt;

  /// New hosts with fresh ids, pinned keys included.
  final List<Host> hosts;

  /// Names of hosts in the file that already exist here; they are skipped.
  final List<String> clashes;
  final List<UnlockProfile> newProfiles;

  /// Names of profiles in the file identical to one stored here.
  final List<String> existingProfiles;
  final List<({String from, String to})> renamedProfiles;
  final List<Relink> keys;
  final List<Relink> passphrases;
  final List<Unlinked> unlinked;

  int get pinned => hosts.where((h) => h.prebootKey != null).length;

  bool get isEmpty => hosts.isEmpty && newProfiles.isEmpty;
}

final class _Snapshot {
  const _Snapshot(this.hostNames, this.keys, this.secrets, this.profiles);

  final List<String> hostNames;
  final List<StoredKey> keys;
  final List<StoredSecret> secrets;
  final List<UnlockProfile> profiles;
}

/// Export and import of the non-secret configuration.
final class ConfigTransfer {
  ConfigTransfer(
    this._db,
    this._hosts,
    this._keys,
    this._secrets,
    this._profiles,
  );

  final AppDatabase _db;
  final HostRepository _hosts;
  final KeyRepository _keys;
  final SecretRepository _secrets;
  final ProfileRepository _profiles;

  /// Reads only public key parts and labels; no vault record is touched.
  Future<ConfigExport> export({DateTime? now}) => _db.transaction(() async {
    final rows = await _db.select(_db.hosts).get();
    final hosts = await _hosts.all();
    final keys = {for (final k in await _keys.all()) k.id: k};
    final secrets = {for (final s in await _secrets.all()) s.id: s.label};
    final profiles = [
      for (final p in await _profiles.all())
        if (!p.builtIn) p,
    ];
    final profileIds = {
      for (final p in [...UnlockProfile.builtIns, ...profiles]) p.id,
    };
    final file = ConfigFile(
      exportedAt: now ?? DateTime.now(),
      profiles: profiles,
      hosts: [
        for (final h in hosts)
          ConfigHost(
            host: h,
            key: switch (keys[h.keyId]) {
              final k? => KeyReference(
                label: k.label,
                type: k.typeName,
                publicLine: k.publicLine,
                fingerprint: k.fingerprint,
              ),
              null => null,
            },
            passphrase: secrets[h.secretId],
            diskPassphrases: {
              for (final MapEntry(key: disk, value: id)
                  in h.diskOverrides.entries)
                disk: ?secrets[id],
            },
            profileRef: profileIds.contains(h.profileId) ? h.profileId : null,
          ),
      ],
    );
    return ConfigExport(
      bytes: file.encode(),
      hosts: hosts.length,
      profiles: profiles.length,
      unreadable: rows.length - hosts.length,
    );
  });

  /// Parses strictly (throws [FormatException]) and plans against the current data.
  Future<ImportPlan> preview(Uint8List bytes) async {
    final file = ConfigFile.decode(bytes);
    return _plan(file, await _snapshot());
  }

  /// Writes the plan in one transaction; pinned keys only when [trustPins].
  Future<int> apply(ImportPlan plan, {required bool trustPins}) =>
      _db.transaction(() async {
        _requireUnchanged(plan, await _snapshot());
        for (final p in plan.newProfiles) {
          await _profiles.save(p);
        }
        for (final h in plan.hosts) {
          await _hosts.save(trustPins ? h : h.copyWith(clearPrebootKey: true));
        }
        return plan.hosts.length;
      });

  Future<_Snapshot> _snapshot() async => _Snapshot(
    [for (final r in await _db.select(_db.hosts).get()) r.name],
    await _keys.all(),
    await _secrets.all(),
    await _profiles.all(),
  );

  /// All or nothing: refuses when a name got taken or a relinked item vanished since the preview.
  static void _requireUnchanged(ImportPlan plan, _Snapshot now) {
    final keyIds = {for (final k in now.keys) k.id};
    final secretIds = {for (final s in now.secrets) s.id};
    final profileIds = {
      for (final p in [...now.profiles, ...plan.newProfiles]) p.id,
    };
    for (final h in plan.hosts) {
      final ok =
          !now.hostNames.any((n) => sameLabel(n, h.name)) &&
          (h.keyId == null || keyIds.contains(h.keyId)) &&
          (h.secretId == null || secretIds.contains(h.secretId)) &&
          h.diskOverrides.values.every(secretIds.contains) &&
          (h.profileId == null || profileIds.contains(h.profileId));
      if (!ok) throw const ImportChangedException();
    }
    for (final p in plan.newProfiles) {
      if (now.profiles.any((e) => e.id == p.id)) {
        throw const ImportChangedException();
      }
    }
  }

  static ImportPlan _plan(ConfigFile file, _Snapshot s) {
    final profileIds = {for (final p in UnlockProfile.builtIns) p.id: p.id};
    final newProfiles = <UnlockProfile>[];
    final existingProfiles = <String>[];
    final renamed = <({String from, String to})>[];
    final names = [for (final p in s.profiles) p.name];
    for (final p in file.profiles) {
      final same = s.profiles
          .where((e) => !e.builtIn && _sameProfile(e, p))
          .firstOrNull;
      if (same != null) {
        profileIds[p.id] = same.id;
        existingProfiles.add(p.name);
        continue;
      }
      final name = _freeName(p.name, names);
      if (name != p.name) renamed.add((from: p.name, to: name));
      names.add(name);
      final created = p.copyWith(id: newId(), name: name, builtIn: false);
      newProfiles.add(created);
      profileIds[p.id] = created.id;
    }

    final keysByFingerprint = {for (final k in s.keys) k.fingerprint: k};
    final secretsByLabel = {
      for (final x in s.secrets) x.label.trim().toLowerCase(): x,
    };
    final keyLinks = <String, Relink>{};
    final secretLinks = <String, Relink>{};
    final unlinked = <String, Unlinked>{};

    String? key(KeyReference? ref, String user) {
      if (ref == null) return null;
      final found = keysByFingerprint[ref.fingerprint];
      if (found == null) {
        _addUnlinked(
          unlinked,
          ReferenceKind.sshKey,
          ref.label,
          user,
          ref.fingerprint,
        );
        return null;
      }
      (keyLinks[ref.fingerprint] ??= Relink(
        fileLabel: ref.label,
        localLabel: found.label,
        fingerprint: ref.fingerprint,
        usedBy: [],
      )).usedBy.add(user);
      return found.id;
    }

    String? secret(String? label, String user) {
      if (label == null) return null;
      final norm = label.trim().toLowerCase();
      final found = secretsByLabel[norm];
      if (found == null) {
        _addUnlinked(unlinked, ReferenceKind.passphrase, label, user, null);
        return null;
      }
      (secretLinks[norm] ??= Relink(
        fileLabel: label,
        localLabel: found.label,
        usedBy: [],
      )).usedBy.add(user);
      return found.id;
    }

    final hosts = <Host>[];
    final clashes = <String>[];
    for (final c in file.hosts) {
      final h = c.host;
      if (s.hostNames.any((n) => sameLabel(n, h.name))) {
        clashes.add(h.name);
        continue;
      }
      final keyId = key(c.key, h.name);
      final secretId = secret(c.passphrase, h.name);
      final overrides = <String, String>{};
      for (final MapEntry(key: disk, value: label)
          in c.diskPassphrases.entries) {
        if (secret(label, '${h.name} (disk $disk)') case final id?) {
          overrides[disk] = id;
        }
      }
      final ref = c.profileRef;
      final profileId = ref == null ? null : profileIds[ref];
      if (ref != null && profileId == null) {
        _addUnlinked(unlinked, ReferenceKind.profile, ref, h.name, null);
      }
      hosts.add(
        Host(
          id: newId(),
          name: h.name,
          group: h.group,
          preboot: h.preboot,
          user: h.user,
          keyId: keyId,
          secretId: secretId,
          diskOverrides: overrides,
          profileId: profileId,
          postbootHost: h.postbootHost,
          postbootPort: h.postbootPort,
          postbootCheck: h.postbootCheck,
          waitTimeout: h.waitTimeout,
          bootTimeout: h.bootTimeout,
          prebootKey: h.prebootKey,
          postbootKey: h.postbootKey,
          legacyAlgorithms: h.legacyAlgorithms,
          enabled: h.enabled,
        ),
      );
    }
    return ImportPlan._(
      exportedAt: file.exportedAt,
      hosts: hosts,
      clashes: clashes,
      newProfiles: newProfiles,
      existingProfiles: existingProfiles,
      renamedProfiles: renamed,
      keys: keyLinks.values.toList(),
      passphrases: secretLinks.values.toList(),
      unlinked: unlinked.values.toList(),
    );
  }

  static void _addUnlinked(
    Map<String, Unlinked> into,
    ReferenceKind kind,
    String label,
    String user,
    String? fingerprint,
  ) {
    final id = '${kind.name}:${fingerprint ?? label.trim().toLowerCase()}';
    (into[id] ??= Unlinked(
      kind: kind,
      label: label,
      fingerprint: fingerprint,
      usedBy: [],
    )).usedBy.add(user);
  }

  static bool _sameProfile(UnlockProfile a, UnlockProfile b) =>
      a.name == b.name &&
      a.driver == b.driver &&
      a.command == b.command &&
      a.promptRegex == b.promptRegex &&
      a.successRegex == b.successRegex &&
      a.failureRegex == b.failureRegex;

  static String _freeName(String name, List<String> taken) {
    bool free(String n) => !taken.any((t) => sameLabel(t, n));
    if (free(name)) return name;
    for (var i = 1; ; i++) {
      final candidate = i == 1 ? '$name (imported)' : '$name (imported $i)';
      if (free(candidate)) return candidate;
    }
  }
}
