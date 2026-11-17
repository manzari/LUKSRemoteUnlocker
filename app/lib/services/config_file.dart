import 'dart:convert';
import 'dart:typed_data';

import 'package:unlock_core/unlock_core.dart';

const String configFormat = 'luks-remote-unlocker-config';
const int configFormatVersion = 1;

/// Exports are a few KiB; anything larger is refused before parsing.
const int maxConfigFileBytes = 1024 * 1024;

const int maxConfigHosts = 1000;
const int maxConfigProfiles = 100;
const int _maxEndpoints = 32;
const int _maxDisks = 32;
const int _maxText = 1024;
const int _maxLongText = 8192;
const int _maxTimeoutSeconds = 366 * 24 * 3600;

final _controlChars = RegExp(r'[\u0000-\u001f\u007f]');
final _whitespace = RegExp(r'\s');

/// Public parts of the SSH key a host used; relinked by fingerprint on import.
final class KeyReference {
  const KeyReference({
    required this.label,
    required this.type,
    required this.publicLine,
    required this.fingerprint,
  });

  final String label;
  final String type;
  final String publicLine;
  final String fingerprint;

  Map<String, Object?> toJson() => {
    'label': label,
    'type': type,
    'publicKey': publicLine,
    'fingerprint': fingerprint,
  };
}

/// A host in an export. [host] carries every plain field; its id and reference ids are unset.
final class ConfigHost {
  ConfigHost({
    required this.host,
    this.key,
    this.passphrase,
    Map<String, String> diskPassphrases = const {},
    this.profileRef,
  }) : diskPassphrases = Map.unmodifiable(diskPassphrases);

  final Host host;
  final KeyReference? key;

  /// Passphrase labels; the passphrases themselves are never exported.
  final String? passphrase;
  final Map<String, String> diskPassphrases;

  /// A built-in profile id or the ref of a profile in the same file.
  final String? profileRef;

  Map<String, Object?> toJson() => {
    'name': host.name,
    'group': host.group,
    'preboot': [for (final e in host.preboot) e.toJson()],
    'user': host.user,
    'sshKey': key?.toJson(),
    'passphrase': passphrase == null ? null : {'label': passphrase},
    'diskPassphrases': {
      for (final MapEntry(key: disk, value: label) in diskPassphrases.entries)
        disk: {'label': label},
    },
    'profile': profileRef,
    'postbootHost': host.postbootHost,
    'postbootPort': host.postbootPort,
    'postbootCheck': host.postbootCheck.id,
    'waitTimeoutSeconds': host.waitTimeout.inSeconds,
    'bootTimeoutSeconds': host.bootTimeout.inSeconds,
    'prebootKey': host.prebootKey?.toJson(),
    'postbootKey': host.postbootKey?.toJson(),
    'legacyAlgorithms': host.legacyAlgorithms,
    'enabled': host.enabled,
  };
}

/// The non-secret configuration: hosts and custom profiles (profile ids are file refs).
final class ConfigFile {
  ConfigFile({
    required this.exportedAt,
    required List<UnlockProfile> profiles,
    required List<ConfigHost> hosts,
  }) : profiles = List.unmodifiable(profiles),
       hosts = List.unmodifiable(hosts);

  final DateTime exportedAt;
  final List<UnlockProfile> profiles;
  final List<ConfigHost> hosts;

  Map<String, Object?> toJson() => {
    'format': configFormat,
    'version': configFormatVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'profiles': [
      for (final p in profiles)
        {
          'ref': p.id,
          'name': p.name,
          'driver': p.driver.id,
          'command': p.command,
          'promptRegex': p.promptRegex,
          'successRegex': p.successRegex,
          'failureRegex': p.failureRegex,
        },
    ],
    'hosts': [for (final h in hosts) h.toJson()],
  };

  Uint8List encode() =>
      utf8.encode('${const JsonEncoder.withIndent('  ').convert(toJson())}\n');

  /// Strict: any problem throws a [FormatException] with a message fit for the UI.
  static ConfigFile decode(Uint8List bytes) {
    if (bytes.length > maxConfigFileBytes) {
      throw const FormatException(
        'The file is too large to be a configuration export.',
      );
    }
    Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on Object {
      throw const FormatException(
        'The file is not a configuration export (it is not JSON).',
      );
    }
    try {
      return _read(json);
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException(
        'The file is not a valid configuration export.',
      );
    }
  }
}

Never _fail(String where, String problem) =>
    throw FormatException('Not a valid configuration export: $where $problem.');

