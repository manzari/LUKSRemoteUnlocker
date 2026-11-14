import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../log/sanitizer.dart';
import 'clock.dart';
import 'ports.dart';
import 'unlock_driver.dart';

/// Runs the command without a pty: reads the disk name, writes the passphrase, closes stdin.
final class StdinDriver implements UnlockDriver {
  const StdinDriver();

  static final _prompt = RegExp(r'^Please unlock disk ([^\s:]+)');

  @override
  Future<DriverResult> run(DriverContext ctx) async {
    final t = ctx.timings;
    final unlocked = <String>[];
    var conn = ctx.connection;
    var passphraseSent = false;
    var reconnectedEarly = false;
    DateTime? notReadySince;
    var rounds = 0;

    while (true) {
      if (rounds >= t.maxRounds) {
        return DriverUnlocked(unlocked, 'stopped after ${t.maxRounds} rounds');
      }
      if (conn.isClosed) {
        try {
          conn = await ctx.control.guard(ctx.reconnect());
        } on SshFailure catch (e) {
          if (unlocked.isNotEmpty) {
            return DriverUnlocked(unlocked, 'server is booting ($e)');
          }
          rethrow;
        }
      }

      final r = await _round(ctx, conn);
      switch (r) {
        case _Unlocked(:final disk, :final confirmed):
          rounds++;
          passphraseSent = true;
          unlocked.add(disk);
          ctx.log.log(
            confirmed
                ? 'disk $disk unlocked'
                : 'disk $disk: exit 0 without a success line, counting it as unlocked',
          );
        case _NothingLocked():
          return DriverUnlocked(
            unlocked,
            unlocked.isEmpty
                ? 'no disk is waiting for a passphrase'
                : 'all disks unlocked',
          );
        case _NotReady(:final text):
          if (passphraseSent) {
            return DriverError(
              unlocked,
              'no unlock prompt after a passphrase was sent: $text',
            );
          }
          final now = ctx.control.clock.now();
          notReadySince ??= now;
          if (now.difference(notReadySince) >= t.notReadyMax) {
            return DriverError(
              unlocked,
              'server not ready after ${t.notReadyMax.inSeconds} s: $text',
            );
          }
          ctx.log.log('not ready, retrying in ${t.notReadyDelay.inSeconds} s');
          await ctx.control.sleep(t.notReadyDelay);
        case _Wrong(:final text):
          return DriverWrongPassphrase(unlocked, text);
        case _LostAfterPassphrase(:final disk):
          return DriverLostAfterPassphrase(unlocked, disk);
        case _LostBeforePrompt(:final reason):
          if (unlocked.isNotEmpty) {
            return DriverUnlocked(unlocked, 'server is booting ($reason)');
          }
          if (conn.isClosed && !reconnectedEarly) {
            reconnectedEarly = true;
            ctx.log.log('$reason, reconnecting');
            continue;
          }
          return DriverError(unlocked, reason);
        case _Other(:final text):
          return DriverError(unlocked, text);
      }
    }
  }

