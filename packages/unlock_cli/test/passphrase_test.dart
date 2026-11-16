import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:unlock_cli/unlock_cli.dart';

void main() {
  late StreamController<List<int>> input;
  late StreamController<Object?> interrupts;
  late HiddenLineReader reader;
  late StringBuffer err;
  late List<bool> echoCalls;
  var echo = true;

  setUp(() {
    input = StreamController<List<int>>();
    interrupts = StreamController<Object?>.broadcast();
    err = StringBuffer();
    echoCalls = [];
    echo = true;
    reader = HiddenLineReader(
      input.stream,
      interrupts: () => interrupts.stream,
      echo: () => echo,
      setEcho: (on) {
        echoCalls.add(on);
        echo = on;
      },
    );
  });

  tearDown(() async {
    await reader.close();
    await input.close();
    await interrupts.close();
  });

  test('reads lines with echo off, keeps typed-ahead bytes', () async {
    final first = reader.read('Password: ', err);
    input
      ..add(utf8.encode('FAKE-one'))
      ..add(utf8.encode('\nFAKE-two\nFA'));
    expect(utf8.decode(await first), 'FAKE-one');
    expect(echoCalls, [false, true]);
    expect(utf8.decode(await reader.read('Again: ', err)), 'FAKE-two');
    final third = reader.read('Third: ', err);
    input.add(utf8.encode('KE-3\n'));
    expect(utf8.decode(await third), 'FAKE-3');
    expect(err.toString(), 'Password: \nAgain: \nThird: \n');
    expect(echo, isTrue);
  });

  test('end of input ends the line', () async {
    final line = reader.read('P: ', err);
    input.add(utf8.encode('FAKE-partial'));
    await input.close();
    expect(utf8.decode(await line), 'FAKE-partial');
    expect(await reader.read('P: ', err), isEmpty);
  });

  test('Ctrl-C restores echo and fails with exit status 130', () async {
    final line = reader.read('Password: ', err);
    input.add(utf8.encode('FAKE-half'));
    await Future<void>.delayed(Duration.zero);
    expect(echo, isFalse);
    interrupts.add(null);
    await expectLater(
      line,
      throwsA(
        isA<CliExit>().having((e) => e.code, 'code', exitInterrupted),
      ),
    );
    expect(echo, isTrue);
    expect(echoCalls, [false, true]);
    expect(interrupts.hasListener, isFalse);
  });

  test('a line over 4096 bytes is refused, echo restored', () async {
    final line = reader.read('P: ', err);
    input.add([...List.filled(5000, 0x41), 0x0a]);
    await expectLater(
      line,
      throwsA(isA<CliExit>().having((e) => e.code, 'code', exitUsage)),
    );
    expect(echo, isTrue);
  });

  test('the previous echo mode is restored, not forced on', () async {
    echo = false;
    final line = reader.read('P: ', err);
    input.add(utf8.encode('x\n'));
    await line;
    expect(echoCalls, [false, false]);
  });
}
