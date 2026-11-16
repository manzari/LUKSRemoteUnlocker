import 'dart:io';

import 'package:unlock_core/engine.dart';
import 'package:yaml/yaml.dart';

import 'vault_files.dart';

final class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A host from the YAML file plus where its key and secrets live: files, stdin or vault labels.
final class CliHost {
  const CliHost({
    required this.host,
    required this.profile,
    this.keyFile,
    this.keyLabel,
    this.passphraseFile,
    this.secretLabel,
    this.diskPassphraseFiles = const {},
    this.diskSecrets = const {},
  });

  final Host host;
  final UnlockProfile profile;

  /// Exactly one of [keyFile] and [keyLabel] is set.
  final String? keyFile;
  final String? keyLabel;
  final String? passphraseFile;
  final String? secretLabel;
  final Map<String, String> diskPassphraseFiles;

  /// Disk name to secret label.
  final Map<String, String> diskSecrets;

  bool get usesVault =>
      keyLabel != null || secretLabel != null || diskSecrets.isNotEmpty;

  /// The default passphrase comes from stdin or --passphrase-fd.
  bool get usesStdin => passphraseFile == null && secretLabel == null;
}

final class CliConfig {
  const CliConfig(this.hosts);

  final List<CliHost> hosts;

  static const _hostKeys = {
    'name',
    'group',
    'preboot',
    'user',
    'key_file',
    'key',
    'passphrase_file',
    'secret',
    'disk_passphrase_files',
    'disk_secrets',
    'postboot',
    'postboot_check',
    'preboot_host_key',
    'postboot_host_key',
    'wait_timeout',
    'boot_timeout',
    'legacy_algorithms',
    'enabled',
    'command',
  };
  static const _defaultKeys = {
    'user',
    'key_file',
    'key',
    'postboot_check',
    'wait_timeout',
    'boot_timeout',
    'legacy_algorithms',
    'command',
  };

  /// [environment] supplies HOME for `~/` paths (default: the process environment).
  static CliConfig load(String path, {Map<String, String>? environment}) {
    final file = File(path);
    final String text;
    try {
      text = file.readAsStringSync();
    } on FileSystemException catch (e) {
      throw ConfigException('$path: ${e.osError?.message ?? e.message}');
    }
    return parse(
      text,
      baseDir: file.absolute.parent.path,
      source: path,
      environment: environment,
    );
  }

