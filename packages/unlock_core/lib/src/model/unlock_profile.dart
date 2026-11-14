import 'package:meta/meta.dart';

enum UnlockDriverKind {
  stdin('stdin'),
  pty('pty');

  const UnlockDriverKind(this.id);

  final String id;

  static UnlockDriverKind fromId(String id) => values.firstWhere(
    (v) => v.id == id,
    orElse: () => throw FormatException('Unknown driver', id),
  );
}

/// How to run the unlock on the pre-boot server.
@immutable
final class UnlockProfile {
  const UnlockProfile({
    required this.id,
    required this.name,
    required this.command,
    this.driver = UnlockDriverKind.stdin,
    this.builtIn = false,
    this.promptRegex,
    this.successRegex,
    this.failureRegex,
  });

  /// Debian/Ubuntu `dropbear-initramfs` with `cryptroot-unlock`.
  static const debian = UnlockProfile(
    id: 'debian-cryptroot-unlock',
    name: 'Debian/Ubuntu cryptroot-unlock',
    command: 'cryptroot-unlock',
    builtIn: true,
  );

  static const builtIns = [debian];

  final String id;
  final String name;
  final bool builtIn;
  final UnlockDriverKind driver;
  final String command;

  // pty driver only (after v1)
  final String? promptRegex;
  final String? successRegex;
  final String? failureRegex;

  UnlockProfile copyWith({
    String? id,
    String? name,
    String? command,
    bool? builtIn,
  }) => UnlockProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    command: command ?? this.command,
    driver: driver,
    builtIn: builtIn ?? this.builtIn,
    promptRegex: promptRegex,
    successRegex: successRegex,
    failureRegex: failureRegex,
  );

  factory UnlockProfile.fromJson(Map<String, Object?> json) => UnlockProfile(
    id: json['id']! as String,
    name: json['name']! as String,
    command: json['command']! as String,
    driver: UnlockDriverKind.fromId(json['driver'] as String? ?? 'stdin'),
    builtIn: json['builtIn'] as bool? ?? false,
    promptRegex: json['promptRegex'] as String?,
    successRegex: json['successRegex'] as String?,
    failureRegex: json['failureRegex'] as String?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'builtIn': builtIn,
    'driver': driver.id,
    'command': command,
    'promptRegex': promptRegex,
    'successRegex': successRegex,
    'failureRegex': failureRegex,
  };

  @override
  bool operator ==(Object other) =>
      other is UnlockProfile &&
      other.id == id &&
      other.name == name &&
      other.builtIn == builtIn &&
      other.driver == driver &&
      other.command == command &&
      other.promptRegex == promptRegex &&
      other.successRegex == successRegex &&
      other.failureRegex == failureRegex;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    builtIn,
    driver,
    command,
    promptRegex,
    successRegex,
    failureRegex,
  );
}
