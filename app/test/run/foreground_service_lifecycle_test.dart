import 'package:flutter_test/flutter_test.dart';
import 'package:luks_remote_unlocker/run/foreground_service_lifecycle.dart';
import 'package:luks_remote_unlocker/run/run_lifecycle.dart';

import '../support/fake_foreground_service.dart';

RunActivity activity(String id, {int hosts = 2, String title = 'All hosts'}) =>
    RunActivity(runId: id, title: title, hostCount: hosts);

void main() {
  late FakeForegroundService service;
  late ForegroundServiceLifecycle lifecycle;

  setUp(() {
    service = FakeForegroundService();
    lifecycle = ForegroundServiceLifecycle(service);
  });

  test('starts once per run, updates per finished host and stops at the '
      'end', () async {
    final run = activity('run-1');
    await lifecycle.runStarted(run);
    await lifecycle.runStarted(run);
    await lifecycle.runProgress(run.withFinished(1));
    await lifecycle.runProgress(activity('other').withFinished(1));
    await lifecycle.runProgress(run.withFinished(2));
    expect(service.running, isTrue);
    await lifecycle.runEnded(run.withFinished(2));

    expect(service.calls, [
      'start Unlocking: All hosts | 0 of 2 hosts done',
      'update Unlocking: All hosts | 1 of 2 hosts done',
      'update Unlocking: All hosts | 2 of 2 hosts done',
      'stop',
    ]);
    expect(service.running, isFalse);

    service.calls.clear();
    final next = activity('run-2', hosts: 1, title: 'alpha');
    await lifecycle.runStarted(next);
    await lifecycle.runEnded(next);
    expect(service.calls, [
      'start Unlocking: alpha | 0 of 1 host done',
      'stop',
    ]);
  });

  test('plugin errors never escape and the stop is still tried', () async {
    final run = activity('run-1');
    service.failing.add('start');
    await lifecycle.runStarted(run);
    await lifecycle.runProgress(run.withFinished(1));
    await lifecycle.runEnded(run.withFinished(2));
    expect(service.calls, [
      'start Unlocking: All hosts | 0 of 2 hosts done',
      'update Unlocking: All hosts | 1 of 2 hosts done',
      'stop',
    ]);

    service
      ..failing.clear()
      ..failing.addAll({'update', 'stop', 'isRunning'})
      ..calls.clear();
    await lifecycle.runStarted(activity('run-2'));
    await lifecycle.runProgress(activity('run-2').withFinished(1));
    await lifecycle.runEnded(activity('run-2').withFinished(1));
    expect(service.calls, [
      'update Unlocking: All hosts | 1 of 2 hosts done',
      'stop',
    ]);
    await lifecycle.stopLeftover();
  });

  test('a service left from a run that died with the engine is stopped at '
      'app start and reused by the next run', () async {
    service.running = true;
    await lifecycle.stopLeftover();
    expect(service.calls, ['stop']);
    expect(service.running, isFalse);

    service
      ..running = true
      ..calls.clear();
    final run = activity('run-1');
    await lifecycle.runStarted(run);
    await lifecycle.stopLeftover();
    expect(service.calls, ['update Unlocking: All hosts | 0 of 2 hosts done']);
    expect(service.running, isTrue);
    await lifecycle.runEnded(run);
    expect(service.running, isFalse);
  });

  test('asks for notifications once per session; a denial only sets the '
      'notice and the service still starts', () async {
    service.answer = NotificationAccess.denied;
    await lifecycle.runRequested();
    expect(service.calls, ['check', 'request']);
    expect(lifecycle.notice, ForegroundServiceLifecycle.notificationsOffNotice);

    await lifecycle.runRequested();
    expect(service.calls, ['check', 'request', 'check']);
    await lifecycle.runStarted(activity('run-1'));
    expect(service.running, isTrue);

    service.access = NotificationAccess.granted;
    await lifecycle.runRequested();
    expect(lifecycle.notice, isNull);
  });

  test('a granted permission is not asked again and a blocked one never '
      'shows the dialog', () async {
    service.access = NotificationAccess.granted;
    await lifecycle.runRequested();
    expect(service.calls, ['check']);
    expect(lifecycle.notice, isNull);

    service
      ..access = NotificationAccess.blocked
      ..calls.clear();
    await ForegroundServiceLifecycle(service).runRequested();
    expect(service.calls, ['check']);
  });

  test('the user granting in the dialog leaves no notice; a failing check '
      'is ignored', () async {
    await lifecycle.runRequested();
    expect(service.calls, ['check', 'request']);
    expect(lifecycle.notice, isNull);

    service.failing.add('check');
    await lifecycle.runRequested();
    expect(lifecycle.notice, isNull);
  });
}
