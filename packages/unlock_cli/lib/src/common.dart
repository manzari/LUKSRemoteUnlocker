import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';

const String executableName = 'luks-unlock';
const String cliVersion = '0.1.0';

const int exitFailure = 1;
const int exitUsage = 64;

/// Ends a command: [message] goes to stderr and the process exits with [code].
final class CliExit implements Exception {
  const CliExit(this.code, this.message, {this.helpFor});

  const CliExit.failure(String message) : this(exitFailure, message);

  /// [helpFor] names the command whose `--help` is suggested, e.g. `key generate`.
  const CliExit.usage(String message, [String? helpFor])
    : this(exitUsage, message, helpFor: helpFor);

  final int code;
  final String message;
  final String? helpFor;

  void report(StringSink err) {
    err.writeln('$executableName: $message');
    if (helpFor != null) {
      err.writeln("Run '$executableName $helpFor --help' for usage.");
    }
  }

  @override
  String toString() => message;
}

void wipe(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);

bool sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Number of UTF-8 characters, counted without decoding to a String.
int utf8Length(Uint8List bytes) => bytes.where((b) => b & 0xc0 != 0x80).length;

/// The value of a file-descriptor option, or null when it is absent.
int? fdOption(ArgResults args, String name, String helpFor) {
  final text = args.option(name);
  if (text == null) return null;
  final fd = int.tryParse(text);
  if (fd == null || fd < 0) {
    throw CliExit.usage(
      '--$name needs a file descriptor number, not $text',
      helpFor,
    );
  }
  return fd;
}

String osMessage(FileSystemException e) => e.osError?.message ?? e.message;
