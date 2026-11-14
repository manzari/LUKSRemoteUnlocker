import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unlock_cli/unlock_cli.dart';
import 'package:unlock_core/unlock_core.dart';

const fakeVaultPassword = 'FAKE-vault-pass-one';
const fakeNewPassword = 'FAKE-vault-pass-two';
const fakeLuksPass = 'FAKE-luks-secret-xyzzy';
const fakeKeyPass = 'FAKE-key-file-pass';

const tinyArgon = VaultTuning(
  params: Argon2Params(memoryKiB: 64, iterations: 1, parallelism: 1),
);

Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

/// Answers terminal prompts in order and serves file descriptors from a map.
final class ScriptedInput implements SecretInput {
  bool terminal = true;
  final answers = <String>[];
  final prompts = <String>[];
  final fds = <int, String>{};

  @override
  bool get hasTerminal => terminal;

  @override
  Uint8List prompt(String label, StringSink err) {
    prompts.add(label);
    if (answers.isEmpty) fail('unexpected prompt "$label"');
    return bytesOf(answers.removeAt(0));
  }

  @override
  Uint8List readFd(int fd) {
    final v = fds[fd];
    if (v == null) throw FileSystemException('Bad file descriptor', '$fd');
    return bytesOf(v);
  }
}

/// Fake pre-boot servers: records the key and passphrases each host receives, then "boots" it.
final class FakeWorld implements Reachability, SshConnector, UnlockDriver {
  final booted = <String>{};
  final keyBuffers = <Uint8List>[];
  final secretBuffers = <Uint8List>[];
  final keys = <String, String>{};
  final secrets = <String, Map<String, String>>{};

  UnlockEngine engine(HostKeyPrompt? prompt) => UnlockEngine(
    reachability: this,
    ssh: this,
    hostKeyPrompt: prompt,
    drivers: {UnlockDriverKind.stdin: this},
    timings: const EngineTimings(
      pollInitial: Duration(milliseconds: 10),
      bootPollInterval: Duration(milliseconds: 10),
    ),
  );

  @override
  Future<bool> tcpOpen(String host, int port, Duration timeout) async =>
      port == 2222 || booted.contains(host);

  @override
  Future<SshConnection> connect(
    Endpoint endpoint, {
    required String user,
    required Uint8List privateKeyPem,
    required HostKeyPolicy policy,
    required bool legacyAlgorithms,
    required Duration timeout,
  }) async {
    keyBuffers.add(privateKeyPem);
    keys[endpoint.host] = latin1.decode(privateKeyPem);
    return _Connection(endpoint.host);
  }

  @override
  Future<HostKey> probeHostKey(
    Endpoint endpoint, {
    required Duration timeout,
    required bool legacyAlgorithms,
    String? preferType,
  }) async => throw const SshUnreachable('refused');

  @override
  Future<DriverResult> run(DriverContext context) async {
    final host = (context.connection as _Connection).host;
    secrets[host] = {
      for (final disk in ['sda3_crypt', 'sdb1_crypt'])
        disk: utf8.decode(context.secrets.passphraseFor(disk)),
    };
    secretBuffers.addAll(context.secrets.allSecrets);
    booted.add(host);
    return const DriverUnlocked(['sda3_crypt'], 'unlocked');
  }
}

final class _Connection implements SshConnection {
  _Connection(this.host);

  final String host;

  @override
  Future<ExecSession> exec(String command) =>
      throw const SshConnectionLost('fake');

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async {}
}

/// Private key text, its base64 body lines and the raw Ed25519 seed.
List<(String, Uint8List)> keyMaterial(Uint8List pem, String publicLine) {
  final lines = ascii
      .decode(pem)
      .split('\n')
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .toList();
  final blob = base64.decode(lines.join());
  final pub = base64.decode(publicLine.split(' ')[1]);
  final pubKey = pub.sublist(pub.length - 32);
  final seeds = <Uint8List>[];
  for (var i = 0; i + 68 <= blob.length; i++) {
    if (blob[i] == 0 && blob[i + 1] == 0 && blob[i + 2] == 0) {
      if (blob[i + 3] == 64 && _equal(blob.sublist(i + 36, i + 68), pubKey)) {
        seeds.add(blob.sublist(i + 4, i + 36));
      }
    }
  }
  expect(seeds, hasLength(1), reason: 'Ed25519 seed not found in the key');
  return [
    ('private key', Uint8List.fromList(pem)),
    for (final l in lines) ('private key line', bytesOf(l)),
    ('private key seed', seeds.single),
  ];
}

bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Fails if [secret] occurs in [haystack] raw, as hex, or as base64 at any alignment.
void expectAbsent(List<int> haystack, Uint8List secret, String what) {
  expect(_indexOf(haystack, secret), -1, reason: '$what found raw');
  final hex = secret.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  for (final form in [hex, hex.toUpperCase()]) {
    expect(_indexOf(haystack, bytesOf(form)), -1, reason: '$what as hex');
  }
  for (var offset = 0; offset < 3 && offset < secret.length; offset++) {
    final part = secret.sublist(offset);
    if (part.length < 3) break;
    final stable = base64.encode(part).substring(0, (part.length ~/ 3) * 4);
    for (final form in [
      stable,
      stable.replaceAll('+', '-').replaceAll('/', '_'),
    ]) {
      expect(
        _indexOf(haystack, bytesOf(form)),
        -1,
        reason: '$what as base64 (offset $offset)',
      );
    }
  }
}

int _indexOf(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
