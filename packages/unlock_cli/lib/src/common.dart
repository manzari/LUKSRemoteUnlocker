import 'dart:async';
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
    err.writeln('$executableName: ${terminalSafe(message)}');
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

/// Octal mode of [path] if group or others have any access, as OpenSSH checks private keys; else null.
String? openToOthers(String path) {
  if (Platform.isWindows) return null;
  final stat = FileStat.statSync(path);
  if (stat.type == FileSystemEntityType.notFound) return null;
  final mode = stat.mode & 0x1ff;
  return mode & 0x3f == 0 ? null : mode.toRadixString(8).padLeft(4, '0');
}

final _unsafe = RegExp(
  r'[\x00-\x08\x0a-\x1f\x7f-\x9f\u2028\u2029\u202a-\u202e\u2066-\u2069]',
);

/// Shows control characters as `\xNN` or `\uNNNN` (tab stays), so text from a server cannot drive the terminal.
String terminalSafe(String text) {
  if (!_unsafe.hasMatch(text)) return text;
  return text.replaceAllMapped(_unsafe, (m) {
    final c = m[0]!.codeUnitAt(0);
    return c < 0x100
        ? '\\x${c.toRadixString(16).padLeft(2, '0')}'
        : '\\u${c.toRadixString(16).padLeft(4, '0')}';
  });
}

/// Runs [body]; an unexpected error, also an uncaught asynchronous one, becomes one line on [err] and exit status 1.
Future<int> runGuarded(Future<int> Function() body, StringSink err) {
  final result = Completer<int>();
  runZonedGuarded(
    () async {
      final code = await body();
      if (!result.isCompleted) result.complete(code);
    },
    (e, _) {
      if (result.isCompleted) return;
      final text = e is FormatException ? 'FormatException: ${e.message}' : '$e';
      final line = terminalSafe(text);
      err.writeln(
        '$executableName: unexpected error: '
        '${line.length > 500 ? '${line.substring(0, 500)}...' : line}',
      );
      result.complete(exitFailure);
    },
  );
  return result.future;
}
