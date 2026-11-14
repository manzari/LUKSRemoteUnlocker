import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:unlock_core/keys.dart';
import 'package:unlock_core/vault.dart';

import 'common.dart';
import 'config.dart';
import 'passphrase.dart';
import 'vault_files.dart';

const int minPasswordLength = 10;

/// Argon2id for new password slots; tests pass tiny parameters.
final class VaultTuning {
  const VaultTuning({
    this.kdf = argon2idInline,
    this.params = Argon2Params.defaults,
  });

  final PasswordKdf kdf;
  final Argon2Params params;
}

/// A label used by a host of the unlock config; `where` names the host for errors.
typedef VaultRef = ({String where, LabelKind kind, String label});

final class _Spec {
  const _Spec(this.args, this.summary, this.options);

  final String args;
  final String summary;
  final void Function(ArgParser) options;
}

void _password(ArgParser p) => p.addOption(
  'password-fd',
  valueHelp: 'N',
  help: 'Read the vault password byte for byte from this file descriptor.',
);

void _label(ArgParser p) =>
    p.addOption('label', valueHelp: 'L', help: 'Label to store it under.');

void _none(ArgParser p) {}

final Map<String, Map<String, _Spec>> _specs = {
  'vault': {
    'init': const _Spec(
      '',
      'Create a vault protected by a master password.',
      _password,
    ),
    'status': const _Spec(
      '',
      'Show whether the vault exists, its id and record counts.',
      _none,
    ),
    'passwd': _Spec('', 'Change the master password.', (p) {
      _password(p);
      p.addOption(
        'new-password-fd',
        valueHelp: 'N',
        help: 'Read the new password byte for byte from this file descriptor.',
      );
    }),
  },
  'key': {
    'generate': _Spec(
      '--label L [--comment C]',
      'Generate an Ed25519 login key in the vault; prints its public line and fingerprint.',
      (p) {
        _label(p);
        p.addOption(
          'comment',
          valueHelp: 'C',
          help: 'Comment of the public line (default: the label).',
        );
        _password(p);
      },
    ),
    'import': _Spec(
      '--label L FILE [--key-passphrase-fd N]',
      'Import an OpenSSH, PKCS#1 or SEC1 private key file into the vault.',
      (p) {
        _label(p);
        p.addOption(
          'key-passphrase-fd',
          valueHelp: 'N',
          help:
              'Read the key file passphrase from this file descriptor '
              '(default: ask on the terminal if the key is encrypted).',
        );
        _password(p);
      },
    ),
    'list': const _Spec('', 'List keys: label, type, fingerprint.', _none),
    'show': const _Spec(
      'LABEL',
      'Print the public line and fingerprint of a key.',
      _none,
    ),
    'rm': const _Spec('LABEL', 'Delete a key from the vault.', _password),
  },
  'secret': {
    'add': _Spec(
      '--label L [--secret-fd N]',
      'Store a LUKS passphrase (typed twice, or read from --secret-fd).',
      (p) {
        _label(p);
        p.addOption(
          'secret-fd',
          valueHelp: 'N',
          help: 'Read the passphrase byte for byte from this file descriptor.',
        );
        _password(p);
      },
    ),
    'list': const _Spec('', 'List the labels of stored passphrases.', _none),
    'rm': const _Spec(
      'LABEL',
      'Delete a passphrase from the vault.',
      _password,
    ),
  },
};

const vaultGroups = ['vault', 'key', 'secret'];

ArgParser _leafParser(_Spec spec) {
  final p = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.')
    ..addOption(
      'vault',
      valueHelp: 'PATH',
      help:
          'Vault file (default: \$$vaultPathVariable, else '
          '\$XDG_DATA_HOME/luks-remote-unlocker/vault.json).',
    );
  spec.options(p);
  return p;
}

ArgParser groupParser(String group) {
  final p = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');
  for (final e in _specs[group]!.entries) {
    p.addCommand(e.key, _leafParser(e.value));
  }
  return p;
}

String groupUsage(String group) {
  final specs = _specs[group]!;
  final width = specs.entries
      .map((e) => '${e.key} ${e.value.args}'.length)
      .reduce((a, b) => a > b ? a : b);
  return 'Usage: $executableName $group <command> [options]\n\n'
      'Commands:\n'
      '${[for (final e in specs.entries) '  ${'${e.key} ${e.value.args}'.padRight(width)}  ${e.value.summary}'].join('\n')}\n\n'
      "Run '$executableName $group <command> --help' for its options.";
}

