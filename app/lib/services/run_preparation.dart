import 'dart:typed_data';

import 'package:unlock_core/unlock_core.dart';

import '../data/key_repository.dart';
import '../data/profile_repository.dart';
import '../data/secret_repository.dart';

final class SkippedHost {
  const SkippedHost(this.host, this.reason);

  final Host host;
  final String reason;
}

/// Decrypted plans for one run. Call [wipe] when the run ends.
final class PreparedRun {
  PreparedRun(this.plans, this.skipped, this._buffers);

  final List<HostPlan> plans;
  final List<SkippedHost> skipped;
  final List<Uint8List> _buffers;

  /// Overwrites every decrypted buffer; Dart cannot guarantee no other copies exist.
  void wipe() {
    for (final b in _buffers) {
      b.fillRange(0, b.length, 0);
    }
  }
}

final class _Skip implements Exception {
  const _Skip(this.reason);

  final String reason;
}

/// Turns hosts into engine plans with one unlocked vault; each record is decrypted once.
final class RunPreparation {
  RunPreparation(this._keys, this._secrets, this._profiles, this._store);

  final KeyRepository _keys;
  final SecretRepository _secrets;
  final ProfileRepository _profiles;
  final VaultStore _store;

  Future<PreparedRun> prepare(Vault vault, List<Host> hosts) async {
    final cache = <String, Uint8List>{};
    final plans = <HostPlan>[];
    final skipped = <SkippedHost>[];
    final profiles = {for (final p in await _profiles.all()) p.id: p};

    // Checked on every use; the kind is authenticated data, so vault.get fails if it was altered.
    Future<Uint8List> open(
      String recordId,
      VaultRecordKind kind,
      String what,
    ) async {
      final record = await _store.readRecord(recordId);
      if (record == null || record.kind != kind) {
        throw _Skip('The vault record of $what is missing or of another kind');
      }
      return cache[recordId] ??= await vault.get(recordId);
    }

    Future<Uint8List?> secret(String? id) async {
      final stored = id == null ? null : await _secrets.get(id);
      if (stored == null) return null;
      return open(
        stored.vaultRecordId,
        VaultRecordKind.passphrase,
        'passphrase "${stored.label}"',
      );
    }

    Future<HostPlan> plan(Host host) async {
      final keyId = host.keyId;
      final key = keyId == null ? null : await _keys.get(keyId);
      if (key == null) throw const _Skip('No SSH key assigned');
      final passphrase =
          await secret(host.secretId) ??
          (throw const _Skip('No passphrase assigned'));
      final perDisk = <String, Uint8List>{};
      for (final MapEntry(key: disk, value: id) in host.diskOverrides.entries) {
        perDisk[disk] =
            await secret(id) ??
            (throw _Skip('Passphrase for disk $disk is missing'));
      }
      final pem = await open(
        key.vaultRecordId,
        VaultRecordKind.sshKey,
        'SSH key "${key.label}"',
      );
      return HostPlan(
        host: host,
        privateKeyPem: pem,
        secrets: DiskPassphrases(passphrase, perDisk: perDisk),
        profile: profiles[host.profileId] ?? UnlockProfile.debian,
      );
    }

    try {
      for (final host in hosts) {
        try {
          plans.add(await plan(host));
        } on _Skip catch (s) {
          skipped.add(SkippedHost(host, s.reason));
        }
      }
    } catch (_) {
      PreparedRun(const [], const [], cache.values.toList()).wipe();
      rethrow;
    }
    return PreparedRun(plans, skipped, cache.values.toList());
  }
}