ConfigFile _read(Object? json) {
  if (json is! Map<String, Object?> || json['format'] != configFormat) {
    throw const FormatException(
      'The file is not a configuration export of this app.',
    );
  }
  final version = json['version'];
  if (version is! int) _fail('the format version', 'is not a whole number');
  if (version > configFormatVersion) {
    throw FormatException(
      'The file was made by a newer version of the app (format $version). '
      'Update the app to import it.',
    );
  }
  if (version != configFormatVersion) {
    _fail('the format version $version', 'is not supported');
  }
  final root = _Obj(json, 'the file', const {
    'format',
    'version',
    'exportedAt',
    'profiles',
    'hosts',
  });
  final exportedAt = DateTime.tryParse(root.text('exportedAt'));
  if (exportedAt == null) _fail('exportedAt', 'is not a date');

  final profiles = <UnlockProfile>[];
  final refs = <String>{};
  final builtInIds = {for (final p in UnlockProfile.builtIns) p.id};
  for (final (i, item) in root.list('profiles', maxConfigProfiles).indexed) {
    final p = _readProfile(_Obj(item, 'profiles[$i]', _profileFields));
    if (builtInIds.contains(p.id)) {
      _fail('profiles[$i], ref', 'names a built-in profile');
    }
    if (!refs.add(p.id)) _fail('profiles[$i], ref', 'is used twice');
    profiles.add(p);
  }
  final hosts = [
    for (final (i, item) in root.list('hosts', maxConfigHosts).indexed)
      _readHost(_Obj(item, 'hosts[$i]', _hostFields)),
  ];
  return ConfigFile(exportedAt: exportedAt, profiles: profiles, hosts: hosts);
}

const _profileFields = {
  'ref',
  'name',
  'driver',
  'command',
  'promptRegex',
  'successRegex',
  'failureRegex',
};

UnlockProfile _readProfile(_Obj o) {
  final driverId = o.text('driver');
  final driver = UnlockDriverKind.values
      .where((d) => d.id == driverId)
      .firstOrNull;
  if (driver == null) o.fail('driver', 'is not a known driver');
  return UnlockProfile(
    id: o.text('ref'),
    name: o.text('name'),
    driver: driver,
    command: o.text('command', max: _maxLongText),
    promptRegex: o.optionalText('promptRegex', max: _maxLongText),
    successRegex: o.optionalText('successRegex', max: _maxLongText),
    failureRegex: o.optionalText('failureRegex', max: _maxLongText),
  );
}

const _hostFields = {
  'name',
  'group',
  'preboot',
  'user',
  'sshKey',
  'passphrase',
  'diskPassphrases',
  'profile',
  'postbootHost',
  'postbootPort',
  'postbootCheck',
  'waitTimeoutSeconds',
  'bootTimeoutSeconds',
  'prebootKey',
  'postbootKey',
  'legacyAlgorithms',
  'enabled',
};

ConfigHost _readHost(_Obj raw) {
  final name = raw.text('name');
  final o = raw.renamed('host "$name"');
  final preboot = [
    for (final (i, item) in o.list('preboot', _maxEndpoints).indexed)
      _readEndpoint(
        _Obj(item, '${o.where}, preboot[$i]', const {'host', 'port'}),
      ),
  ];
  if (preboot.isEmpty) o.fail('preboot', 'needs at least one address');
  final checkId = o.text('postbootCheck');
  final check = PostBootCheck.values.where((c) => c.id == checkId).firstOrNull;
  if (check == null) o.fail('postbootCheck', 'is not a known check');

  final disks = <String, String>{};
  final diskMap = o.map('diskPassphrases', _maxDisks);
  for (final MapEntry(:key, :value) in diskMap.entries) {
    final disk = _checkText(key, '${o.where}, diskPassphrases', 'a disk name');
    if (disks.containsKey(disk)) {
      o.fail('diskPassphrases', 'lists "$disk" twice');
    }
    disks[disk] = _label(value, '${o.where}, diskPassphrases.$disk');
  }

  final host = Host(
    id: '',
    name: name,
    group: o.optionalText('group'),
    preboot: preboot,
    user: o.text('user'),
    postbootHost: o.optionalText('postbootHost'),
    postbootPort: o.integer('postbootPort', 1, 65535, 'a port from 1 to 65535'),
    postbootCheck: check,
    waitTimeout: Duration(seconds: o.timeout('waitTimeoutSeconds')),
    bootTimeout: Duration(seconds: o.timeout('bootTimeoutSeconds')),
    prebootKey: o.hostKey('prebootKey'),
    postbootKey: o.hostKey('postbootKey'),
    legacyAlgorithms: o.boolean('legacyAlgorithms'),
    enabled: o.boolean('enabled'),
  );
  final problems = host.validate();
  if (problems.isNotEmpty) _fail('${o.where}:', problems.join('; '));

  final passphrase = o.value('passphrase');
  return ConfigHost(
    host: host,
    key: _readKey(o.value('sshKey'), '${o.where}, sshKey'),
    passphrase: passphrase == null
        ? null
        : _label(passphrase, '${o.where}, passphrase'),
    diskPassphrases: disks,
    profileRef: o.optionalText('profile'),
  );
}

