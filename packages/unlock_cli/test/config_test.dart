import 'dart:io';

import 'package:test/test.dart';
import 'package:unlock_cli/unlock_cli.dart';
import 'package:unlock_core/engine.dart';

final fp = 'SHA256:${'A' * 43}';

CliConfig parse(String yaml) => CliConfig.parse(yaml, baseDir: '/cfg');

Matcher configError(String text) => throwsA(
  isA<ConfigException>().having((e) => e.message, 'message', contains(text)),
);

void main() {
  test('full host with defaults merged', () {
    final c = parse('''
defaults:
  user: admin
  key_file: keys/default
  wait_timeout: 2m
hosts:
  - name: nas
    group: home
    preboot: [nas:2222, "[fd00::5]:2222"]
    preboot_host_key: "ssh-ed25519 $fp"
    postboot: nas.lan
    postboot_check: tcp
    postboot_host_key: "$fp"
    boot_timeout: 90
    legacy_algorithms: true
    enabled: false
    command: my-unlock
    passphrase_file: p/nas
    disk_passphrase_files: {sdb1_crypt: /abs/disk}
''');
    final h = c.hosts.single;
    expect(h.host.name, 'nas');
    expect(h.host.id, 'nas');
    expect(h.host.group, 'home');
    expect(h.host.user, 'admin');
    expect(h.host.preboot, [
      const Endpoint('nas', 2222),
      const Endpoint('fd00::5', 2222),
    ]);
    expect(h.host.prebootKey, HostKey('ssh-ed25519', fp));
    expect(h.host.postboot, const Endpoint('nas.lan', 22));
    expect(h.host.postbootCheck, PostBootCheck.tcp);
    expect(h.host.postbootKey, HostKey(null, fp));
    expect(h.host.waitTimeout, const Duration(minutes: 2));
    expect(h.host.bootTimeout, const Duration(seconds: 90));
    expect(h.host.legacyAlgorithms, isTrue);
    expect(h.host.enabled, isFalse);
    expect(h.profile.command, 'my-unlock');
    expect(h.profile.driver, UnlockDriverKind.stdin);
    expect(h.keyFile, '/cfg/keys/default');
    expect(h.passphraseFile, '/cfg/p/nas');
    expect(h.diskPassphraseFiles, {'sdb1_crypt': '/abs/disk'});
  });

  test('minimal host gets the plan defaults', () {
    final h = parse('hosts:\n  - {name: a, preboot: a, key_file: k}')
        .hosts
        .single;
    expect(h.host.preboot, [const Endpoint('a', 22)]);
    expect(h.host.user, 'root');
    expect(h.host.postboot, const Endpoint('a', 22));
    expect(h.host.postbootCheck, PostBootCheck.sshHostKey);
    expect(h.host.waitTimeout, const Duration(minutes: 10));
    expect(h.host.bootTimeout, const Duration(minutes: 5));
    expect(h.profile, UnlockProfile.debian);
    expect(h.host.prebootKey, isNull);
  });

  test('home directory paths', () {
    final h = parse('hosts:\n  - {name: a, preboot: a, key_file: ~/k}')
        .hosts
        .single;
    expect(h.keyFile, '${Platform.environment['HOME']}/k');
  });

  test('errors name the problem', () {
    expect(() => parse('hosts: []'), configError('non-empty list'));
    expect(
      () => parse('hosts:\n  - {preboot: a, key_file: k}'),
      configError('name is required'),
    );
    expect(
      () => parse('hosts:\n  - {name: a, key_file: k}'),
      configError('preboot is required'),
    );
    expect(
      () => parse('hosts:\n  - {name: a, preboot: a}'),
      configError('key_file or key is required'),
    );
    expect(
      () => parse('hosts:\n  - {name: a, preboot: "a:x", key_file: k}'),
      configError('preboot'),
    );
    expect(
      () =>
          parse('hosts:\n  - {name: a, preboot: a, key_file: k, colour: red}'),
      configError('unknown key "colour"'),
    );
    expect(
      () => parse(
        'hosts:\n  - {name: a, preboot: a, key_file: k, wait_timeout: 5x}',
      ),
      configError('wait_timeout'),
    );
    expect(
      () => parse(
        'hosts:\n  - {name: a, preboot: a, key_file: k, preboot_host_key: MD5:x}',
      ),
      configError('preboot_host_key'),
    );
    expect(
      () => parse(
        'hosts:\n  - {name: a, preboot: a, key_file: k, postboot_check: ping}',
      ),
      configError('postboot_check'),
    );
    expect(
      () => parse(
        'hosts:\n  - {name: a, preboot: a, key_file: k, enabled: maybe}',
      ),
      configError('enabled'),
    );
    expect(
      () => parse(
        'hosts:\n  - {name: a, preboot: "a:22", key_file: k, postboot_check: tcp}',
      ),
      configError('tcp check'),
    );
    expect(
      () => parse(
        'hosts:\n  - {name: a, preboot: a, key_file: k}\n  - {name: a, preboot: b, key_file: k}',
      ),
      configError('duplicate name a'),
    );
    expect(
      () => parse('defaults: {name: x}\nhosts:\n  - {name: a}'),
      configError('unknown key "name"'),
    );
    expect(() => parse(': : :'), throwsA(isA<ConfigException>()));
  });

  test('vault labels instead of files and stdin', () {
    final c = parse('''
defaults:
  key: laptop
hosts:
  - name: a
    preboot: a
    secret: nas
    disk_secrets: {sdb1_crypt: data}
    disk_passphrase_files: {sdc1_crypt: f}
  - {name: b, preboot: b, key_file: k}
  - {name: c, preboot: c, passphrase_file: p}
''');
    final [a, b, other] = c.hosts;
    expect(a.keyLabel, 'laptop');
    expect(a.keyFile, isNull);
    expect(a.secretLabel, 'nas');
    expect(a.diskSecrets, {'sdb1_crypt': 'data'});
    expect(a.diskPassphraseFiles, {'sdc1_crypt': '/cfg/f'});
    expect(a.usesVault, isTrue);
    expect(a.usesStdin, isFalse);
    expect(b.keyFile, '/cfg/k');
    expect(b.keyLabel, isNull);
    expect(b.usesVault, isFalse);
    expect(b.usesStdin, isTrue);
    expect(other.keyLabel, 'laptop');
    expect(other.usesStdin, isFalse);
    expect(
      parse(
        'defaults: {key_file: k}\nhosts:\n  - {name: a, preboot: a, key: x}',
      ).hosts.single.keyFile,
      isNull,
    );
  });

  test('vault label errors', () {
    expect(
      () => parse('hosts:\n  - {name: a, preboot: a, key: x, key_file: k}'),
      configError('use either key_file or key'),
    );
    expect(
      () => parse(
        'hosts:\n  - {name: a, preboot: a, key: x, secret: s, passphrase_file: p}',
      ),
      configError('use either passphrase_file or secret'),
    );
    expect(
      () => parse(
        'hosts:\n  - {name: a, preboot: a, key: x, disk_secrets: {d: s}, '
        'disk_passphrase_files: {d: f}}',
      ),
      configError('disk d is in both'),
    );
    expect(
      () => parse('hosts:\n  - {name: a, preboot: a, key: "a b"}'),
      configError('key: invalid label "a b"'),
    );
    expect(
      () => parse(
        'hosts:\n  - {name: a, preboot: a, key: x, disk_secrets: {d: "-x"}}',
      ),
      configError('disk_secrets: invalid label'),
    );
    expect(
      () => parse('defaults: {secret: s}\nhosts:\n  - {name: a, preboot: a}'),
      configError('unknown key "secret"'),
    );
  });

  test('the bench example parses', () {
    final c = CliConfig.load('example/bench.yaml');
    expect(c.hosts.map((h) => h.host.name), ['target1', 'target2']);
    expect(c.hosts.first.host.preboot, [const Endpoint('target1', 2222)]);
    expect(File(c.hosts.first.keyFile!).existsSync(), isTrue);
  });

  test('durations', () {
    expect(CliConfig.parseDuration('90'), const Duration(seconds: 90));
    expect(CliConfig.parseDuration('30s'), const Duration(seconds: 30));
    expect(CliConfig.parseDuration('10m'), const Duration(minutes: 10));
    expect(CliConfig.parseDuration('1h'), const Duration(hours: 1));
    expect(() => CliConfig.parseDuration('0'), throwsFormatException);
  });
}