  Future<_Round> _round(DriverContext ctx, SshConnection conn) async {
    final t = ctx.timings;
    final control = ctx.control;
    final ExecSession session;
    try {
      session = await control.guard(
        conn.exec(ctx.profile.command),
        timeout: t.execTimeout,
      );
    } on SshFailure catch (e) {
      return _LostBeforePrompt('could not start the unlock command: $e');
    } on RunTimeout {
      unawaited(conn.close());
      return const _LostBeforePrompt(
        'no answer when starting the unlock command',
      );
    }

    final sanitizer = SecretSanitizer(ctx.secrets.allSecrets);
    final prompt = Completer<String>();
    final out = _Lines('stdout', sanitizer.newStream(), ctx.log, (line) {
      final m = _prompt.firstMatch(line);
      if (m != null && !prompt.isCompleted) prompt.complete(m[1]);
    });
    final err = _Lines('stderr', sanitizer.newStream(), ctx.log, null);
    final outSub = session.stdout.listen(out.add, onError: (Object _) {});
    final errSub = session.stderr.listen(err.add, onError: (Object _) {});
    final streamsDone = Future.wait([
      outSub.asFuture<void>().catchError((Object _) {}),
      errSub.asFuture<void>().catchError((Object _) {}),
    ]);
    final exit = session.exitCode;

    String? disk;
    var wrote = false;
    int? code;
    try {
      disk = await control.guard(
        Future.any<String?>([prompt.future, exit.then((_) => null)]),
        timeout: t.execTimeout,
      );
      if (disk != null) {
        ctx.log.log('disk $disk: sending passphrase');
        wrote = true;
        session.write(ctx.secrets.passphraseFor(disk));
        await session.closeStdin();
      }
      code = await control.guard(exit, timeout: t.execTimeout);
      await control.guard(streamsDone, timeout: const Duration(seconds: 2));
    } on RunTimeout {
      session.close();
      if (code == null) {
        return wrote
            ? _LostAfterPassphrase(disk!)
            : const _LostBeforePrompt(
                'no unlock prompt and no exit within the timeout',
              );
      }
    } on RunCancelled {
      session.close();
      rethrow;
    } finally {
      out.close();
      err.close();
      await outSub.cancel();
      await errSub.cancel();
    }

    final text = '${err.text}\n${out.text}';
    if (code == null) {
      return wrote
          ? _LostAfterPassphrase(disk!)
          : const _LostBeforePrompt('session closed without an exit status');
    }
    if (code == 0) {
      return disk == null
          ? const _NothingLocked()
          : _Unlocked(disk, text.contains('set up successfully'));
    }
    if (text.contains('maximum number of tries exceeded')) {
      return _Wrong(_lastLine(text, 'maximum number of tries exceeded'));
    }
    if (text.contains('bad password or options')) {
      return _Wrong(_lastLine(text, 'bad password or options'));
    }
    for (final s in const [
      'Try again later',
      'Timeout reached while waiting for askpass',
    ]) {
      if (text.contains(s)) return _NotReady(_lastLine(text, s));
    }
    final last = text.trim().split('\n').where((l) => l.trim().isNotEmpty);
    return _Other(
      'exit $code${last.isEmpty ? ' without output' : ': ${last.last.trim()}'}',
    );
  }

  static String _lastLine(String text, String needle) =>
      text.split('\n').lastWhere((l) => l.contains(needle)).trim();
}

/// Sanitized line splitter for one output stream.
final class _Lines {
  _Lines(this.name, this.sanitizer, this.log, this.onLine);

  final String name;
  final StreamSanitizer sanitizer;
  final RunLog log;
  final void Function(String line)? onLine;
  final _all = StringBuffer();
  final _partial = <int>[];

  String get text => _all.toString();

  void add(Uint8List chunk) => _feed(sanitizer.add(chunk));

  void close() {
    _feed(sanitizer.close());
    if (_partial.isNotEmpty) _emit(List.of(_partial));
    _partial.clear();
  }

  void _feed(List<int> bytes) {
    for (final b in bytes) {
      if (b == 0x0a) {
        _emit(List.of(_partial));
        _partial.clear();
      } else {
        _partial.add(b);
      }
    }
  }

  void _emit(List<int> bytes) {
    final line = utf8.decode(bytes, allowMalformed: true).replaceAll('\r', '');
    _all.writeln(line);
    if (line.trim().isEmpty) return;
    log.log('$name: $line');
    onLine?.call(line);
  }
}

sealed class _Round {
  const _Round();
}

final class _Unlocked extends _Round {
  const _Unlocked(this.disk, this.confirmed);

  final String disk;
  final bool confirmed;
}

final class _NothingLocked extends _Round {
  const _NothingLocked();
}

final class _NotReady extends _Round {
  const _NotReady(this.text);

  final String text;
}

final class _Wrong extends _Round {
  const _Wrong(this.text);

  final String text;
}

final class _LostAfterPassphrase extends _Round {
  const _LostAfterPassphrase(this.disk);

  final String disk;
}

final class _LostBeforePrompt extends _Round {
  const _LostBeforePrompt(this.reason);

  final String reason;
}

final class _Other extends _Round {
  const _Other(this.text);

  final String text;
}
