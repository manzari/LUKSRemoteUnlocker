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

/// Turns hosts into engine plans with one unlocked vault; each record is decrypted once.
final class RunPreparation {
  RunPreparation(this._keys, this._secrets, this._profiles);

  final KeyRepository _keys;
  final SecretRepository _secrets;
  final ProfileRepository _profiles;

  Future<PreparedRun> prepare(Vault vault, List<Host> hosts) async {
    final cache = <String, Uint8List>{};
    final plans = <HostPlan>[];
    final skipped = <SkippedHost>[];
    final profiles = {for (final p in await _profiles.all()) p.id: p};

    Future<Uint8List?> secret(String id) async {
      final stored = await _secrets.get(id);
      if (stored == null) return null;
      return cache[stored.vaultRecordId] ??= await vault.get(
        stored.vaultRecordId,
      );
    }

    try {
      for (final host in hosts) {
        final keyId = host.keyId;
        final secretId = host.secretId;
        final key = keyId == null ? null : await _keys.get(keyId);
        if (key == null) {
          skipped.add(SkippedHost(host, 'No SSH key assigned'));
          continue;
        }
        final passphrase = secretId == null ? null : await secret(secretId);
        if (passphrase == null) {
          skipped.add(SkippedHost(host, 'No passphrase assigned'));
          continue;
        }
        final perDisk = <String, Uint8List>{};
        String? missingDisk;
        for (final MapEntry(key: disk, value: id)
            in host.diskOverrides.entries) {
          final bytes = await secret(id);
          if (bytes == null) {
            missingDisk = disk;
            break;
          }
          perDisk[disk] = bytes;
        }
        if (missingDisk != null) {
          skipped.add(
            SkippedHost(host, 'Passphrase for disk $missingDisk is missing'),
          );
          continue;
        }
        final pem = cache[key.vaultRecordId] ??= await vault.get(
          key.vaultRecordId,
        );
        plans.add(
          HostPlan(
            host: host,
            privateKeyPem: pem,
            secrets: DiskPassphrases(passphrase, perDisk: perDisk),
            profile: profiles[host.profileId] ?? UnlockProfile.debian,
          ),
        );
      }
    } catch (_) {
      PreparedRun(const [], const [], cache.values.toList()).wipe();
      rethrow;
    }
    return PreparedRun(plans, skipped, cache.values.toList());
  }
}
