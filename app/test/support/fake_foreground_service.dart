import 'package:luks_remote_unlocker/run/foreground_service_lifecycle.dart';

/// Records plugin calls; like the plugin, update and stop fail while nothing runs.
final class FakeForegroundService implements ForegroundService {
  NotificationAccess access = NotificationAccess.denied;

  /// What the user picks in the system dialog.
  NotificationAccess answer = NotificationAccess.granted;
  bool running = false;
  final calls = <String>[];

  /// Calls by name (check, request, isRunning, start, update, stop) that throw.
  final failing = <String>{};

  void _call(String name, [String? args]) {
    if (name != 'isRunning') calls.add(args == null ? name : '$name $args');
    if (failing.contains(name)) throw StateError('FAKE plugin failure');
  }

  void _requireRunning() {
    if (!running) throw StateError('FAKE service not started');
  }

  @override
  Future<NotificationAccess> notificationAccess() async {
    _call('check');
    return access;
  }

  @override
  Future<NotificationAccess> requestNotificationAccess() async {
    _call('request');
    return access = answer;
  }

  @override
  Future<bool> isRunning() async {
    _call('isRunning');
    return running;
  }

  @override
  Future<void> start({required String title, required String text}) async {
    _call('start', '$title | $text');
    if (running) throw StateError('FAKE service already started');
    running = true;
  }

  @override
  Future<void> update({required String title, required String text}) async {
    _call('update', '$title | $text');
    _requireRunning();
  }

  @override
  Future<void> stop() async {
    _call('stop');
    _requireRunning();
    running = false;
  }
}
