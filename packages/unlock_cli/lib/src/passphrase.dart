import 'dart:io';
import 'dart:typed_data';

abstract interface class PassphraseReader {
  /// Reads from file descriptor [fd] as-is, else from stdin without one trailing newline.
  Uint8List read({int? fd, required StringSink prompt});
}

final class TerminalPassphraseReader implements PassphraseReader {
  const TerminalPassphraseReader();

  @override
  Uint8List read({int? fd, required StringSink prompt}) {
    if (fd != null) return File('/dev/fd/$fd').readAsBytesSync();
    final bytes = BytesBuilder(copy: false);
    if (stdin.hasTerminal) {
      prompt.write('Passphrase: ');
      final echo = stdin.echoMode;
      stdin.echoMode = false;
      try {
        for (
          var b = stdin.readByteSync();
          b != -1 && b != 0x0a;
          b = stdin.readByteSync()
        ) {
          bytes.addByte(b);
        }
      } finally {
        stdin.echoMode = echo;
        prompt.writeln();
      }
      return bytes.takeBytes();
    }
    for (var b = stdin.readByteSync(); b != -1; b = stdin.readByteSync()) {
      bytes.addByte(b);
    }
    final all = bytes.takeBytes();
    return all.isNotEmpty && all.last == 0x0a
        ? Uint8List.sublistView(all, 0, all.length - 1)
        : all;
  }
}
