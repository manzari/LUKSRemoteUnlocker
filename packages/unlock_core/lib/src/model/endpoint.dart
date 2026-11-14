import 'package:meta/meta.dart';

/// A host name or IP address with a TCP port.
@immutable
final class Endpoint {
  const Endpoint(this.host, this.port);

  final String host;
  final int port;

  /// Parses `host`, `host:port`, `[v6]` or `[v6]:port`.
  factory Endpoint.parse(String text, {int defaultPort = 22}) {
    final s = text.trim();
    String host;
    String? port;
    if (s.startsWith('[')) {
      final end = s.indexOf(']');
      if (end < 0) throw FormatException('Bad endpoint', text);
      host = s.substring(1, end);
      final rest = s.substring(end + 1);
      if (rest.isNotEmpty) {
        if (!rest.startsWith(':')) throw FormatException('Bad endpoint', text);
        port = rest.substring(1);
      }
    } else if (':'.allMatches(s).length == 1) {
      final i = s.indexOf(':');
      host = s.substring(0, i);
      port = s.substring(i + 1);
    } else {
      host = s;
    }
    final p = port == null ? defaultPort : int.tryParse(port);
    if (host.isEmpty || p == null || p < 1 || p > 65535) {
      throw FormatException('Bad endpoint', text);
    }
    return Endpoint(host, p);
  }

  factory Endpoint.fromJson(Map<String, Object?> json) =>
      Endpoint(json['host']! as String, json['port']! as int);

  Map<String, Object?> toJson() => {'host': host, 'port': port};

  @override
  bool operator ==(Object other) =>
      other is Endpoint && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => host.contains(':') ? '[$host]:$port' : '$host:$port';
}
