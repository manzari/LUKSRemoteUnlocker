import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../run/foreground_service_lifecycle.dart';

/// The run lifecycle main() installs: the foreground service on Android, none elsewhere.
ForegroundServiceLifecycle? platformRunLifecycle() => Platform.isAndroid
    ? ForegroundServiceLifecycle(PluginForegroundService())
    : null;

/// Android `dataSync` service with wake and Wi-Fi lock and a progress notification.
///
/// Started without a callback, so no task handler and no second isolate ever run; the engine stays in the main isolate.
final class PluginForegroundService implements ForegroundService {
  PluginForegroundService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'run_progress',
        channelName: 'Unlock progress',
        channelDescription: 'Shown while servers are being unlocked.',
        onlyAlertOnce: true,
        visibility: NotificationVisibility.VISIBILITY_PRIVATE,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: false,
      ),
    );
  }

  static const _serviceId = 4100;

  @override
  Future<NotificationAccess> notificationAccess() async =>
      _access(await FlutterForegroundTask.checkNotificationPermission());

  @override
  Future<NotificationAccess> requestNotificationAccess() async =>
      _access(await FlutterForegroundTask.requestNotificationPermission());

  @override
  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  @override
  Future<void> start({required String title, required String text}) async =>
      _check(
        await FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: const [ForegroundServiceTypes.dataSync],
          notificationTitle: title,
          notificationText: text,
        ),
      );

  @override
  Future<void> update({required String title, required String text}) async =>
      _check(
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        ),
      );

  @override
  Future<void> stop() async =>
      _check(await FlutterForegroundTask.stopService());

  static NotificationAccess _access(NotificationPermission p) => switch (p) {
    NotificationPermission.granted => NotificationAccess.granted,
    NotificationPermission.denied => NotificationAccess.denied,
    NotificationPermission.permanently_denied => NotificationAccess.blocked,
  };

  static void _check(ServiceRequestResult result) {
    if (result case ServiceRequestFailure(:final error)) {
      throw StateError(
        'Foreground service request failed: ${error.runtimeType}',
      );
    }
  }
}
