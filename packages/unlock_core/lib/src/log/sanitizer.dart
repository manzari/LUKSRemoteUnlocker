import 'dart:convert';
import 'dart:typed_data';

const redactedMarker = '[redacted]';

/// Replaces every occurrence of a secret's bytes in output.
final class SecretSanitizer {
  SecretSanitizer(Iterable<Uint8List> secrets)
    : _secrets = [
        for (final s in secrets)
          if (s.isNotEmpty) s,
      ]..sort((a, b) => b.length - a.length);

  final List<Uint8List> _secrets;

  static final _marker = utf8.encode(redactedMarker);

  /// Sanitizes a complete byte string.
  Uint8List bytes(List<int> data) {
    final stream = newStream();
    return Uint8List.fromList([...stream.add(data), ...stream.close()]);
  }

  /// Sanitizes a complete message, including secrets in their UTF-8 form.
  String text(String message) {
    if (_secrets.isEmpty) return message;
    return utf8.decode(bytes(utf8.encode(message)), allowMalformed: true);
  }

  /// A sanitizer for one byte stream that also catches secrets split across chunks.
  StreamSanitizer newStream() => StreamSanitizer._(_secrets);
}

final class StreamSanitizer {
  StreamSanitizer._(this._secrets);

  final List<Uint8List> _secrets;
  List<int> _pending = const [];

  /// Returns the bytes that are safe to emit so far.
  List<int> add(List<int> chunk) {
    _pending = [..._pending, ...chunk];
    return _drain(last: false);
  }

  /// Returns the remaining bytes at end of stream.
  List<int> close() => _drain(last: true);

  List<int> _drain({required bool last}) {
    final p = _pending;
    final out = <int>[];
    var i = 0;
    scan:
    while (i < p.length) {
      final tail = p.length - i;
      // longest first, so a longer secret still arriving beats a shorter full match
      for (final s in _secrets) {
        if (s.length <= tail) {
          if (_matchesAt(p, i, s, s.length)) {
            out.addAll(SecretSanitizer._marker);
            i += s.length;
            continue scan;
          }
        } else if (!last && _matchesAt(p, i, s, tail)) {
          break scan;
        }
      }
      out.add(p[i]);
      i++;
    }
    _pending = p.sublist(i);
    return out;
  }

  static bool _matchesAt(List<int> p, int at, Uint8List s, int n) {
    if (at + n > p.length) return false;
    for (var k = 0; k < n; k++) {
      if (p[at + k] != s[k]) return false;
    }
    return true;
  }
}
