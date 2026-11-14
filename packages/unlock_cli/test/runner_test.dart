import 'package:test/test.dart';
import 'package:unlock_cli/unlock_cli.dart';

void main() {
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    out = StringBuffer();
    err = StringBuffer();
  });

  test('prints usage without arguments', () {
    expect(runCli(const [], out: out, err: err), 0);
    expect(out.toString(), contains('Usage: luks-unlock'));
    expect(err.toString(), isEmpty);
  });

  test('prints the version', () {
    expect(runCli(const ['--version'], out: out, err: err), 0);
    expect(out.toString(), startsWith('luks-unlock $cliVersion'));
  });

  test('rejects unknown options with a usage exit code', () {
    expect(runCli(const ['--nope'], out: out, err: err), exitUsage);
    expect(err.toString(), contains('Usage: luks-unlock'));
  });
}
