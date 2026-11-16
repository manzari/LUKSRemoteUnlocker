import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:unlock_core/unlock_core.dart';

import 'common.dart';
import 'config.dart';
import 'passphrase.dart';
import 'vault_commands.dart';
import 'vault_files.dart';

ArgParser buildParser() {
  final p = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.')
    ..addFlag('version', negatable: false, help: 'Print the version.')
    ..addCommand('unlock', unlockParser());
  for (final g in vaultGroups) {
    p.addCommand(g, groupParser(g));
  }
  return p;
}

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
  ..addOption(
    'vault',
    valueHelp: 'PATH',
    help: 'Vault for key: and secret: labels (default as for vault commands).',
  )
  ..addOption(
    'password-fd',
    valueHelp: 'N',
    help: 'Read the vault password byte for byte from this file descriptor.',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

String usage(ArgParser parser) =>
    'Usage: $executableName <command> [options]\n\n'
    'Unlocks LUKS-encrypted servers waiting at the Dropbear pre-boot prompt.\n\n'
    'Commands:\n'
    '  unlock   Unlock hosts from a YAML config\n'
    '  vault    Create the vault, show its status, change its password\n'
    '  key      Generate, import, list, show and remove SSH login keys\n'
    '  secret   Add, list and remove LUKS passphrases\n\n'
    '${parser.usage}';

String unlockUsage() =>
    'Usage: $executableName unlock --config hosts.yaml '
    '(--host NAME ... | --group G | --all) [--accept-new-host-key] [--passphrase-fd N]\n'
    '       [--vault PATH] [--password-fd N]\n\n'
    'Reads one passphrase from stdin (no echo on a terminal) unless every selected\n'
    'host has a passphrase_file or secret. Hosts with key: or secret: labels unlock the\n'
    'vault first (one password prompt). Exit status: 0 if every host ended Unlocked or\n'
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
  SecretInput? input,
  VaultTuning tuning = const VaultTuning(),
  Map<String, String>? environment,
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
  final vaults = VaultCli(
    out: out,
    err: err,
    input: input ?? const TerminalSecretInput(),
    environment: environment ?? Platform.environment,
    tuning: tuning,
  );
  if (command.name != 'unlock') return vaults.run(command);
  return _Unlock(
    command,
    out,
    err,
    readPassphrase ?? const TerminalPassphraseReader(),
    newEngine,
    vaults,
  ).run();
}

final class _Unlock {
  _Unlock(
    this.args,
    this.out,
    this.err,
    this.reader,
    this.newEngine,
    this.vaults,
  );

  static const _help = 'unlock';

  final ArgResults args;
  final StringSink out;
  final StringSink err;
  final PassphraseReader reader;
  final EngineFactory? newEngine;
  final VaultCli vaults;
  final _secrets = <Uint8List>[];

  Future<int> run() async {
    if (args.flag('help')) {
      out.writeln(unlockUsage());
      return 0;
    }
    final List<HostPlan> plans;
    try {
      plans = await _prepare();
    } on CliExit catch (e) {
      _wipe();
      e.report(err);
      return e.code;
    } on ConfigException catch (e) {
      _wipe();
      err.writeln('$executableName: ${terminalSafe('$e')}');
      return exitUsage;
    } on VaultException catch (e) {
      _wipe();
      err.writeln('$executableName: vault: ${terminalSafe(e.message)}');
      return exitFailure;
    } on FileSystemException catch (e) {
      _wipe();
      err.writeln(
        '$executableName: ${terminalSafe('${e.path ?? e.message}: ${osMessage(e)}')}',
      );
      return exitFailure;
    } catch (_) {
      _wipe();
      rethrow;
    }
    try {
      return await _run(plans);
    } finally {
      _wipe();
    }
  }

