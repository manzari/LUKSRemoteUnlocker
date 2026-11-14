import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:unlock_core/engine.dart';
import 'package:unlock_core/unlock_core.dart';

import 'config.dart';
import 'passphrase.dart';

const String executableName = 'luks-unlock';
const String cliVersion = '0.1.0';

const int exitUsage = 64;

ArgParser buildParser() => ArgParser()
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.')
  ..addFlag('version', negatable: false, help: 'Print the version.')
  ..addCommand('unlock', unlockParser());

ArgParser unlockParser() => ArgParser()
  ..addOption(
    'config',
    abbr: 'c',
    valueHelp: 'hosts.yaml',
    help: 'YAML file with the hosts (see README).',
  )
  ..addMultiOption(
    'host',
    valueHelp: 'NAME',
    splitCommas: false,
    help: 'Unlock this host; repeat for more.',
  )
  ..addMultiOption(
    'group',
    valueHelp: 'G',
    splitCommas: false,
    help: 'Unlock every enabled host in this group.',
  )
  ..addFlag('all', negatable: false, help: 'Unlock every enabled host.')
  ..addFlag(
    'accept-new-host-key',
    negatable: false,
    help: 'Trust an unpinned pre-boot host key and print it for pinning.',
  )
  ..addOption(
    'passphrase-fd',
    valueHelp: 'N',
    help: 'Read the passphrase byte for byte from this file descriptor.',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

String usage(ArgParser parser) =>
    'Usage: $executableName <command> [options]\n\n'
    'Unlocks LUKS-encrypted servers waiting at the Dropbear pre-boot prompt.\n\n'
    'Commands:\n'
    '  unlock   Unlock hosts from a YAML config\n\n'
    '${parser.usage}';

String unlockUsage() =>
    'Usage: $executableName unlock --config hosts.yaml '
    '(--host NAME ... | --group G | --all) [--accept-new-host-key] [--passphrase-fd N]\n\n'
    'Reads one passphrase from stdin (no echo on a terminal) unless every selected\n'
    'host has a passphrase_file. Exit status: 0 if every host ended Unlocked or\n'
    'Already up, 1 otherwise, 64 on usage or config errors.\n\n'
    '${unlockParser().usage}';

/// Builds the engine; tests swap in fakes.
typedef EngineFactory = UnlockEngine Function(HostKeyPrompt? prompt);

Future<int> runCli(
  List<String> arguments, {
  required StringSink out,
  required StringSink err,
  PassphraseReader? readPassphrase,
  EngineFactory? newEngine,
}) async {
  final parser = buildParser();
  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    err
      ..writeln(e.message)
      ..writeln()
      ..writeln(usage(parser));
    return exitUsage;
  }
  if (results.flag('version')) {
    out.writeln('$executableName $cliVersion (unlock_core $unlockCoreVersion)');
    return 0;
  }
  final command = results.command;
  if (command == null || results.flag('help')) {
    out.writeln(usage(parser));
    return 0;
  }
  return _Unlock(
    command,
    out,
    err,
    readPassphrase ?? const TerminalPassphraseReader(),
    newEngine,
  ).run();
}

final class _UsageError implements Exception {
  const _UsageError(this.message);

  final String message;
}

final class _Unlock {
  _Unlock(this.args, this.out, this.err, this.reader, this.newEngine);

  final ArgResults args;
  final StringSink out;
  final StringSink err;
  final PassphraseReader reader;
  final EngineFactory? newEngine;
  final _secrets = <Uint8List>[];

  Future<int> run() async {
    if (args.flag('help')) {
      out.writeln(unlockUsage());
      return 0;
    }
    final List<HostPlan> plans;
    try {
      plans = _prepare();
    } on _UsageError catch (e) {
      _wipe();
      err
        ..writeln('$executableName: ${e.message}')
        ..writeln("Run '$executableName unlock --help' for usage.");
      return exitUsage;
    } on ConfigException catch (e) {
      _wipe();
      err.writeln('$executableName: $e');
      return exitUsage;
    }
    try {
      return await _run(plans);
    } finally {
      _wipe();
    }
  }

