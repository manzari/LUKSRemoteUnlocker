import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'endpoint.dart';
import 'host_key.dart';

enum PostBootCheck {
  sshHostKey('ssh-hostkey'),
  tcp('tcp'),
  none('none');

  const PostBootCheck(this.id);

  final String id;

  static PostBootCheck fromId(String id) => values.firstWhere(
    (v) => v.id == id,
    orElse: () => throw FormatException('Unknown post-boot check', id),
  );
}

/// A server to unlock. Ids refer to keys, secrets and profiles stored elsewhere.
@immutable
final class Host {
  Host({
    required this.id,
    required this.name,
    required List<Endpoint> preboot,
    this.group,
    this.user = 'root',
    this.keyId,
    this.secretId,
    Map<String, String> diskOverrides = const {},
    this.profileId,
    this.postbootHost,
    this.postbootPort = 22,
    this.postbootCheck = PostBootCheck.sshHostKey,
    this.waitTimeout = const Duration(minutes: 10),
    this.bootTimeout = const Duration(minutes: 5),
    this.prebootKey,
    this.postbootKey,
    this.legacyAlgorithms = false,
    this.enabled = true,
  }) : preboot = List.unmodifiable(preboot),
       diskOverrides = Map.unmodifiable(diskOverrides) {
    if (preboot.isEmpty) throw ArgumentError('A host needs a pre-boot address');
  }

  final String id;
  final String name;
  final String? group;

  /// Pre-boot SSH addresses, tried in this order.
  final List<Endpoint> preboot;
  final String user;
  final String? keyId;
  final String? secretId;

  /// Disk name to secret id.
  final Map<String, String> diskOverrides;
  final String? profileId;

  /// Defaults to the first pre-boot host.
  final String? postbootHost;
  final int postbootPort;
  final PostBootCheck postbootCheck;
  final Duration waitTimeout;
  final Duration bootTimeout;

  /// Pinned pre-boot (Dropbear) host key.
  final HostKey? prebootKey;

  /// First host key seen on the booted system.
  final HostKey? postbootKey;
  final bool legacyAlgorithms;
  final bool enabled;

  Endpoint get postboot =>
      Endpoint(postbootHost ?? preboot.first.host, postbootPort);

  /// Problems that make the host unusable, empty when valid.
  List<String> validate() => [
    if (name.trim().isEmpty) 'name is empty',
    if (user.trim().isEmpty) 'user is empty',
    if (postbootPort < 1 || postbootPort > 65535) 'post-boot port is invalid',
    // Ports only: Dropbear listens on every address, and two names may be the same machine.
    if (postbootCheck == PostBootCheck.tcp &&
        preboot.any((e) => e.port == postbootPort))
      'the tcp check needs a post-boot port that differs from every pre-boot port',
    if (waitTimeout <= Duration.zero) 'wait timeout must be positive',
    if (bootTimeout <= Duration.zero) 'boot timeout must be positive',
  ];

  /// The clear flags reset a field to null, which passing null cannot.
  Host copyWith({
    String? name,
    String? group,
    List<Endpoint>? preboot,
    String? user,
    String? postbootHost,
    int? postbootPort,
    PostBootCheck? postbootCheck,
    Duration? waitTimeout,
    Duration? bootTimeout,
    HostKey? prebootKey,
    HostKey? postbootKey,
    bool clearPrebootKey = false,
    bool clearPostbootKey = false,
    bool? legacyAlgorithms,
    bool? enabled,
    bool clearGroup = false,
    bool clearPostbootHost = false,
  }) => Host(
    id: id,
    name: name ?? this.name,
    group: clearGroup ? null : group ?? this.group,
    preboot: preboot ?? this.preboot,
    user: user ?? this.user,
    keyId: keyId,
    secretId: secretId,
    diskOverrides: diskOverrides,
    profileId: profileId,
    postbootHost: clearPostbootHost ? null : postbootHost ?? this.postbootHost,
    postbootPort: postbootPort ?? this.postbootPort,
    postbootCheck: postbootCheck ?? this.postbootCheck,
    waitTimeout: waitTimeout ?? this.waitTimeout,
    bootTimeout: bootTimeout ?? this.bootTimeout,
    prebootKey: clearPrebootKey ? null : prebootKey ?? this.prebootKey,
    postbootKey: clearPostbootKey ? null : postbootKey ?? this.postbootKey,
    legacyAlgorithms: legacyAlgorithms ?? this.legacyAlgorithms,
    enabled: enabled ?? this.enabled,
  );