Endpoint _readEndpoint(_Obj o) => Endpoint(
  o.text('host'),
  o.integer('port', 1, 65535, 'a port from 1 to 65535'),
);

String _label(Object? value, String where) =>
    _Obj(value, where, const {'label'}).text('label');

KeyReference? _readKey(Object? value, String where) {
  if (value == null) return null;
  final o = _Obj(value, where, const {
    'label',
    'type',
    'publicKey',
    'fingerprint',
  });
  final type = o.text('type');
  final line = o.text('publicKey', max: _maxLongText);
  final fingerprint = o.text('fingerprint');
  final parts = line.split(RegExp(r'\s+'));
  Uint8List? blob;
  try {
    blob = parts.length < 2 ? null : base64.decode(parts[1]);
  } on FormatException {
    blob = null;
  }
  if (blob == null || parts[0] != type) {
    o.fail('publicKey', 'is not a "$type" public key line');
  }
  if (sshFingerprint(blob) != fingerprint) {
    o.fail('fingerprint', 'does not match the public key');
  }
  return KeyReference(
    label: o.text('label'),
    type: type,
    publicLine: line,
    fingerprint: fingerprint,
  );
}

String _checkText(Object? v, String where, String what, {int max = _maxText}) {
  if (v is! String) _fail(where, 'must be text');
  final text = v.trim();
  if (text.isEmpty) _fail(where, 'needs $what');
  if (v.length > max) _fail(where, 'is too long');
  if (_controlChars.hasMatch(v)) _fail(where, 'contains control characters');
  return text;
}

/// A JSON object with exactly the given fields; [where] names it in error messages.
final class _Obj {
  _Obj(Object? value, this.where, Set<String> fields)
    : _map = value is Map<String, Object?>
          ? value
          : _fail(where, 'must be an object') {
    for (final key in _map.keys) {
      if (!fields.contains(key)) _fail(where, 'has an unknown field "$key"');
    }
    for (final key in fields) {
      if (!_map.containsKey(key)) _fail(where, 'lacks the field "$key"');
    }
  }

  _Obj._renamed(this._map, this.where);

  final Map<String, Object?> _map;
  final String where;

  _Obj renamed(String where) => _Obj._renamed(_map, where);

  Never fail(String field, String problem) => _fail('$where, $field', problem);

  Object? value(String field) => _map[field];

  String text(String field, {int max = _maxText}) =>
      _checkText(_map[field], '$where, $field', 'a value', max: max);

  /// Null when null or blank.
  String? optionalText(String field, {int max = _maxText}) {
    final v = _map[field];
    if (v == null || (v is String && v.trim().isEmpty)) return null;
    return text(field, max: max);
  }

  int integer(String field, int min, int max, String what) {
    final v = _map[field];
    if (v is! int || v < min || v > max) fail(field, 'must be $what');
    return v;
  }

  int timeout(String field) =>
      integer(field, 1, _maxTimeoutSeconds, 'a positive number of seconds');

  bool boolean(String field) {
    final v = _map[field];
    if (v is! bool) fail(field, 'must be true or false');
    return v;
  }

  List<Object?> list(String field, int maxLength) {
    final v = _map[field];
    if (v is! List<Object?>) fail(field, 'must be a list');
    if (v.length > maxLength) fail(field, 'has more than $maxLength entries');
    return v;
  }

  Map<String, Object?> map(String field, int maxLength) {
    final v = _map[field];
    if (v is! Map<String, Object?>) fail(field, 'must be an object');
    if (v.length > maxLength) fail(field, 'has more than $maxLength entries');
    return v;
  }

  HostKey? hostKey(String field) {
    final v = _map[field];
    if (v == null) return null;
    final o = _Obj(v, '$where, $field', const {'type', 'fingerprint'});
    final type = o.optionalText('type');
    if (type != null && _whitespace.hasMatch(type)) {
      o.fail('type', 'must be one word');
    }
    final fingerprint = o.text('fingerprint');
    try {
      return HostKey(type, fingerprint);
    } on FormatException {
      o.fail('fingerprint', 'is not a SHA256 fingerprint');
    }
  }
}