  List<HostPlan> _prepare() {
    if (args.rest.isNotEmpty) {
      throw _UsageError('unexpected argument ${args.rest.first}');
    }
    final path = args.option('config');
    if (path == null) throw const _UsageError('--config is required');
    final names = args.multiOption('host');
    final groups = args.multiOption('group');
    final all = args.flag('all');
    final modes = [names.isNotEmpty, groups.isNotEmpty, all].where((m) => m);
    if (modes.length != 1) {
      throw const _UsageError('choose exactly one of --host, --group or --all');
    }
    final fdText = args.option('passphrase-fd');
    final fd = fdText == null ? null : int.tryParse(fdText);
    if (fdText != null && (fd == null || fd < 0)) {
      throw _UsageError(
        '--passphrase-fd needs a file descriptor number, not $fdText',
      );
    }

    final config = CliConfig.load(path);
    final selected = <CliHost>[];
    if (names.isNotEmpty) {
      for (final n in names) {
        final h = config.hosts.where((h) => h.host.name == n);
        if (h.isEmpty) throw _UsageError('no host named $n in $path');
        if (!selected.contains(h.first)) selected.add(h.first);
      }
    } else {
      selected.addAll(
        config.hosts.where(
          (h) => h.host.enabled && (all || groups.contains(h.host.group)),
        ),
      );
    }
    if (selected.isEmpty) throw const _UsageError('no enabled host selected');

    final keys = {
      for (final h in selected) h.host.name: _readFile(h.keyFile, 'key_file'),
    };
    Uint8List? shared;
    if (selected.any((h) => h.passphraseFile == null)) {
      try {
        shared = _keep(reader.read(fd: fd, prompt: err));
      } on FileSystemException catch (e) {
        throw _UsageError(
          'cannot read the passphrase: ${e.osError?.message ?? e.message}',
        );
      }
      if (shared.isEmpty) throw const _UsageError('the passphrase is empty');
    }
    return [
      for (final h in selected)
        HostPlan(
          host: h.host,
          privateKeyPem: keys[h.host.name]!,
          profile: h.profile,
          secrets: DiskPassphrases(
            h.passphraseFile == null
                ? shared!
                : _secretFile(h.passphraseFile!, 'passphrase_file'),
            perDisk: {
              for (final e in h.diskPassphraseFiles.entries)
                e.key: _secretFile(e.value, 'disk_passphrase_files'),
            },
          ),
        ),
    ];
  }

  Uint8List _readFile(String path, String what) {
    try {
      return _keep(File(path).readAsBytesSync());
    } on FileSystemException catch (e) {
      throw ConfigException('$what $path: ${e.osError?.message ?? e.message}');
    }
  }

  Uint8List _secretFile(String path, String what) {
    final b = _readFile(path, what);
    final s = b.isNotEmpty && b.last == 0x0a
        ? _keep(Uint8List.fromList(b.sublist(0, b.length - 1)))
        : b;
    if (s.isEmpty) throw ConfigException('$what $path is empty');
    return s;
  }

  Uint8List _keep(Uint8List b) {
    _secrets.add(b);
    return b;
  }

  void _wipe() {
    for (final s in _secrets) {
      s.fillRange(0, s.length, 0);
    }
  }

  Future<int> _run(List<HostPlan> plans) async {
    final prompt = args.flag('accept-new-host-key') ? _AcceptPrompt(err) : null;
    final engine =
        newEngine?.call(prompt) ??
        UnlockEngine(
          reachability: const TcpReachability(),
          ssh: const DartSsh2Connector(),
          hostKeyPrompt: prompt,
        );
    final names = {for (final p in plans) p.host.id: p.host.name};
    final finals = <String, HostEvent>{};
    final hints = <String>[];
    StreamSubscription<ProcessSignal>? sigint;
    try {
      sigint = ProcessSignal.sigint.watch().listen((_) {
        err.writeln('$executableName: cancelling');
        engine.cancel();
      });
    } on SignalException {
      sigint = null;
    }
    try {
      await for (final e in engine.run(plans)) {
        final name = names[e.hostId]!;
        final state = e.result?.label ?? e.phase.id;
        out.writeln('[$name] $state: ${e.message}');
        if (e.isFinal) finals[e.hostId] = e;
        if (e.newPrebootKey case final k?) {
          hints.add(
            '$name: accepted pre-boot key; pin it with  preboot_host_key: "$k"',
          );
        }
        if (e.newPostbootKey case final k?) {
          hints.add(
            '$name: post-boot key seen; record it with  postboot_host_key: "$k"',
          );
        }
        if (e.isFinal &&
            e.presentedKey != null &&
            plans.firstWhere((p) => p.host.id == e.hostId).host.prebootKey ==
                null) {
          hints.add(
            '$name: pre-boot key is not pinned; after checking it on the server, add  '
            'preboot_host_key: "${e.presentedKey}"  or run with --accept-new-host-key',
          );
        }
      }
    } finally {
      await sigint?.cancel();
    }

    final nameWidth = [4, ...names.values.map((n) => n.length)].reduce(_max);
    final stateWidth = [
      6,
      ...FinalState.values.map((s) => s.label.length),
    ].reduce(_max);
    out
      ..writeln()
      ..writeln(
        '${'HOST'.padRight(nameWidth)}  ${'RESULT'.padRight(stateWidth)}  DETAIL',
      );
    var ok = true;
    for (final p in plans) {
      final e = finals[p.host.id];
      final state = e?.result ?? FinalState.error;
      ok = ok && state.isSuccess;
      out.writeln(
        '${p.host.name.padRight(nameWidth)}  ${state.label.padRight(stateWidth)}  ${e?.message ?? ''}',
      );
    }
    if (hints.isNotEmpty) {
      out.writeln();
      hints.forEach(out.writeln);
    }
    return ok ? 0 : 1;
  }

  static int _max(int a, int b) => a > b ? a : b;
}

final class _AcceptPrompt implements HostKeyPrompt {
  _AcceptPrompt(this.err);

  final StringSink err;

  @override
  Future<bool> confirm(Host host, HostKey key) async {
    err.writeln('[${host.name}] accepting new pre-boot host key $key');
    return true;
  }
}
