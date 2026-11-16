import 'dart:io';

import 'package:unlock_cli/unlock_cli.dart';

Future<void> main(List<String> arguments) async {
  final code = await runGuarded(
    () => runCli(arguments, out: stdout, err: stderr),
    stderr,
  );
  await Future.wait([stdout.flush(), stderr.flush()]);
  exit(code);
}