  Future<List<HostPlan>> _prepare() async {
    if (args.rest.isNotEmpty) {
      throw CliExit.usage('unexpected argument ${args.rest.first}', _help);
    }
    final path = args.option('config');
    if (path == null) throw const CliExit.usage('--config is required', _help);
    final names = args.multiOption('host');
    final groups = args.multiOption('group');
    final all = args.flag('all');
    final modes = [names.isNotEmpty, groups.isNotEmpty, all].where((m) => m);
    if (modes.length != 1) {
      throw const CliExit.usage(
        'choose exactly one of --host, --group or --all',
        _help,
      );
    }
    final fd = fdOption(args, 'passphrase-fd', _help);
    final passwordFd = fdOption(args, 'password-fd', _help);

    final config = CliConfig.load(path, environment: vaults.environment);
    final selected = <CliHost>[];
    if (names.isNotEmpty) {
      for (final n in names) {
        final h = config.hosts.where((h) => h.host.name == n);
        if (h.isEmpty) throw CliExit.usage('no host named $n in $path', _help);
        if (!selected.contains(h.first)) selected.add(h.first);
      }
    } else {
      selected.addAll(
        config.hosts.where(
          (h) => h.host.enabled && (all || groups.contains(h.host.group)),
        ),
      );
    }
    if (selected.isEmpty) {
      throw const CliExit.usage('no enabled host selected', _help);
    }

    final keyFiles = {
      for (final h in selected)
        if (h.keyFile case final f?) h.host.name: _readFile(f, 'key_file'),
    };
    final passFiles = {
      for (final h in selected)
        if (h.passphraseFile case final f?)
          h.host.name: _secretFile(f, 'passphrase_file'),
    };
    final diskFiles = {
      for (final h in selected)
        h.host.name: {
          for (final e in h.diskPassphraseFiles.entries)
            e.key: _secretFile(e.value, 'disk_passphrase_files'),
        },
    };

    final refs = <VaultRef>[
      for (final h in selected) ...[
        if (h.keyLabel case final l?)
          (where: h.host.name, kind: LabelKind.key, label: l),
        if (h.secretLabel case final l?)
          (where: h.host.name, kind: LabelKind.secret, label: l),
        for (final l in h.diskSecrets.values)
          (where: h.host.name, kind: LabelKind.secret, label: l),
      ],
    ];
    final fromVault = <(LabelKind, String), Uint8List>{};
    if (refs.isNotEmpty) {
      final loc = VaultLocation.resolve(
        args.option('vault'),
        vaults.environment,
      );
      fromVault.addAll(await vaults.readForRun(loc, refs, passwordFd));
      _secrets.addAll(fromVault.values);
    }

    Uint8List? shared;
    if (selected.any((h) => h.usesStdin)) {
      try {
        shared = _keep(await reader.read(fd: fd, prompt: err));
      } on FileSystemException catch (e) {
        throw CliExit.usage('cannot read the passphrase: ${osMessage(e)}');
      }
      if (shared.isEmpty) {
        throw const CliExit.usage('the passphrase is empty', _help);
      }
    }
    Uint8List secret(String label) => fromVault[(LabelKind.secret, label)]!;
    return [
      for (final h in selected)
        HostPlan(
          host: h.host,
          privateKeyPem:
              keyFiles[h.host.name] ?? fromVault[(LabelKind.key, h.keyLabel)]!,
          profile: h.profile,
          secrets: DiskPassphrases(
            passFiles[h.host.name] ??
                (h.secretLabel == null ? shared! : secret(h.secretLabel!)),
            perDisk: {
              ...diskFiles[h.host.name]!,
              for (final e in h.diskSecrets.entries) e.key: secret(e.value),
            },
          ),
        ),
    ];
  }

  /// Refuses a file that group or others may read, as ssh does for private keys.
  Uint8List _readFile(String path, String what) {
    try {
      if (openToOthers(path) case final mode?) {
        throw ConfigException(
          '$what $path is accessible by group or others (mode $mode); '
          'restrict it with chmod 600',
        );
      }
      return _keep(File(path).readAsBytesSync());
    } on FileSystemException catch (e) {
      throw ConfigException('$what $path: ${osMessage(e)}');
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
      // Messages and key types come from the servers.
      await for (final e in engine.run(plans)) {
        final name = names[e.hostId]!;
        final state = e.result?.label ?? e.phase.id;
        out.writeln('[$name] $state: ${terminalSafe(e.message)}');
        if (e.isFinal) finals[e.hostId] = e;
        if (e.newPrebootKey case final k?) {
          hints.add(
            '$name: accepted pre-boot key; pin it with  '
            'preboot_host_key: "${terminalSafe('$k')}"',
          );
        }
        if (e.newPostbootKey case final k?) {
          hints.add(
            '$name: post-boot key seen; record it with  '
            'postboot_host_key: "${terminalSafe('$k')}"',
          );
        }
        if (e.isFinal &&
            e.presentedKey != null &&
            plans.firstWhere((p) => p.host.id == e.hostId).host.prebootKey ==
                null) {
          hints.add(
            '$name: pre-boot key is not pinned; after checking it on the server, add  '
            'preboot_host_key: "${terminalSafe('${e.presentedKey}')}"  '
            'or run with --accept-new-host-key',
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
        '${p.host.name.padRight(nameWidth)}  ${state.label.padRight(stateWidth)}  ${terminalSafe(e?.message ?? '')}',
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
    err.writeln(
      '[${host.name}] accepting new pre-boot host key ${terminalSafe('$key')}',
    );
    return true;
  }
}
