import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unlock_cli/unlock_cli.dart';
import 'package:unlock_core/unlock_core.dart';

import 'support.dart';

const pw = fakeVaultPassword;
const benchKey = '../../bench/fixtures/id_ed25519_bench';

void main() {
  late Directory dir;
  late String vaultPath;
  late ScriptedInput input;
  late StringBuffer out;
  late StringBuffer err;
  late FakeWorld world;
  late List<(String, Uint8List)> leaks;
  final transcript = BytesBuilder();
  var stdinReads = 0;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vault_cli_');
    vaultPath = '${dir.path}/data/vault.json';
    input = ScriptedInput();
    world = FakeWorld();
    transcript.clear();
    stdinReads = 0;
    leaks = [
      for (final s in [fakeVaultPassword, fakeNewPassword, fakeLuksPass])
        (s, bytesOf(s)),
      ('key file passphrase', bytesOf(fakeKeyPass)),
    ];
  });

  tearDown(() {
    final all = transcript.toBytes();
    for (final (what, secret) in leaks) {
      expectAbsent(all, secret, '$what in stdout/stderr');
    }
    dir.deleteSync(recursive: true);
  });

  Future<int> cli(
    List<String> args, {
    List<String> answers = const [],
    Map<int, String> fds = const {},
    bool terminal = true,
    String stdinPass = 'FAKE-stdin-pass',
  }) async {
    input
      ..terminal = terminal
      ..prompts.clear()
      ..answers.clear()
      ..answers.addAll(answers)
      ..fds.clear()
      ..fds.addAll(fds);
    out = StringBuffer();
    err = StringBuffer();
    final code = await runCli(
      args,
      out: out,
      err: err,
      input: input,
      tuning: tinyArgon,
      environment: {'HOME': dir.path, vaultPathVariable: vaultPath},
      newEngine: world.engine,
      readPassphrase: _Stdin(stdinPass, () => stdinReads++),
    );
    transcript
      ..add(utf8.encode(out.toString()))
      ..add(utf8.encode(err.toString()));
    printOnFailure('$args -> $code\n$out$err');
    return code;
  }

  Future<void> init() async {
    expect(await cli(['vault', 'init'], answers: [pw, pw]), 0);
  }

  Future<void> addSecret(String label, String value) async {
    expect(
      await cli(
        ['secret', 'add', '--label', label, '--secret-fd', '4'],
        answers: [pw],
        fds: {4: value},
      ),
      0,
    );
  }

  Future<Uint8List> record(LabelKind kind, String label) async {
    final store = await FileVaultStore.open(vaultPath);
    final vault = await Vault.open(store, kdf: argon2idInline);
    final index = VaultIndex.load(VaultLocation(vaultPath), vault.id);
    await vault.unlockWithPassword(bytesOf(pw));
    try {
      return await vault.get(index.find(kind, label)!.recordId);
    } finally {
      vault.lock();
    }
  }

  Future<String> generate(String label) async {
    expect(await cli(['key', 'generate', '--label', label], answers: [pw]), 0);
    final line = out.toString().split('\n').first;
    leaks.addAll(keyMaterial(await record(LabelKind.key, label), line));
    return line;
  }

  Future<List<String>> recordIds() async =>
      (await FileVaultStore.open(vaultPath)).listRecordIds();

  group('vault location', () {
    test('defaults to XDG_DATA_HOME, then ~/.local/share', () {
      expect(
        VaultLocation.resolve(null, {
          'HOME': '/h',
          'XDG_DATA_HOME': '/x',
        }).vault,
        '/x/luks-remote-unlocker/vault.json',
      );
      final home = VaultLocation.resolve(null, {
        'HOME': '/h',
        'XDG_DATA_HOME': 'relative',
      });
      expect(home.vault, '/h/.local/share/luks-remote-unlocker/vault.json');
      expect(
        home.index,
        '/h/.local/share/luks-remote-unlocker/vault.index.json',
      );
      expect(home.lock, '/h/.local/share/luks-remote-unlocker/vault.lock');
    });

    test('--vault beats the environment variable', () {
      final env = {'HOME': '/h', vaultPathVariable: '/env/v.json'};
      expect(VaultLocation.resolve(null, env).vault, '/env/v.json');
      expect(VaultLocation.resolve('/flag/v', env).vault, '/flag/v');
      expect(VaultLocation.resolve('/flag/v', env).index, '/flag/v.index.json');
      expect(VaultLocation.resolve('~/v.json', env).vault, '/h/v.json');
    });

    test('--vault on the command line is used', () async {
      final other = '${dir.path}/other/v.json';
      expect(
        await cli(['vault', 'init', '--vault', other], answers: [pw, pw]),
        0,
      );
      expect(File(other).existsSync(), isTrue);
      expect(File(vaultPath).existsSync(), isFalse);
    });
  });

  group('vault init', () {
    test('asks twice, writes private files, no staging left', () async {
      await init();
      expect(input.prompts, [
        'New vault password: ',
        'Repeat new vault password: ',
      ]);
      expect(out.toString(), startsWith('Created vault '));
      final loc = VaultLocation(vaultPath);
      expect(File(loc.vault).statSync().modeString(), 'rw-------');
      expect(File(loc.index).statSync().modeString(), 'rw-------');
      expect(Directory(loc.dir).statSync().modeString(), 'rwx------');
      expect(File(loc.staging).existsSync(), isFalse);
      expect(jsonDecode(File(loc.index).readAsStringSync()), {
        'version': 1,
        'vaultId': isA<String>(),
        'keys': isEmpty,
        'secrets': isEmpty,
      });
    });

    test('refuses an existing vault', () async {
      await init();
      expect(await cli(['vault', 'init'], answers: [pw, pw]), exitFailure);
      expect(err.toString(), contains('a vault already exists'));
      expect(input.prompts, isEmpty);
    });

    test('short, mismatched or missing passwords are usage errors', () async {
      expect(
        await cli(['vault', 'init'], answers: ['short-pw', 'short-pw']),
        exitUsage,
      );
      expect(err.toString(), contains('at least 10 characters'));
      expect(
        await cli(['vault', 'init'], answers: [pw, fakeNewPassword]),
        exitUsage,
      );
      expect(err.toString(), contains('do not match'));
      expect(await cli(['vault', 'init'], terminal: false), exitUsage);
      expect(err.toString(), contains('--password-fd'));
      expect(await cli(['vault', 'init', '--password-fd', 'x']), exitUsage);
      expect(await cli(['vault', 'init', '--password-fd', '9']), exitUsage);
      expect(err.toString(), contains('cannot read --password-fd 9'));
      expect(await cli(['vault', 'init', 'extra']), exitUsage);
      expect(File(vaultPath).existsSync(), isFalse);
    });

    test('--password-fd uses the bytes exactly as read', () async {
      expect(
        await cli(
          ['vault', 'init', '--password-fd', '3'],
          fds: {3: '$pw\n'},
          terminal: false,
        ),
        0,
      );
      expect(
        await cli(['key', 'generate', '--label', 'k'], answers: [pw]),
        exitFailure,
      );
      expect(err.toString(), contains('wrong vault password'));
      expect(
        await cli(
          ['key', 'generate', '--label', 'k', '--password-fd', '3'],
          fds: {3: '$pw\n'},
        ),
        0,
      );
    });
  });

  group('vault status', () {
    test('missing vault: exit 1', () async {
      expect(await cli(['vault', 'status']), exitFailure);
      expect(out.toString(), contains('exists:         no'));
    });

    test('counts records by kind and needs no password', () async {
      await init();
      await generate('laptop');
      await addSecret('nas', fakeLuksPass);
      expect(await cli(['vault', 'status']), 0);
      expect(input.prompts, isEmpty);
      final text = out.toString();
      expect(text, contains('exists:         yes'));
      expect(text, contains('password slot:  yes'));
      expect(text, contains('records:        1 ssh-key, 1 passphrase'));
      expect(text, contains('labels:         1 key, 1 secret'));
      expect(text, isNot(contains('warning')));
      final vault = await Vault.open(await FileVaultStore.open(vaultPath));
      expect(text, contains('id:             ${vault.id}'));
    });

    test('warns about records without a label', () async {
      await init();
      await addSecret('nas', fakeLuksPass);
      File(VaultLocation(vaultPath).index).deleteSync();
      expect(await cli(['vault', 'status']), 0);
      expect(out.toString(), contains('1 vault record(s) have no label'));
    });
  });

  group('vault passwd', () {
    test('changes the password; the old one stops working', () async {
      await init();
      await addSecret('nas', fakeLuksPass);
      expect(
        await cli(
          ['vault', 'passwd'],
          answers: [pw, fakeNewPassword, fakeNewPassword],
        ),
        0,
      );
      expect(input.prompts, [
        'Vault password: ',
        'New vault password: ',
        'Repeat new vault password: ',
      ]);
      expect(await cli(['secret', 'rm', 'nas'], answers: [pw]), exitFailure);
      expect(
        await cli(
          ['secret', 'rm', 'nas', '--password-fd', '3'],
          fds: {3: fakeNewPassword},
        ),
        0,
      );
    });

    test('wrong current password, short new password', () async {
      await init();
      expect(
        await cli(['vault', 'passwd'], answers: [fakeNewPassword]),
        exitFailure,
      );
      expect(err.toString(), contains('wrong vault password'));
      expect(
        await cli(
          ['vault', 'passwd', '--password-fd', '3', '--new-password-fd', '4'],
          fds: {3: pw, 4: 'tiny'},
        ),
        exitUsage,
      );
      expect(err.toString(), contains('at least 10 characters'));
      expect(await cli(['key', 'generate', '--label', 'k'], answers: [pw]), 0);
    });

    test('no vault: exit 1, nothing created', () async {
      expect(await cli(['vault', 'passwd'], answers: [pw]), exitFailure);
      expect(err.toString(), contains('no vault at'));
      expect(Directory('${dir.path}/data').existsSync(), isFalse);
    });
  });

  group('key', () {
    test('generate prints the public line and fingerprint', () async {
      await init();
      final line = await generate('laptop');
      final printed = out.toString().split('\n');
      expect(line, matches(RegExp(r'^ssh-ed25519 AAAA\S+ laptop$')));
      final blob = base64.decode(line.split(' ')[1]);
      expect(printed[1], sshFingerprint(blob));
      expect(input.prompts, ['Vault password: ']);

      final pem = await record(LabelKind.key, 'laptop');
      final stored = const SshKeyService().importOpenSsh(pem);
      expect(stored.fingerprint, printed[1]);

      expect(await cli(['key', 'show', 'laptop']), 0);
      expect(out.toString(), '$line\n${printed[1]}\n');
      expect(await cli(['key', 'list']), 0);
      expect(
        out.toString(),
        'LABEL   TYPE         FINGERPRINT\n'
        'laptop  ssh-ed25519  ${printed[1]}\n',
      );
    });

    test('--comment sets the comment', () async {
      await init();
      expect(
        await cli(
          ['key', 'generate', '--label', 'k', '--comment', 'me@phone'],
          answers: [pw],
        ),
        0,
      );
      expect(out.toString().split('\n').first, endsWith(' me@phone'));
    });

    test(
      'errors: duplicate, bad or missing label, wrong password, no vault',
      () async {
        expect(
          await cli(['key', 'generate', '--label', 'k'], answers: [pw]),
          exitFailure,
        );
        expect(err.toString(), contains('no vault at'));
        expect(Directory('${dir.path}/data').existsSync(), isFalse);

        await init();
        expect(await cli(['key', 'generate']), exitUsage);
        expect(err.toString(), contains('--label is required'));
        expect(await cli(['key', 'generate', '--label', 'a b']), exitUsage);
        expect(err.toString(), contains('invalid label'));

        expect(
          await cli(
            ['key', 'generate', '--label', 'k'],
            answers: ['wrong-pass-1'],
          ),
          exitFailure,
        );
        expect(err.toString(), contains('wrong vault password'));
        expect(await recordIds(), isEmpty);
        expect(await cli(['key', 'list']), 0);
        expect(out.toString(), isEmpty);

        await generate('k');
        expect(
          await cli(['key', 'generate', '--label', 'k'], answers: [pw]),
          exitFailure,
        );
        expect(err.toString(), contains('a key labelled k already exists'));
        expect(input.prompts, isEmpty);
        expect(await recordIds(), hasLength(1));

        expect(await cli(['key', 'show', 'nope']), exitFailure);
        expect(err.toString(), contains('no key labelled nope'));
        expect(await cli(['key', 'show']), exitUsage);
        expect(await cli(['key', 'rm', 'nope'], answers: [pw]), exitFailure);
      },
    );

    test('import: plain file, then encrypted with prompt and fd', () async {
      await init();
      expect(
        await cli(
          ['key', 'import', '--label', 'bench', benchKey],
          answers: [pw],
        ),
        0,
      );
      final bench = const SshKeyService().importOpenSsh(
        File(benchKey).readAsBytesSync(),
      );
      expect(out.toString(), '${bench.publicLine}\n${bench.fingerprint}\n');

      final file = '${dir.path}/enc';
      final r = await Process.run('ssh-keygen', [
        '-q',
        '-t',
        'ed25519',
        '-N',
        fakeKeyPass,
        '-C',
        'enc',
        '-f',
        file,
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(
        await cli(
          ['key', 'import', '--label', 'enc', file],
          answers: [fakeKeyPass, pw],
        ),
        0,
      );
      expect(input.prompts, ['Key passphrase: ', 'Vault password: ']);
      final pub = File('$file.pub').readAsStringSync().trim();
      expect(out.toString().split('\n').first, pub);
      leaks.addAll(keyMaterial(await record(LabelKind.key, 'enc'), pub));

      expect(
        await cli(
          [
            'key',
            'import',
            '--label',
            'enc2',
            file,
            '--key-passphrase-fd',
            '5',
          ],
          answers: [pw],
          fds: {5: fakeKeyPass},
        ),
        0,
      );
      expect(input.prompts, ['Vault password: ']);
    });

    test('import errors', () async {
      await init();
      final file = '${dir.path}/enc';
      await Process.run('ssh-keygen', [
        '-q',
        '-t',
        'ed25519',
        '-N',
        fakeKeyPass,
        '-f',
        file,
      ]);
      expect(
        await cli(
          ['key', 'import', '--label', 'e', file],
          answers: ['nope', pw],
        ),
        exitFailure,
      );
      expect(err.toString(), contains('passphrase is wrong'));
      expect(
        await cli(['key', 'import', '--label', 'e', file], terminal: false),
        exitUsage,
      );
      expect(err.toString(), contains('--key-passphrase-fd'));
      expect(
        await cli(
          ['key', 'import', '--label', 'e', '$file.pub'],
          answers: [pw],
        ),
        exitFailure,
      );
      expect(err.toString(), contains('This is a public key'));
      expect(
        await cli(['key', 'import', '--label', 'e', '${dir.path}/none']),
        exitUsage,
      );
      expect(await cli(['key', 'import', '--label', 'e']), exitUsage);
      expect(err.toString(), contains('FILE is required'));
      expect(await recordIds(), isEmpty);
    });

    test('rm needs the password and removes record and label', () async {
      await init();
      await generate('a');
      await generate('b');
      expect(await cli(['key', 'rm', 'a'], answers: ['wrong-pass-1']), 1);
      expect(await recordIds(), hasLength(2));
      expect(await cli(['key', 'rm', 'a'], answers: [pw]), 0);
      expect(out.toString(), 'Removed key a\n');
      expect(await recordIds(), hasLength(1));
      expect(await cli(['key', 'list']), 0);
      expect(out.toString(), isNot(contains('a ')));
      expect(out.toString(), contains('\nb '));
    });
  });

  group('secret', () {
    test('add asks the passphrase twice after the vault password', () async {
      await init();
      expect(
        await cli(
          ['secret', 'add', '--label', 'nas'],
          answers: [pw, fakeLuksPass, fakeLuksPass],
        ),
        0,
      );
      expect(input.prompts, [
        'Vault password: ',
        'Passphrase for nas: ',
        'Repeat passphrase for nas: ',
      ]);
      expect(out.toString(), 'Stored secret nas\n');
      expect(await record(LabelKind.secret, 'nas'), bytesOf(fakeLuksPass));
    });

    test('--secret-fd keeps the bytes exactly', () async {
      await init();
      await addSecret('nas', '$fakeLuksPass\n');
      expect(await record(LabelKind.secret, 'nas'), bytesOf('$fakeLuksPass\n'));
    });

    test('errors', () async {
      expect(
        await cli(['secret', 'add', '--label', 's'], answers: [pw, 'x', 'x']),
        exitFailure,
      );
      await init();
      expect(
        await cli(
          ['secret', 'add', '--label', 's'],
          answers: [pw, fakeLuksPass, 'other'],
        ),
        exitUsage,
      );
      expect(err.toString(), contains('passphrases do not match'));
      expect(
        await cli(['secret', 'add', '--label', 's'], answers: [pw, '', '']),
        exitUsage,
      );
      expect(err.toString(), contains('passphrase is empty'));
      expect(
        await cli(['secret', 'add', '--label', 's'], terminal: false),
        exitUsage,
      );
      expect(input.prompts, isEmpty);
      expect(
        await cli(
          ['secret', 'add', '--label', 's', '--secret-fd', '4'],
          answers: ['wrong-pass-1'],
          fds: {4: fakeLuksPass},
        ),
        exitFailure,
      );
      expect(await recordIds(), isEmpty);
      await addSecret('s', fakeLuksPass);
      expect(
        await cli(
          ['secret', 'add', '--label', 's', '--secret-fd', '4'],
          answers: [pw],
          fds: {4: fakeLuksPass},
        ),
        exitFailure,
      );
      expect(err.toString(), contains('a secret labelled s already exists'));
      expect(await cli(['secret', 'rm', 'x'], answers: [pw]), exitFailure);
      expect(err.toString(), contains('no secret labelled x'));
    });

    test('list prints labels only; rm removes', () async {
      await init();
      await addSecret('nas', fakeLuksPass);
      await addSecret('web', fakeNewPassword);
      await generate('nas');
      expect(await cli(['secret', 'list']), 0);
      expect(out.toString(), 'nas\nweb\n');
      expect(await cli(['secret', 'rm', 'nas'], answers: [pw]), 0);
      expect(await cli(['secret', 'list']), 0);
      expect(out.toString(), 'web\n');
      expect(await cli(['key', 'list']), 0);
      expect(out.toString(), contains('nas'));
    });
  });

  test(
    'vault directory holds no password, passphrase or private key',
    () async {
      await init();
      await generate('laptop');
      await addSecret('nas', fakeLuksPass);
      expect(
        await cli(
          ['secret', 'add', '--label', 'tty'],
          answers: [pw, fakeNewPassword, fakeNewPassword],
        ),
        0,
      );
      final files = Directory(VaultLocation(vaultPath).dir).listSync();
      expect(files.map((f) => f.uri.pathSegments.last).toSet(), {
        'vault.json',
        'vault.index.json',
        'vault.lock',
      });
      final all = [for (final f in files) ...File(f.path).readAsBytesSync()];
      for (final (what, secret) in leaks) {
        expectAbsent(all, secret, '$what in the vault directory');
      }
    },
  );

  group('help and usage', () {
    test('groups and commands', () async {
      expect(await cli(['vault']), 0);
      expect(out.toString(), contains('passwd'));
      expect(await cli(['key', '--help']), 0);
      expect(out.toString(), contains('generate --label L [--comment C]'));
      expect(await cli(['secret', 'add', '--help']), 0);
      expect(out.toString(), contains('--secret-fd'));
      expect(await cli(['vault', 'bogus']), exitUsage);
      expect(await cli(['key', 'list', '--nope']), exitUsage);
      expect(await cli(['--help']), 0);
      expect(out.toString(), contains('secret   Add, list and remove'));
    });
  });

  group('unlock with vault labels', () {
    String config(String hosts, [String name = 'hosts']) {
      final f = File('${dir.path}/$name.yaml')
        ..writeAsStringSync(
          'defaults:\n  postboot_check: tcp\n  wait_timeout: 5\n  boot_timeout: 5\n'
          'hosts:\n$hosts',
        );
      return f.path;
    }

    const vaultHost =
        '  - {name: a, preboot: "a:2222", postboot: "a:22", key: laptop, '
        'secret: nas, disk_secrets: {sdb1_crypt: data}}\n';

    Future<void> fill() async {
      await init();
      await generate('laptop');
      await addSecret('nas', fakeLuksPass);
      await addSecret('data', fakeNewPassword);
    }

    test(
      'one password prompt, records passed to the engine, then wiped',
      () async {
        await fill();
        final pem = await record(LabelKind.key, 'laptop');
        final path = config(vaultHost);
        expect(await cli(['unlock', '-c', path, '--all'], answers: [pw]), 0);
        expect(input.prompts, ['Vault password: ']);
        expect(stdinReads, 0);
        expect(out.toString(), contains(RegExp(r'\na\s+Unlocked\s+booted')));
        expect(world.keys['a'], latin1.decode(pem));
        expect(world.secrets['a'], {
          'sda3_crypt': fakeLuksPass,
          'sdb1_crypt': fakeNewPassword,
        });
        for (final b in [...world.keyBuffers, ...world.secretBuffers]) {
          expect(b.every((x) => x == 0), isTrue, reason: 'buffer not wiped');
        }
      },
    );

    test('mixing vault and stdin hosts: one prompt each', () async {
      await fill();
      final path = config(
        '$vaultHost  - {name: b, preboot: "b:2222", postboot: "b:22", '
        'key_file: ${File(benchKey).absolute.path}}\n',
      );
      expect(
        await cli(
          ['unlock', '-c', path, '--all', '--password-fd', '3'],
          fds: {3: pw},
          stdinPass: 'FAKE-stdin-pass',
        ),
        0,
      );
      expect(input.prompts, isEmpty);
      expect(stdinReads, 1);
      expect(world.secrets['b']!['sda3_crypt'], 'FAKE-stdin-pass');
      expect(world.secrets['a']!['sda3_crypt'], fakeLuksPass);
    });

    test('decrypts only the records it needs', () async {
      await fill();
      await addSecret('unused', 'FAKE-unused');
      final vault = await Vault.open(await FileVaultStore.open(vaultPath));
      final id = VaultIndex.load(
        VaultLocation(vaultPath),
        vault.id,
      ).find(LabelKind.secret, 'unused')!.recordId;
      final json = jsonDecode(
        File(vaultPath).readAsStringSync(),
      ) as Map<String, Object?>;
      for (final r in (json['records']! as List).cast<Map<String, Object?>>()) {
        if (r['id'] == id) {
          final c = base64.decode(r['ciphertext']! as String);
          c[0] ^= 1;
          r['ciphertext'] = base64.encode(c);
        }
      }
      File(vaultPath).writeAsStringSync(jsonEncode(json));
      final path = config(vaultHost);
      expect(await cli(['unlock', '-c', path, '--all'], answers: [pw]), 0);
      expect(
        await cli(
          [
            'unlock',
            '-c',
            config(vaultHost.replaceFirst('nas', 'unused'), 'unused'),
            '--all',
          ],
          answers: [pw],
        ),
        exitFailure,
      );
      expect(err.toString(), contains('failed authentication'));
    });

    test('config and vault errors', () async {
      final path = config(vaultHost);
      expect(await cli(['unlock', '-c', path, '--all'], answers: [pw]), 64);
      expect(err.toString(), contains('no vault at'));
      expect(input.prompts, isEmpty);

      await fill();
      final missing = config(vaultHost.replaceFirst('data', 'nope'), 'missing');
      expect(await cli(['unlock', '-c', missing, '--all'], answers: [pw]), 64);
      expect(err.toString(), contains('no secret labelled "nope"'));
      expect(input.prompts, isEmpty);

      expect(
        await cli(['unlock', '-c', path, '--all'], answers: ['wrong-pass-1']),
        exitFailure,
      );
      expect(err.toString(), contains('wrong vault password'));
      expect(world.keys, isEmpty);

      expect(await cli(['unlock', '-c', path, '--all'], terminal: false), 64);
      expect(err.toString(), contains('--password-fd'));

      final neither = config('  - {name: c, preboot: "c:2222"}\n', 'neither');
      expect(await cli(['unlock', '-c', neither, '--all']), 64);
      expect(err.toString(), contains('key_file or key is required'));
    });

    test('--vault selects the vault for unlock', () async {
      final other = '${dir.path}/other.json';
      expect(
        await cli(['vault', 'init', '--vault', other], answers: [pw, pw]),
        0,
      );
      expect(
        await cli(
          ['key', 'generate', '--vault', other, '--label', 'laptop'],
          answers: [pw],
        ),
        0,
      );
      final path = config(
        '  - {name: a, preboot: "a:2222", postboot: "a:22", key: laptop}\n',
      );
      expect(await cli(['unlock', '-c', path, '--all']), 64);
      expect(
        await cli(
          ['unlock', '-c', path, '--all', '--vault', other],
          answers: [pw],
        ),
        0,
      );
      expect(stdinReads, 1);
    });
  });
}

final class _Stdin implements PassphraseReader {
  _Stdin(this.value, this.onRead);

  final String value;
  final void Function() onRead;

  @override
  Uint8List read({int? fd, required StringSink prompt}) {
    onRead();
    return bytesOf(value);
  }
}
