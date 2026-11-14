import 'dart:io';

import 'package:unlock_cli/unlock_cli.dart';

void main(List<String> arguments) {
  exitCode = runCli(arguments, out: stdout, err: stderr);
}
