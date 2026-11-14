import 'dart:io';

import 'package:unlock_core/engine.dart';
import 'package:yaml/yaml.dart';

final class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A host from the YAML file plus where its key and secrets live.
final class CliHost {
  const CliHost({
    required this.host,
    required this.keyFile,
    required this.profile,
    this.passphraseFile,
    this.diskPassphraseFiles = const {},
  });

  final Host host;
  final String keyFile;
  final UnlockProfile profile;
  final String? passphraseFile;
  final Map<String, String> diskPassphraseFiles;
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
    'passphrase_file',
    'disk_passphrase_files',
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
    'postboot_check',
    'wait_timeout',
    'boot_timeout',
    'legacy_algorithms',
    'command',
  };

  static CliConfig load(String path) {
    final file = File(path);
    final String text;
    try {
      text = file.readAsStringSync();
    } on FileSystemException catch (e) {
      throw ConfigException('$path: ${e.osError?.message ?? e.message}');
    }
    return parse(text, baseDir: file.absolute.parent.path, source: path);
  }

  static CliConfig parse(
    String text, {
    required String baseDir,
    String source = 'config',
  }) {
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
      final h = {...defaults, ..._map(raw, where)};
      _onlyKeys(_map(raw, where), _hostKeys, where);
      final host = _host(h, where, baseDir);
      if (!names.add(host.host.name)) {
        throw ConfigException('$where: duplicate name ${host.host.name}');
      }
      hosts.add(host);
    }
    return CliConfig(hosts);
  }

  static CliHost _host(Map<String, Object?> h, String where, String baseDir) {
    String? str(String k) {
      final v = h[k];
      if (v == null) return null;
      if (v is String || v is num) return '$v';
      throw ConfigException('$where: $k must be a string');
    }

    bool flag(String k, bool def) {
      final v = h[k] ?? def;
      if (v is! bool) throw ConfigException('$where: $k must be true or false');
      return v;
    }

    T parsed<T>(String k, T Function(String) parse) {
      try {
        return parse(str(k)!);
      } on FormatException catch (e) {
        throw ConfigException('$where: $k: ${e.message} (${e.source})');
      }
    }

    final name = str('name');
    if (name == null || name.trim().isEmpty) {
      throw ConfigException('$where: name is required');
    }
    final at = '$where ($name)';
    final keyFile = str('key_file');
    if (keyFile == null) throw ConfigException('$at: key_file is required');
    final pre = h['preboot'];
    final preList = pre is List ? pre : <Object?>[?pre];
    if (preList.isEmpty) throw ConfigException('$at: preboot is required');
    final List<Endpoint> preboot;
    try {
      preboot = [for (final e in preList) Endpoint.parse('$e')];
    } on FormatException catch (e) {
      throw ConfigException('$at: preboot: ${e.message} (${e.source})');
    }
    final post = h['postboot'] == null
        ? null
        : parsed('postboot', Endpoint.parse);
    final disks = h['disk_passphrase_files'];
    if (disks != null && disks is! Map) {
      throw ConfigException('$at: disk_passphrase_files must be a map');
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
          : parsed('wait_timeout', parseDuration),
      bootTimeout: h['boot_timeout'] == null
          ? const Duration(minutes: 5)
          : parsed('boot_timeout', parseDuration),
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
      keyFile: resolvePath(keyFile, baseDir),
      profile: command == null
          ? UnlockProfile.debian
          : UnlockProfile.debian.copyWith(
              id: 'custom',
              name: 'custom',
              command: command,
              builtIn: false,
            ),
      passphraseFile: str('passphrase_file') == null
          ? null
          : resolvePath(str('passphrase_file')!, baseDir),
      diskPassphraseFiles: {
        for (final e in ((disks as Map?) ?? const {}).entries)
          '${e.key}': resolvePath('${e.value}', baseDir),
      },
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

  static String resolvePath(String p, String baseDir) {
    if (p == '~' || p.startsWith('~/')) {
      final home = Platform.environment['HOME'] ?? '';
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
