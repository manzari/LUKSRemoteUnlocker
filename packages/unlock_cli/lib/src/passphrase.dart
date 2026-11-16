import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'common.dart';

/// Exit status after Ctrl-C at a password prompt.
const int exitInterrupted = 130;

abstract interface class PassphraseReader {
  /// Reads from file descriptor [fd] as-is, else from stdin without one trailing newline.
  Future<Uint8List> read({int? fd, required StringSink prompt});
}

final class TerminalPassphraseReader implements PassphraseReader {
  const TerminalPassphraseReader();

  @override
  Future<Uint8List> read({int? fd, required StringSink prompt}) async {
    if (fd != null) return File('/dev/fd/$fd').readAsBytesSync();
    if (stdinIsTerminal()) {
      return HiddenLineReader.terminal.read('Passphrase: ', prompt);
    }
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
  Future<Uint8List> prompt(String label, StringSink err);

  /// Everything readable from file descriptor [fd], byte for byte.
  Uint8List readFd(int fd);
}

final class TerminalSecretInput implements SecretInput {
  const TerminalSecretInput();

  @override
  bool get hasTerminal => stdinIsTerminal();

  @override
  Future<Uint8List> prompt(String label, StringSink err) =>
      HiddenLineReader.terminal.read(label, err);

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

/// Reads lines with echo off from a stream that takes one listener, like stdin.
///
/// Reads asynchronously so that Ctrl-C is seen: echo is restored and the read throws a [CliExit].
final class HiddenLineReader {
  HiddenLineReader(
    this._input, {
    required this._interrupts,
    required this._echo,
    required this._setEcho,
  });

  static final terminal = HiddenLineReader(
    stdin,
    interrupts: ProcessSignal.sigint.watch,
    echo: () => stdin.echoMode,
    setEcho: (on) => stdin.echoMode = on,
  );

  static const int maxLength = 4096;

  final Stream<List<int>> _input;
  final Stream<Object?> Function() _interrupts;
  final bool Function() _echo;
  final void Function(bool on) _setEcho;

  StreamSubscription<List<int>>? _subscription;
  final _chunks = <Uint8List>[];
  var _offset = 0;
  var _ended = false;
  Completer<void>? _wake;

  /// One line up to Enter, without the newline; the buffers it used are overwritten.
  Future<Uint8List> read(String label, StringSink err) async {
    err.write(label);
    final echo = _echo();
    _setEcho(false);
    final interrupted = Completer<void>();
    StreamSubscription<Object?>? sigint;
    try {
      sigint = _interrupts().listen((_) {
        if (!interrupted.isCompleted) interrupted.complete();
      });
    } on SignalException {
      sigint = null;
    }
    final buf = Uint8List(maxLength);
    var n = 0;
    var tooLong = false;
    try {
      (_subscription ??= _input.listen(
        _onData,
        onError: (Object _) => _onDone(),
        onDone: _onDone,
      )).resume();
      while (true) {
        if (_chunks.isEmpty) {
          if (_ended) break;
          final wake = _wake = Completer<void>();
          await Future.any([wake.future, interrupted.future]);
          if (interrupted.isCompleted) {
            throw const CliExit(exitInterrupted, 'interrupted');
          }
          continue;
        }
        final chunk = _chunks.first;
        var i = _offset;
        for (; i < chunk.length && chunk[i] != 0x0a; i++) {
          if (n == buf.length) {
            tooLong = true;
          } else {
            buf[n++] = chunk[i];
          }
        }
        if (i == chunk.length) {
          _dropChunk();
          continue;
        }
        _offset = i + 1;
        if (_offset == chunk.length) _dropChunk();
        break;
      }
      if (tooLong) {
        throw const CliExit.usage('the input line is longer than 4096 bytes');
      }
      return Uint8List.fromList(Uint8List.sublistView(buf, 0, n));
    } finally {
      wipe(buf);
      _subscription?.pause();
      await sigint?.cancel();
      _setEcho(echo);
      err.writeln();
    }
  }

  /// Stops listening to the input; stdin cannot be listened to again.
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onData(List<int> data) {
    _chunks.add(Uint8List.fromList(data));
    if (data is Uint8List) wipe(data);
    _wakeUp();
  }

  void _onDone() {
    _ended = true;
    _wakeUp();
  }

  void _wakeUp() {
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  void _dropChunk() {
    wipe(_chunks.removeAt(0));
    _offset = 0;
  }
}