  static CliConfig parse(
    String text, {
    required String baseDir,
    String source = 'config',
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final Object? doc;
    try {
      doc = loadYaml(text);
    } on YamlException catch (e) {
      throw ConfigException('$source: ${e.message}');
    }
    final root = _map(doc, source);
    _onlyKeys(root, const {'defaults', 'hosts'}, source);
    final defaults = root['defaults'] == null
        ? const <String, Object?>{}
        : _map(root['defaults'], '$source: defaults');
    _onlyKeys(defaults, _defaultKeys, '$source: defaults');
    final list = root['hosts'];
    if (list is! List || list.isEmpty) {
      throw ConfigException('$source: "hosts" must be a non-empty list');
    }
    final hosts = <CliHost>[];
    final names = <String>{};
    for (final (i, raw) in list.indexed) {
      final where = '$source: hosts[$i]';
      final own = _map(raw, where);
      _onlyKeys(own, _hostKeys, where);
      final h = {...defaults, ...own};
      // A key source set on the host replaces the one from defaults.
      if (own.containsKey('key') || own.containsKey('key_file')) {
        if (!own.containsKey('key')) h.remove('key');
        if (!own.containsKey('key_file')) h.remove('key_file');
      }
      final host = _host(h, where, baseDir, env);
      if (!names.add(host.host.name)) {
        throw ConfigException('$where: duplicate name ${host.host.name}');
      }
      hosts.add(host);
    }
    return CliConfig(hosts);
  }

  static CliHost _host(
    Map<String, Object?> h,
    String where,
    String baseDir,
    Map<String, String> env,
  ) {
    ConfigException notString(String k, Object v) => ConfigException(
      '$where: $k must be a string${v is num || v is bool ? ' (quote it)' : ''}',
    );

    // [number]: a whole number is accepted too, for durations.
    String? str(String k, {bool number = false}) {
      final v = h[k];
      if (v == null) return null;
      if (v is String) return v;
      if (number && v is int) return '$v';
      throw notString(k, v);
    }

    bool flag(String k, bool def) {
      final v = h[k] ?? def;
      if (v is! bool) throw ConfigException('$where: $k must be true or false');
      return v;
    }

    T parsed<T>(String k, T Function(String) parse, {bool number = false}) {
      try {
        return parse(str(k, number: number)!);
      } on FormatException catch (e) {
        throw ConfigException('$where: $k: ${e.message} (${e.source})');
      }
    }

    String path(String k, String p) {
      try {
        return resolvePath(p, baseDir, environment: env);
      } on FormatException catch (e) {
        throw ConfigException('$where: $k: ${e.message} (${e.source})');
      }
    }

    final name = str('name');
    if (name == null || name.trim().isEmpty) {
      throw ConfigException('$where: name is required');
    }
    final at = '$where ($name)';
    String? label(String k) {
      final v = str(k);
      if (v != null && !labelPattern.hasMatch(v)) {
        throw ConfigException('$at: $k: invalid label "$v"');
      }
      return v;
    }

    final keyFile = str('key_file');
    final keyLabel = label('key');
    if ((keyFile == null) == (keyLabel == null)) {
      throw ConfigException(
        keyFile == null
            ? '$at: key_file or key is required'
            : '$at: use either key_file or key, not both',
      );
    }
    final passphraseFile = str('passphrase_file');
    final secretLabel = label('secret');
    if (passphraseFile != null && secretLabel != null) {
      throw ConfigException(
        '$at: use either passphrase_file or secret, not both',
      );
    }
    final pre = h['preboot'];
    final preList = pre is List ? pre : <Object?>[?pre];
    if (preList.isEmpty) throw ConfigException('$at: preboot is required');
    final preboot = <Endpoint>[];
    for (final e in preList) {
      if (e is! String) {
        throw ConfigException(
          '$at: preboot: ${e == null ? 'empty entry' : '$e is not a string'}; '
          'use host or host:port',
        );
      }
      try {
        preboot.add(Endpoint.parse(e));
      } on FormatException catch (f) {
        throw ConfigException('$at: preboot: ${f.message} (${f.source})');
      }
    }
    final post = h['postboot'] == null
        ? null
        : parsed('postboot', Endpoint.parse);
    Map<String, String> disks(String k) {
      final v = h[k];
      if (v == null) return const {};
      if (v is! Map) throw ConfigException('$at: $k must be a map');
      final out = <String, String>{};
      for (final MapEntry(:key, :value) in v.entries) {
        if (key is! String) {
          throw ConfigException('$at: $k: disk name $key must be a string');
        }
        if (value is! String) {
          throw ConfigException(
            '$at: $k: $key must be a string, not ${value ?? 'empty'}',
          );
        }
        out[key] = value;
      }
      return out;
    }

    final diskFiles = disks('disk_passphrase_files');
    final diskSecrets = disks('disk_secrets');
    for (final e in diskSecrets.entries) {
      if (diskFiles.containsKey(e.key)) {
        throw ConfigException(
          '$at: disk ${e.key} is in both disk_passphrase_files and disk_secrets',
        );
      }
      if (!labelPattern.hasMatch(e.value)) {
        throw ConfigException('$at: disk_secrets: invalid label "${e.value}"');
      }
    }
    final command = str('command');

    final host = Host(
      id: name,
      name: name,
      group: str('group'),
      preboot: preboot,
      user: str('user') ?? 'root',
      postbootHost: post?.host,
      postbootPort: post?.port ?? 22,
      postbootCheck: h['postboot_check'] == null
          ? PostBootCheck.sshHostKey
          : parsed('postboot_check', PostBootCheck.fromId),
      waitTimeout: h['wait_timeout'] == null
          ? const Duration(minutes: 10)
          : parsed('wait_timeout', parseDuration, number: true),
      bootTimeout: h['boot_timeout'] == null
          ? const Duration(minutes: 5)
          : parsed('boot_timeout', parseDuration, number: true),
      prebootKey: h['preboot_host_key'] == null
          ? null
          : parsed('preboot_host_key', HostKey.parse),
      postbootKey: h['postboot_host_key'] == null
          ? null
          : parsed('postboot_host_key', HostKey.parse),
      legacyAlgorithms: flag('legacy_algorithms', false),
      enabled: flag('enabled', true),
    );
    final problems = host.validate();
    if (problems.isNotEmpty) {
      throw ConfigException('$at: ${problems.join('; ')}');
    }
    return CliHost(
      host: host,
      keyFile: keyFile == null ? null : path('key_file', keyFile),
      keyLabel: keyLabel,
      profile: command == null
          ? UnlockProfile.debian
          : UnlockProfile.debian.copyWith(
              id: 'custom',
              name: 'custom',
              command: command,
              builtIn: false,
            ),
      passphraseFile: passphraseFile == null
          ? null
          : path('passphrase_file', passphraseFile),
      secretLabel: secretLabel,
      diskPassphraseFiles: {
        for (final e in diskFiles.entries)
          e.key: path('disk_passphrase_files: ${e.key}', e.value),
      },
      diskSecrets: diskSecrets,
    );
  }

  /// `90`, `90s`, `10m` or `1h`.
  static Duration parseDuration(String s) {
    final m = RegExp(r'^\s*(\d+)\s*([smh]?)\s*$').firstMatch(s);
    if (m == null) throw FormatException('expected seconds or 30s/10m/1h', s);
    final n = int.parse(m[1]!);
    final d = switch (m[2]) {
      'm' => Duration(minutes: n),
      'h' => Duration(hours: n),
      _ => Duration(seconds: n),
    };
    if (d <= Duration.zero) throw FormatException('must be positive', s);
    return d;
  }

  /// Throws a [FormatException] for `~` when HOME is unset or empty.
  static String resolvePath(
    String p,
    String baseDir, {
    Map<String, String>? environment,
  }) {
    if (p.isEmpty) throw FormatException('empty path', p);
    if (p == '~' || p.startsWith('~/')) {
      final home = (environment ?? Platform.environment)['HOME'] ?? '';
      if (home.isEmpty) throw FormatException('HOME is not set', p);
      return '$home${p.substring(1)}';
    }
    if (p.startsWith('/')) return p;
    return '$baseDir/$p';
  }

  static Map<String, Object?> _map(Object? v, String where) {
    if (v is! Map) throw ConfigException('$where: expected a mapping');
    return {for (final e in v.entries) '${e.key}': e.value};
  }

  static void _onlyKeys(
    Map<String, Object?> m,
    Set<String> keys,
    String where,
  ) {
    for (final k in m.keys) {
      if (!keys.contains(k)) throw ConfigException('$where: unknown key "$k"');
    }
  }
}