String commandUsage(String group, String name) {
  final spec = _specs[group]![name]!;
  final line = 'Usage: $executableName $group $name ${spec.args}'.trimRight();
  return '$line [options]\n\n${spec.summary}\n\n${_leafParser(spec).usage}';
}

final class _Open {
  _Open(this.loc, this.store, this.vault, this.index);

  final VaultLocation loc;
  final FileVaultStore store;
  final Vault vault;
  final VaultIndex index;
}

/// The `vault`, `key` and `secret` commands, plus vault access for `unlock`.
final class VaultCli {
  VaultCli({
    required this.out,
    required this.err,
    required this.input,
    required this.environment,
    this.tuning = const VaultTuning(),
  });

  final StringSink out;
  final StringSink err;
  final SecretInput input;
  final Map<String, String> environment;
  final VaultTuning tuning;

  static const _keys = SshKeyService();

  Future<int> run(ArgResults group) async {
    final name = group.name!;
    final sub = group.command;
    try {
      if (sub == null) {
        if (group.rest.isNotEmpty) {
          throw CliExit.usage(
            'unknown $name command ${group.rest.first}',
            name,
          );
        }
        out.writeln(groupUsage(name));
        return 0;
      }
      if (sub.flag('help')) {
        out.writeln(commandUsage(name, sub.name!));
        return 0;
      }
      return await switch ('$name ${sub.name}') {
        'vault init' => _init(sub),
        'vault status' => _status(sub),
        'vault passwd' => _passwd(sub),
        'key generate' => _keyGenerate(sub),
        'key import' => _keyImport(sub),
        'key list' => _keyList(sub),
        'key show' => _keyShow(sub),
        'key rm' => _remove(sub, LabelKind.key),
        'secret add' => _secretAdd(sub),
        'secret list' => _secretList(sub),
        'secret rm' => _remove(sub, LabelKind.secret),
        final c => throw StateError('no handler for $c'),
      };
    } on CliExit catch (e) {
      e.report(err);
      return e.code;
    } on VaultException catch (e) {
      err.writeln('$executableName: ${e.message}');
      return exitFailure;
    } on SshKeyException catch (e) {
      err.writeln('$executableName: ${e.message}');
      return exitFailure;
    } on FileSystemException catch (e) {
      err.writeln('$executableName: ${e.path ?? e.message}: ${osMessage(e)}');
      return exitFailure;
    }
  }

  /// Unlocks the vault once and decrypts only the records of [refs]; the caller wipes the buffers.
  Future<Map<(LabelKind, String), Uint8List>> readForRun(
    VaultLocation loc,
    List<VaultRef> refs,
    int? passwordFd,
  ) async {
    if (!loc.exists) {
      throw ConfigException(
        '${refs.first.where} uses vault labels, but there is no vault at ${loc.vault}',
      );
    }
    final o = await _open(loc);
    final entries = <(LabelKind, String), IndexEntry>{};
    for (final r in refs) {
      entries[(r.kind, r.label)] =
          o.index.find(r.kind, r.label) ??
          (throw ConfigException(
            '${r.where}: no ${r.kind.word} labelled "${r.label}" in the vault ${loc.vault}',
          ));
    }
    await _unlock(o.vault, passwordFd, 'unlock');
    final plain = <(LabelKind, String), Uint8List>{};
    try {
      for (final MapEntry(key: ref, value: e) in entries.entries) {
        final record = await o.store.readRecord(e.recordId);
        if (record == null || record.kind != ref.$1.recordKind) {
          throw CliExit.failure(
            'the vault record of ${ref.$1.word} ${ref.$2} is missing or of another kind',
          );
        }
        plain[ref] = await o.vault.get(e.recordId);
      }
      return plain;
    } catch (_) {
      plain.values.forEach(wipe);
      rethrow;
    } finally {
      o.vault.lock();
    }
  }

  VaultLocation _locate(ArgResults a) =>
      VaultLocation.resolve(a.option('vault'), environment);

  void _requireVault(VaultLocation loc) {
    if (!loc.exists) {
      throw CliExit.failure(
        'no vault at ${loc.vault}; create one with "$executableName vault init"',
      );
    }
  }

  Future<_Open> _open(VaultLocation loc) async {
    _requireVault(loc);
    final store = await FileVaultStore.open(loc.vault);
    final vault = await Vault.open(store, kdf: tuning.kdf);
    return _Open(loc, store, vault, VaultIndex.load(loc, vault.id));
  }

