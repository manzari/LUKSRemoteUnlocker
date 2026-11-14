import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unlock_core/engine.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

String run(SecretSanitizer s, List<String> chunks) {
  final stream = s.newStream();
  final out = <int>[];
  for (final c in chunks) {
    out.addAll(stream.add(utf8.encode(c)));
  }
  out.addAll(stream.close());
  return utf8.decode(out);
}

void main() {
  final s = SecretSanitizer([b('fake-secret'), b('fake-sec-2')]);

  test('replaces every occurrence', () {
    expect(s.text('a fake-secret b fake-secret'), 'a [redacted] b [redacted]');
    expect(s.text('fake-sec-2fake-secret'), '[redacted][redacted]');
  });

  test('leaves other text alone', () {
    expect(s.text('fake-sec fake-secre'), 'fake-sec fake-secre');
    expect(s.text(''), '');
  });

  test('a secret split across chunk boundaries', () {
    expect(run(s, ['xx fake-', 'sec', 'ret yy']), 'xx [redacted] yy');
    expect(
      run(s, ['f', 'a', 'k', 'e', '-', 's', 'e', 'c', 'r', 'e', 't']),
      '[redacted]',
    );
  });

  test('holds back only a possible prefix and releases it at the end', () {
    final stream = s.newStream();
    expect(utf8.decode(stream.add(b('abc fake-se'))), 'abc ');
    expect(utf8.decode(stream.add(b('x'))), 'fake-sex');
    expect(utf8.decode(stream.add(b(' fake'))), ' ');
    expect(utf8.decode(stream.close()), 'fake');
  });

  test('longest secret wins when one is a prefix of another', () {
    final t = SecretSanitizer([b('fake'), b('fake-longer')]);
    expect(t.text('fake-longer fake'), '[redacted] [redacted]');
    expect(run(t, ['fake-lo', 'nger']), '[redacted]');
  });

  test('non-UTF-8 secrets are matched as bytes', () {
    final t = SecretSanitizer([
      Uint8List.fromList([0xff, 0x00, 0xfe]),
    ]);
    final stream = t.newStream();
    final out = [
      ...stream.add([1, 0xff]),
      ...stream.add([0x00, 0xfe, 2]),
      ...stream.close(),
    ];
    expect(out, [1, ...utf8.encode(redactedMarker), 2]);
  });

  test('empty secrets are ignored', () {
    expect(SecretSanitizer([Uint8List(0)]).text('abc'), 'abc');
  });
}
