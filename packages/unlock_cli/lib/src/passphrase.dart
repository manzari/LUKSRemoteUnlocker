import 'dart:io';
import 'dart:typed_data';

import 'common.dart';

abstract interface class PassphraseReader {
  /// Reads from file descriptor [fd] as-is, else from stdin without one trailing newline.
  Uint8List read({int? fd, required StringSink prompt});
}

final class TerminalPassphraseReader implements PassphraseReader {
  const TerminalPassphraseReader();

  @override
  Uint8List read({int? fd, required StringSink prompt}) {
    if (fd != null) return File('/dev/fd/$fd').readAsBytesSync();
    if (stdinIsTerminal()) return readHiddenLine('Passphrase: ', prompt);
    final bytes = BytesBuilder(copy: false);
    for (var b = stdin.readByteSync(); b != -1; b = stdin.readByteSync()) {
      bytes.addByte(b);
    }
    final all = bytes.takeBytes();
    return all.isNotEmpty && all.last == 0x0a
        ? Uint8List.sublistView(all, 0, all.length - 1)
        : all;
  }
}

/// Vault passwords, new secrets and key passphrases: typed on a terminal or read from a file descriptor.
abstract interface class SecretInput {
  bool get hasTerminal;

  /// One line typed on the terminal with echo off, without the newline.
  Uint8List prompt(String label, StringSink err);

  /// Everything readable from file descriptor [fd], byte for byte.
  Uint8List readFd(int fd);
}

final class TerminalSecretInput implements SecretInput {
  const TerminalSecretInput();

  @override
  bool get hasTerminal => stdinIsTerminal();

  @override
  Uint8List prompt(String label, StringSink err) => readHiddenLine(label, err);

  @override
  Uint8List readFd(int fd) => File('/dev/fd/$fd').readAsBytesSync();
}

bool stdinIsTerminal() => _ttyEcho() != null;

/// Echo mode of stdin, or null unless it is a real tty (Dart's hasTerminal is also true for /dev/null).
bool? _ttyEcho() {
  if (!stdin.hasTerminal) return null;
  try {
    return stdin.echoMode;
  } on StdinException {
    return null;
  }
}

/// Reads stdin up to Enter with echo off; the line buffer is overwritten afterwards.
Uint8List readHiddenLine(String label, StringSink err) {
  final buf = Uint8List(4096);
  var n = 0;
  var tooLong = false;
  err.write(label);
  final echo = stdin.echoMode;
  stdin.echoMode = false;
  try {
    for (
      var b = stdin.readByteSync();
      b != -1 && b != 0x0a;
      b = stdin.readByteSync()
    ) {
      if (n == buf.length) {
        tooLong = true;
      } else {
        buf[n++] = b;
      }
    }
  } finally {
    stdin.echoMode = echo;
    err.writeln();
  }
  final line = Uint8List.fromList(Uint8List.sublistView(buf, 0, n));
  wipe(buf);
  if (tooLong) {
    wipe(line);
    throw const CliExit.usage('the input line is longer than 4096 bytes');
  }
  return line;
}
