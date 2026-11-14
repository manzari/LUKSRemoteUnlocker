import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

const fakeKeyPass = 'fake-key-pass';

/// Runs `ssh-keygen` in a private temp directory.
class Keygen {
  Keygen(this.dir);

  final Directory dir;
  var _count = 0;

  static Keygen create() =>
      Keygen(Directory.systemTemp.createTempSync('unlock_core_keys_'));

  void dispose() => dir.deleteSync(recursive: true);

  String path(String name) => '${dir.path}/$name';

  Future<String> run(List<String> args) async {
    final result = await Process.run('ssh-keygen', args);
    if (result.exitCode != 0) {
      fail('ssh-keygen ${args.join(' ')} failed: ${result.stderr}');
    }
    return (result.stdout as String).trim();
  }

  /// New key file; returns its path.
  Future<String> newKey(
    String type, {
    int? bits,
    String passphrase = '',
    String? format,
    String comment = 'test-key',
    List<String> extra = const [],
    String? name,
  }) async {
    final file = path(name ?? 'k${_count++}_$type');
    await run([
      '-q',
      '-t',
      type,
      if (bits != null) ...['-b', '$bits'],
      if (format != null) ...['-m', format],
      ...extra,
      '-N',
      passphrase,
      '-C',
      comment,
      '-f',
      file,
    ]);
    return file;
  }

  /// Writes private key bytes with mode 600, as ssh-keygen requires.
  Future<String> writePrivate(Uint8List pem) async {
    final file = path('w${_count++}');
    File(file).writeAsBytesSync(pem, flush: true);
    final chmod = await Process.run('chmod', ['600', file]);
    expect(chmod.exitCode, 0);
    return file;
  }

  Future<String> publicLine(String file, {String passphrase = ''}) =>
      run(['-y', '-P', passphrase, '-f', file]);

  Future<String> fingerprint(String file) async =>
      (await run(['-l', '-E', 'sha256', '-f', file])).split(' ')[1];

  Uint8List read(String file) => File(file).readAsBytesSync();
}
