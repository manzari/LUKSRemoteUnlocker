import 'dart:async';
import 'dart:io';

import '../engine/ports.dart';

final class TcpReachability implements Reachability {
  const TcpReachability();

  @override
  Future<bool> tcpOpen(String host, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }
}