  /// Opens the vault under the writer lock.
  Future<int> _write(ArgResults a, Future<int> Function(_Open o) body) {
    final loc = _locate(a);
    _requireVault(loc);
    return loc.exclusive(() async => body(await _open(loc)));
  }

  void _noArgs(ArgResults a, String helpFor) {
    if (a.rest.isNotEmpty) {
      throw CliExit.usage('unexpected argument ${a.rest.first}', helpFor);
    }
  }

  String _one(ArgResults a, String what, String helpFor) {
    if (a.rest.isEmpty) throw CliExit.usage('$what is required', helpFor);
    if (a.rest.length > 1) {
      throw CliExit.usage('unexpected argument ${a.rest[1]}', helpFor);
    }
    return a.rest.single;
  }

  IndexEntry _entry(_Open o, LabelKind kind, String label) =>
      o.index.find(kind, label) ??
      (throw CliExit.failure(
        'no ${kind.word} labelled $label in ${o.loc.vault}',
      ));

  void _free(_Open o, LabelKind kind, String label) {
    if (o.index.find(kind, label) != null) {
      throw CliExit.failure('a ${kind.word} labelled $label already exists');
    }
  }

  Uint8List _fd(int fd, String option) {
    try {
      return input.readFd(fd);
    } on FileSystemException catch (e) {
      throw CliExit.usage('cannot read --$option $fd: ${osMessage(e)}');
    }
  }

  void _needTerminal(String what, String option, String helpFor) {
    if (!input.hasTerminal) {
      throw CliExit.usage(
        'the $what is read from a terminal; without one use --$option N',
        helpFor,
      );
    }
  }

  Future<void> _unlock(Vault vault, int? fd, String helpFor) async {
    final Uint8List password;
    if (fd != null) {
      password = _fd(fd, 'password-fd');
    } else {
      _needTerminal('vault password', 'password-fd', helpFor);
      password = input.prompt('Vault password: ', err);
    }
    try {
      await vault.unlockWithPassword(password);
    } on VaultWrongPasswordException {
      throw const CliExit.failure('wrong vault password');
    } finally {
      wipe(password);
    }
  }

  /// Reads a new secret from [fd] as-is, or twice from the terminal.
  Uint8List _newSecret({
    required int? fd,
    required String option,
    required String what,
    required String prompt,
    required int minLength,
    required String helpFor,
  }) {
    final Uint8List value;
    if (fd != null) {
      value = _fd(fd, option);
    } else {
      _needTerminal(what, option, helpFor);
      value = input.prompt('$prompt: ', err);
      final again = input.prompt(
        'Repeat ${prompt[0].toLowerCase()}${prompt.substring(1)}: ',
        err,
      );
      final same = sameBytes(value, again);
      wipe(again);
      if (!same) {
        wipe(value);
        throw CliExit.usage('the ${what}s do not match');
      }
    }
    if (utf8Length(value) < minLength) {
      wipe(value);
      throw CliExit.usage(
        minLength > 1
            ? 'the $what must have at least $minLength characters'
            : 'the $what is empty',
      );
    }
    return value;
  }

  Future<void> _store(
    _Open o,
    LabelKind kind,
    String label,
    Uint8List secret, {
    SshKey? key,
  }) async {
    final id = await o.vault.put(kind.recordKind, secret);
    o.index.add(
      kind,
      IndexEntry(
        label: label,
        recordId: id,
        created: DateTime.now(),
        keyType: key?.type.wireName,
        publicLine: key?.publicLine,
        fingerprint: key?.fingerprint,
      ),
    );
    try {
      await o.index.save(o.loc);
    } catch (_) {
      await o.vault.delete(id).then<void>((_) {}, onError: (Object _) {});
      rethrow;
    }
  }

