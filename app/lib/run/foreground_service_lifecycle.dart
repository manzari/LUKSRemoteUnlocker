import 'package:flutter/foundation.dart';

import 'run_lifecycle.dart';

enum NotificationAccess {
  granted,
  denied,

  /// Denied for good; the platform shows no dialog any more.
  blocked,
}

/// The plugin calls behind [ForegroundServiceLifecycle], so tests can use a fake.
abstract interface class ForegroundService {
  Future<NotificationAccess> notificationAccess();

  /// Shows the system dialog where the platform still allows it.
  Future<NotificationAccess> requestNotificationAccess();

  Future<bool> isRunning();

  Future<void> start({required String title, required String text});

  Future<void> update({required String title, required String text});

  Future<void> stop();
}

/// Keeps the process, CPU and Wi-Fi awake during a run; plugin errors never reach the run.
final class ForegroundServiceLifecycle extends RunLifecycle {
  ForegroundServiceLifecycle(this._service);

  static const notificationsOffNotice =
      'Notifications are off, so the progress shows only in the app. The run '
      'still goes on with the screen off.';

  final ForegroundService _service;
  String? _runId;
  var _asked = false;
  var _notificationsOff = false;

  @override
  String? get notice => _notificationsOff ? notificationsOffNotice : null;

  /// Stops a service whose run died with the Flutter engine (process kept alive by the service).
  Future<void> stopLeftover() => _guard('cleanup', () async {
    if (await _service.isRunning() && _runId == null) await _service.stop();
  });

  /// Asks for the notification permission once per app session; a denial does not block the run.
  @override
  Future<void> runRequested() => _guard('permission', () async {
    var access = await _service.notificationAccess();
    if (access == NotificationAccess.denied && !_asked) {
      _asked = true;
      access = await _service.requestNotificationAccess();
    }
    _notificationsOff = access != NotificationAccess.granted;
  });

  @override
  Future<void> runStarted(RunActivity run) async {
    if (_runId == run.runId) return;
    _runId = run.runId;
    await _guard('start', () async {
      if (await _service.isRunning()) {
        await _service.update(title: _title(run), text: _text(run));
      } else {
        await _service.start(title: _title(run), text: _text(run));
      }
    });
  }

  @override
  Future<void> runProgress(RunActivity run) async {
    if (run.runId != _runId) return;
    await _guard(
      'update',
      () => _service.update(title: _title(run), text: _text(run)),
    );
  }

  @override
  Future<void> runEnded(RunActivity run) async {
    _runId = null;
    await _guard('stop', _service.stop);
  }

  static String _title(RunActivity run) => 'Unlocking: ${run.title}';

  static String _text(RunActivity run) =>
      '${run.finishedCount} of ${run.hostCount} '
      '${run.hostCount == 1 ? 'host' : 'hosts'} done';

  static Future<void> _guard(String what, Future<void> Function() op) async {
    try {
      await op();
    } on Object catch (e) {
      debugPrint('Foreground service $what failed: ${e.runtimeType}');
    }
  }
}
