import '../model/unlock_profile.dart';
import 'clock.dart';
import 'ports.dart';

abstract interface class RunLog {
  /// Records a message; the implementation redacts secrets again.
  void log(String message);
}

final class DriverTimings {
  const DriverTimings({
    this.execTimeout = const Duration(seconds: 30),
    this.notReadyDelay = const Duration(seconds: 2),
    this.notReadyMax = const Duration(seconds: 60),
    this.maxRounds = 8,
  });

  final Duration execTimeout;
  final Duration notReadyDelay;
  final Duration notReadyMax;
  final int maxRounds;
}

final class DriverContext {
  DriverContext({
    required this.connection,
    required this.reconnect,
    required this.profile,
    required this.secrets,
    required this.log,
    required this.control,
    this.timings = const DriverTimings(),
  });

  /// Logged-in connection to the pre-boot server.
  final SshConnection connection;

  /// Connects and logs in again with the same host-key policy; throws [SshFailure].
  final Future<SshConnection> Function() reconnect;
  final UnlockProfile profile;
  final SecretResolver secrets;
  final RunLog log;
  final RunControl control;
  final DriverTimings timings;
}

/// Step 5 of the flow: runs the unlock command until no disk is left.
abstract interface class UnlockDriver {
  /// Throws [SshFailure] only for a reconnect that fails before any disk was unlocked.
  Future<DriverResult> run(DriverContext context);
}

sealed class DriverResult {
  const DriverResult(this.unlockedDisks);

  final List<String> unlockedDisks;
}

/// No disk is waiting any more, or the server went away after an unlock: wait for boot.
final class DriverUnlocked extends DriverResult {
  const DriverUnlocked(super.unlockedDisks, this.note);

  final String note;
}

/// The connection dropped after a passphrase was written, before a result.
final class DriverLostAfterPassphrase extends DriverResult {
  const DriverLostAfterPassphrase(super.unlockedDisks, this.disk);

  final String disk;
}

final class DriverWrongPassphrase extends DriverResult {
  const DriverWrongPassphrase(super.unlockedDisks, this.message);

  final String message;
}

final class DriverError extends DriverResult {
  const DriverError(super.unlockedDisks, this.message);

  final String message;
}