  Future<int> _init(ArgResults a) async {
    const helpFor = 'vault init';
    _noArgs(a, helpFor);
    final loc = _locate(a);
    final fd = fdOption(a, 'password-fd', helpFor);
    final exists = CliExit.failure('a vault already exists at ${loc.vault}');
    if (loc.exists) throw exists;
    final password = _newSecret(
      fd: fd,
      option: 'password-fd',
      what: 'vault password',
      prompt: 'New vault password',
      minLength: minPasswordLength,
      helpFor: helpFor,
    );
    try {
      return await loc.exclusive(() async {
        if (loc.exists) throw exists;
        final staging = File(loc.staging);
        if (staging.existsSync()) staging.deleteSync();
        final Vault vault;
        try {
          vault = await Vault.create(
            await FileVaultStore.open(loc.staging),
            kdf: tuning.kdf,
          );
          try {
            await vault.setPassword(password, params: tuning.params);
          } finally {
            vault.lock();
          }
          staging.renameSync(loc.vault);
        } catch (_) {
          if (staging.existsSync()) staging.deleteSync();
          rethrow;
        }
        await VaultIndex(vault.id).save(loc);
        out.writeln('Created vault ${vault.id} at ${loc.vault}');
        return 0;
      });
    } finally {
      wipe(password);
    }
  }

  Future<int> _status(ArgResults a) async {
    _noArgs(a, 'vault status');
    final loc = _locate(a);
    out.writeln('vault:          ${loc.vault}');
    if (!loc.exists) {
      out.writeln('exists:         no');
      return exitFailure;
    }
    final o = await _open(loc);
    final ids = (await o.store.listRecordIds()).toSet();
    final counts = {for (final k in VaultRecordKind.values) k: 0};
    for (final id in ids) {
      final kind = (await o.store.readRecord(id))!.kind;
      counts[kind] = counts[kind]! + 1;
    }
    final keys = o.index.of(LabelKind.key);
    final secrets = o.index.of(LabelKind.secret);
    out
      ..writeln('exists:         yes')
      ..writeln('id:             ${o.vault.id}')
      ..writeln('index:          ${loc.index}')
      ..writeln('password slot:  ${o.vault.hasPasswordSlot ? 'yes' : 'no'}')
      ..writeln(
        'records:        '
        '${[for (final e in counts.entries) '${e.value} ${e.key.wireName}'].join(', ')}',
      )
      ..writeln('labels:         ${keys.length} key, ${secrets.length} secret');
    final orphans = ids.difference(o.index.recordIds).length;
    if (orphans > 0) {
      out.writeln('warning: $orphans vault record(s) have no label');
    }
    for (final kind in LabelKind.values) {
      for (final e in o.index.of(kind)) {
        if (!ids.contains(e.recordId)) {
          out.writeln('warning: ${kind.word} ${e.label} has no vault record');
        }
      }
    }
    return 0;
  }

  Future<int> _passwd(ArgResults a) async {
    const helpFor = 'vault passwd';
    _noArgs(a, helpFor);
    final fd = fdOption(a, 'password-fd', helpFor);
    final newFd = fdOption(a, 'new-password-fd', helpFor);
    return _write(a, (o) async {
      await _unlock(o.vault, fd, helpFor);
      try {
        final password = _newSecret(
          fd: newFd,
          option: 'new-password-fd',
          what: 'new vault password',
          prompt: 'New vault password',
          minLength: minPasswordLength,
          helpFor: helpFor,
        );
        try {
          await o.vault.changePassword(password, params: tuning.params);
        } finally {
          wipe(password);
        }
      } finally {
        o.vault.lock();
      }
      out.writeln('Changed the password of vault ${o.vault.id}');
      return 0;
    });
  }

  void _printKey(String? publicLine, String? fingerprint) => out
    ..writeln(publicLine ?? '?')
    ..writeln(fingerprint ?? '?');

  Future<int> _keyGenerate(ArgResults a) async {
    const helpFor = 'key generate';
    _noArgs(a, helpFor);
    final label = checkLabel(a.option('label'), helpFor);
    final comment = a.option('comment') ?? label;
    final fd = fdOption(a, 'password-fd', helpFor);
    return _write(a, (o) async {
      _free(o, LabelKind.key, label);
      await _unlock(o.vault, fd, helpFor);
      final SshKey key;
      try {
        key = _keys.generateEd25519(comment: comment);
        try {
          await _store(o, LabelKind.key, label, key.privateKeyPem, key: key);
        } finally {
          wipe(key.privateKeyPem);
        }
      } finally {
        o.vault.lock();
      }
      _printKey(key.publicLine, key.fingerprint);
      return 0;
    });
  }