  factory Host.fromJson(Map<String, Object?> json) {
    HostKey? key(Object? v) =>
        v == null ? null : HostKey.fromJson((v as Map).cast<String, Object?>());
    return Host(
      id: json['id']! as String,
      name: json['name']! as String,
      group: json['group'] as String?,
      preboot: [
        for (final e in json['preboot']! as List)
          Endpoint.fromJson((e as Map).cast<String, Object?>()),
      ],
      user: json['user'] as String? ?? 'root',
      keyId: json['keyId'] as String?,
      secretId: json['secretId'] as String?,
      diskOverrides: ((json['diskOverrides'] as Map?) ?? const {})
          .cast<String, String>(),
      profileId: json['profileId'] as String?,
      postbootHost: json['postbootHost'] as String?,
      postbootPort: json['postbootPort'] as int? ?? 22,
      postbootCheck: PostBootCheck.fromId(
        json['postbootCheck'] as String? ?? PostBootCheck.sshHostKey.id,
      ),
      waitTimeout: Duration(seconds: json['waitTimeoutSeconds'] as int? ?? 600),
      bootTimeout: Duration(seconds: json['bootTimeoutSeconds'] as int? ?? 300),
      prebootKey: key(json['prebootKey']),
      postbootKey: key(json['postbootKey']),
      legacyAlgorithms: json['legacyAlgorithms'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'group': group,
    'preboot': [for (final e in preboot) e.toJson()],
    'user': user,
    'keyId': keyId,
    'secretId': secretId,
    'diskOverrides': diskOverrides,
    'profileId': profileId,
    'postbootHost': postbootHost,
    'postbootPort': postbootPort,
    'postbootCheck': postbootCheck.id,
    'waitTimeoutSeconds': waitTimeout.inSeconds,
    'bootTimeoutSeconds': bootTimeout.inSeconds,
    'prebootKey': prebootKey?.toJson(),
    'postbootKey': postbootKey?.toJson(),
    'legacyAlgorithms': legacyAlgorithms,
    'enabled': enabled,
  };

  static const _list = ListEquality<Endpoint>();
  static const _map = MapEquality<String, String>();

  @override
  bool operator ==(Object other) =>
      other is Host &&
      other.id == id &&
      other.name == name &&
      other.group == group &&
      _list.equals(other.preboot, preboot) &&
      other.user == user &&
      other.keyId == keyId &&
      other.secretId == secretId &&
      _map.equals(other.diskOverrides, diskOverrides) &&
      other.profileId == profileId &&
      other.postbootHost == postbootHost &&
      other.postbootPort == postbootPort &&
      other.postbootCheck == postbootCheck &&
      other.waitTimeout == waitTimeout &&
      other.bootTimeout == bootTimeout &&
      other.prebootKey == prebootKey &&
      other.postbootKey == postbootKey &&
      other.legacyAlgorithms == legacyAlgorithms &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    group,
    _list.hash(preboot),
    user,
    keyId,
    secretId,
    _map.hash(diskOverrides),
    profileId,
    postbootHost,
    postbootPort,
    postbootCheck,
    waitTimeout,
    bootTimeout,
    prebootKey,
    postbootKey,
    legacyAlgorithms,
    enabled,
  ]);

  @override
  String toString() => 'Host($name)';
}
