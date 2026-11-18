import 'package:meta/meta.dart';

import 'host_key.dart';

/// Where a host is in the unlock flow.
enum HostPhase {
  checkingIfUp('checking-if-up'),
  pinging('pinging'),
  waitingForPreboot('waiting-for-preboot'),
  verifyingHostKey('verifying-host-key'),
  authenticating('authenticating'),
  unlocking('unlocking'),
  waitingForBoot('waiting-for-boot'),
  finished('finished');

  const HostPhase(this.id);

  final String id;

  static HostPhase fromId(String id) => values.firstWhere(
    (v) => v.id == id,
    orElse: () => throw FormatException('Unknown phase', id),
  );
}

enum FinalState {
  unlocked('unlocked', 'Unlocked'),
  alreadyUp('already-up', 'Already up'),
  unlockedBootNotConfirmed(
    'unlocked-boot-not-confirmed',
    'Unlocked, boot not confirmed',
  ),
  wrongPassphrase('wrong-passphrase', 'Wrong passphrase'),
  hostKeyMismatch('host-key-mismatch', 'Host key mismatch'),
  authFailed('auth-failed', 'Auth failed'),
  prebootTimeout('preboot-timeout', 'Pre-boot timeout'),
  cancelled('cancelled', 'Cancelled'),
  error('error', 'Error');

  const FinalState(this.id, this.label);

  final String id;
  final String label;

  bool get isSuccess => this == unlocked || this == alreadyUp;

  static FinalState fromId(String id) => values.firstWhere(
    (v) => v.id == id,
    orElse: () => throw FormatException('Unknown final state', id),
  );
}

/// One log entry of a host's run. [message] never contains a run secret.
@immutable
final class HostEvent {
  const HostEvent({
    required this.hostId,
    required this.time,
    required this.phase,
    required this.message,
    this.result,
    this.newPrebootKey,
    this.newPostbootKey,
    this.presentedKey,
  });

  final String hostId;
  final DateTime time;
  final HostPhase phase;
  final String message;

  /// Set on the last event of a host.
  final FinalState? result;

  /// A pre-boot key the user accepted in this run; persist it as pinned.
  final HostKey? newPrebootKey;

  /// The first key seen on the booted system; persist it as the post-boot key.
  final HostKey? newPostbootKey;

  /// The key a server presented when it was refused (mismatch or unpinned).
  final HostKey? presentedKey;

  bool get isFinal => result != null;

  factory HostEvent.fromJson(Map<String, Object?> json) {
    HostKey? key(Object? v) =>
        v == null ? null : HostKey.fromJson((v as Map).cast<String, Object?>());
    final result = json['result'] as String?;
    return HostEvent(
      hostId: json['hostId']! as String,
      time: DateTime.parse(json['time']! as String),
      phase: HostPhase.fromId(json['phase']! as String),
      message: json['message']! as String,
      result: result == null ? null : FinalState.fromId(result),
      newPrebootKey: key(json['newPrebootKey']),
      newPostbootKey: key(json['newPostbootKey']),
      presentedKey: key(json['presentedKey']),
    );
  }

  Map<String, Object?> toJson() => {
    'hostId': hostId,
    'time': time.toUtc().toIso8601String(),
    'phase': phase.id,
    'message': message,
    'result': result?.id,
    'newPrebootKey': newPrebootKey?.toJson(),
    'newPostbootKey': newPostbootKey?.toJson(),
    'presentedKey': presentedKey?.toJson(),
  };

  @override
  String toString() =>
      '[$hostId] ${result?.label ?? phase.id}${message.isEmpty ? '' : ': $message'}';
}