  Future<int> _keyImport(ArgResults a) async {
    const helpFor = 'key import';
    final path = _one(a, 'FILE', helpFor);
    final label = checkLabel(a.option('label'), helpFor);
    final fd = fdOption(a, 'password-fd', helpFor);
    final keyFd = fdOption(a, 'key-passphrase-fd', helpFor);
    final Uint8List file;
    try {
      file = File(path).readAsBytesSync();
    } on FileSystemException catch (e) {
      throw CliExit.usage('$path: ${osMessage(e)}', helpFor);
    }
    try {
      return await _write(a, (o) async {
        _free(o, LabelKind.key, label);
        final key = _import(file, keyFd, helpFor);
        try {
          await _unlock(o.vault, fd, helpFor);
          await _store(o, LabelKind.key, label, key.privateKeyPem, key: key);
        } finally {
          wipe(key.privateKeyPem);
          o.vault.lock();
        }
        _printKey(key.publicLine, key.fingerprint);
        return 0;
      });
    } finally {
      wipe(file);
    }
  }

  SshKey _import(Uint8List file, int? fd, String helpFor) {
    var passphrase = fd == null ? null : _fd(fd, 'key-passphrase-fd');
    try {
      try {
        return _keys.importOpenSsh(file, passphrase: passphrase);
      } on KeyPassphraseRequiredException {
        if (passphrase != null) rethrow;
        if (!input.hasTerminal) {
          throw CliExit.usage(
            'the key file is encrypted; type its passphrase on a terminal '
            'or use --key-passphrase-fd N',
            helpFor,
          );
        }
        passphrase = input.prompt('Key passphrase: ', err);
        return _keys.importOpenSsh(file, passphrase: passphrase);
      }
    } finally {
      if (passphrase != null) wipe(passphrase);
    }
  }

  Future<int> _keyList(ArgResults a) async {
    _noArgs(a, 'key list');
    final keys = (await _open(_locate(a))).index.of(LabelKind.key);
    if (keys.isEmpty) return 0;
    int widest(String head, Iterable<String> cells) =>
        [head, ...cells].map((s) => s.length).reduce((a, b) => a > b ? a : b);
    final lw = widest('LABEL', keys.map((k) => k.label));
    final tw = widest('TYPE', keys.map((k) => k.keyType ?? '?'));
    out.writeln('${'LABEL'.padRight(lw)}  ${'TYPE'.padRight(tw)}  FINGERPRINT');
    for (final k in keys) {
      out.writeln(
        '${k.label.padRight(lw)}  ${(k.keyType ?? '?').padRight(tw)}  ${k.fingerprint ?? '?'}',
      );
    }
    return 0;
  }

  Future<int> _keyShow(ArgResults a) async {
    final label = _one(a, 'LABEL', 'key show');
    final e = _entry(await _open(_locate(a)), LabelKind.key, label);
    _printKey(e.publicLine, e.fingerprint);
    return 0;
  }

  Future<int> _secretAdd(ArgResults a) async {
    const helpFor = 'secret add';
    _noArgs(a, helpFor);
    final label = checkLabel(a.option('label'), helpFor);
    final fd = fdOption(a, 'password-fd', helpFor);
    final secretFd = fdOption(a, 'secret-fd', helpFor);
    if (secretFd == null) _needTerminal('passphrase', 'secret-fd', helpFor);
    return _write(a, (o) async {
      _free(o, LabelKind.secret, label);
      await _unlock(o.vault, fd, helpFor);
      try {
        final secret = _newSecret(
          fd: secretFd,
          option: 'secret-fd',
          what: 'passphrase',
          prompt: 'Passphrase for $label',
          minLength: 1,
          helpFor: helpFor,
        );
        try {
          await _store(o, LabelKind.secret, label, secret);
        } finally {
          wipe(secret);
        }
      } finally {
        o.vault.lock();
      }
      out.writeln('Stored secret $label');
      return 0;
    });
  }

  Future<int> _secretList(ArgResults a) async {
    _noArgs(a, 'secret list');
    final o = await _open(_locate(a));
    for (final e in o.index.of(LabelKind.secret)) {
      out.writeln(e.label);
    }
    return 0;
  }

  Future<int> _remove(ArgResults a, LabelKind kind) async {
    final helpFor = '${kind.word} rm';
    final label = _one(a, 'LABEL', helpFor);
    final fd = fdOption(a, 'password-fd', helpFor);
    return _write(a, (o) async {
      final e = _entry(o, kind, label);
      await _unlock(o.vault, fd, helpFor);
      try {
        o.index.remove(kind, label);
        await o.index.save(o.loc);
        if ((await o.store.readRecord(e.recordId)) != null) {
          await o.vault.delete(e.recordId);
        }
      } finally {
        o.vault.lock();
      }
      out.writeln('Removed ${kind.word} $label');
      return 0;
    });
  }
}
