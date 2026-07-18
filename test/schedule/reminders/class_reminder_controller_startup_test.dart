import 'dart:async';

import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/schedule/reminders/class_reminder_repository.dart';
import 'package:dualmate/schedule/reminders/class_reminder_scheduler.dart';
import 'package:dualmate/schedule/reminders/reminder_sync_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'startup never renders paused while granted permissions are loading',
    (tester) async {
      final permissions = _DelayedNotificationApi();
      final source = _FakeScheduleSourceProvider();
      final controller = ClassReminderController(
        repository: _MemoryReminderRepository(),
        scheduleProvider: _FakeScheduleProvider(source),
        sourceProvider: source,
        scheduler: _NoopScheduler(),
        notificationApi: () => permissions,
        now: () => DateTime(2026, 7, 20, 8),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: controller,
            builder: (context, _) =>
                Text(controller.remindersPaused ? 'paused banner' : 'schedule'),
          ),
        ),
      );

      final initialization = controller.initialize();
      await permissions.checksStarted.future;
      await tester.pump();

      expect(controller.hasReminders, isTrue);
      expect(find.text('paused banner'), findsNothing);
      expect(find.text('schedule'), findsOneWidget);

      permissions.complete(
        notification: true,
        reminderChannel: true,
        exactAlarm: true,
      );
      await initialization;
      await tester.pump();

      expect(find.text('paused banner'), findsNothing);
      expect(find.text('schedule'), findsOneWidget);
    },
  );

  for (final missingPermission in [
    'notifications',
    'reminder channel',
    'exact alarm',
  ]) {
    testWidgets(
      'startup renders paused after $missingPermission permission is denied',
      (tester) async {
        final permissions = _DelayedNotificationApi();
        final source = _FakeScheduleSourceProvider();
        final controller = ClassReminderController(
          repository: _MemoryReminderRepository(),
          scheduleProvider: _FakeScheduleProvider(source),
          sourceProvider: source,
          scheduler: _NoopScheduler(),
          notificationApi: () => permissions,
          now: () => DateTime(2026, 7, 20, 8),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Text(
                controller.remindersPaused ? 'paused banner' : 'schedule',
              ),
            ),
          ),
        );

        final initialization = controller.initialize();
        await permissions.checksStarted.future;
        await tester.pump();
        expect(find.text('paused banner'), findsNothing);

        permissions.complete(
          notification: missingPermission != 'notifications',
          reminderChannel: missingPermission != 'reminder channel',
          exactAlarm: missingPermission != 'exact alarm',
        );
        await initialization;
        await tester.pump();

        expect(find.text('paused banner'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'missing notification service stays unknown instead of showing paused',
    (tester) async {
      final source = _FakeScheduleSourceProvider();
      final controller = ClassReminderController(
        repository: _MemoryReminderRepository(),
        scheduleProvider: _FakeScheduleProvider(source),
        sourceProvider: source,
        scheduler: _NoopScheduler(),
        notificationApi: () => null,
        now: () => DateTime(2026, 7, 20, 8),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Text(controller.remindersPaused ? 'paused banner' : 'schedule'),
        ),
      );

      expect(controller.hasReminders, isTrue);
      expect(controller.permissionStateKnown, isFalse);
      expect(find.text('paused banner'), findsNothing);
      expect(find.text('schedule'), findsOneWidget);
    },
  );

  test(
    'fix permissions opens the disabled reminder channel settings',
    () async {
      final permissions = _ChannelDisabledNotificationApi();
      final source = _FakeScheduleSourceProvider();
      final controller = ClassReminderController(
        repository: _MemoryReminderRepository(),
        scheduleProvider: _FakeScheduleProvider(source),
        sourceProvider: source,
        scheduler: _NoopScheduler(),
        notificationApi: () => permissions,
        now: () => DateTime(2026, 7, 20, 8),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.remindersPaused, isTrue);

      await controller.openReliablePermissionSettings();

      expect(permissions.channelSettingsOpens, 1);
      expect(permissions.runtimePermissionRequests, 0);
      expect(permissions.exactAlarmPermissionRequests, 0);
      expect(controller.permissionsGranted, isTrue);
    },
  );

  test('fix permissions opens only one settings surface at a time', () async {
    final permissions = _ChannelDisabledNotificationApi(
      exactAlarmAllowed: false,
    );
    final source = _FakeScheduleSourceProvider();
    final controller = ClassReminderController(
      repository: _MemoryReminderRepository(),
      scheduleProvider: _FakeScheduleProvider(source),
      sourceProvider: source,
      scheduler: _NoopScheduler(),
      notificationApi: () => permissions,
      now: () => DateTime(2026, 7, 20, 8),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.openReliablePermissionSettings();

    expect(permissions.channelSettingsOpens, 1);
    expect(permissions.exactAlarmPermissionRequests, 0);
  });

  test('unchanged resume does not notify schedule listeners', () async {
    final source = _FakeScheduleSourceProvider();
    final controller = ClassReminderController(
      repository: _MemoryReminderRepository(),
      scheduleProvider: _FakeScheduleProvider(source),
      sourceProvider: source,
      scheduler: _NoopScheduler(),
      notificationApi: () => _GrantedNotificationApi(),
      now: () => DateTime(2026, 7, 20, 8),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.onAppResumed();

    expect(notifications, 0);
  });

  test(
    'queued refresh does not cancel alarms while permissions are unknown',
    () async {
      final repository = _MemoryReminderRepository();
      final source = _FakeScheduleSourceProvider();
      final controller = ClassReminderController(
        repository: repository,
        scheduleProvider: _FakeScheduleProvider(source),
        sourceProvider: source,
        scheduler: _NoopScheduler(),
        notificationApi: () => null,
        now: () => DateTime(2026, 7, 20, 8),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final start = DateTime(2026, 7, 20);
      controller.queue.enqueue(
        ReminderSyncRequest(
          schedule: Schedule.fromList([
            ScheduleEntry(
              start: DateTime(2026, 7, 20, 10),
              end: DateTime(2026, 7, 20, 12),
              title: 'Recht',
              details: '',
              professor: '',
              room: '',
              type: ScheduleEntryType.Class,
            ),
          ]),
          start: start,
          end: start.add(const Duration(days: 7)),
          sourceIdentity: 'rapla:a',
          sourceGeneration: 1,
        ),
      );

      await controller.queue.drain();

      expect(controller.permissionStateKnown, isFalse);
      expect(repository.manifestWindowReads, 0);
    },
  );

  test('failed initialization can be retried', () async {
    final repository = _FailOnceReminderRepository();
    final source = _FakeScheduleSourceProvider();
    final controller = ClassReminderController(
      repository: repository,
      scheduleProvider: _FakeScheduleProvider(source),
      sourceProvider: source,
      scheduler: _NoopScheduler(),
      notificationApi: () => _GrantedNotificationApi(),
      now: () => DateTime(2026, 7, 20, 8),
    );
    addTearDown(controller.dispose);

    await expectLater(controller.initialize(), throwsStateError);
    await controller.initialize();

    expect(controller.isInitialized, isTrue);
    expect(repository.loadAttempts, greaterThanOrEqualTo(2));
  });
}

class _DelayedNotificationApi extends VoidNotificationApi {
  final Completer<void> checksStarted = Completer<void>();
  final Completer<bool> _notificationPermission = Completer<bool>();
  final Completer<bool> _reminderChannelPermission = Completer<bool>();
  final Completer<bool> _exactAlarmPermission = Completer<bool>();
  var _checks = 0;

  void complete({
    required bool notification,
    required bool reminderChannel,
    required bool exactAlarm,
  }) {
    _notificationPermission.complete(notification);
    _reminderChannelPermission.complete(reminderChannel);
    _exactAlarmPermission.complete(exactAlarm);
  }

  void _didStartCheck() {
    _checks += 1;
    if (_checks == 3) checksStarted.complete();
  }

  @override
  Future<bool> areNotificationsEnabled() {
    _didStartCheck();
    return _notificationPermission.future;
  }

  @override
  Future<bool> areClassRemindersEnabled() {
    _didStartCheck();
    return _reminderChannelPermission.future;
  }

  @override
  Future<bool> canScheduleExactNotifications() {
    _didStartCheck();
    return _exactAlarmPermission.future;
  }
}

class _ChannelDisabledNotificationApi extends VoidNotificationApi {
  final bool exactAlarmAllowed;
  bool channelEnabled = false;
  int channelSettingsOpens = 0;
  int runtimePermissionRequests = 0;
  int exactAlarmPermissionRequests = 0;

  _ChannelDisabledNotificationApi({this.exactAlarmAllowed = true});

  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<bool> areClassRemindersEnabled() async => channelEnabled;

  @override
  Future<bool> canScheduleExactNotifications() async => exactAlarmAllowed;

  @override
  Future<bool?> requestRuntimePermission() async {
    runtimePermissionRequests++;
    return true;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    exactAlarmPermissionRequests++;
    return true;
  }

  @override
  Future<bool> openClassReminderSettings() async {
    channelSettingsOpens++;
    channelEnabled = true;
    return true;
  }
}

class _GrantedNotificationApi extends VoidNotificationApi {
  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<bool> areClassRemindersEnabled() async => true;

  @override
  Future<bool> canScheduleExactNotifications() async => true;
}

class _MemoryReminderRepository extends ClassReminderRepository {
  _MemoryReminderRepository() : super(_UnusedDatabaseAccess());

  final rules = [
    ClassReminderRule(
      id: 'recht',
      scope: ClassReminderScope.recurring,
      canonicalTitle: 'Recht',
      offset: const Duration(minutes: 30),
      sourceIdentity: 'rapla:a',
    ),
  ];
  int manifestWindowReads = 0;

  @override
  Future<ExpiredReminderDeletionCount> deleteExpired(DateTime now) async {
    return const ExpiredReminderDeletionCount(oneTimeRules: 0, manifestRows: 0);
  }

  @override
  Future<List<ClassReminderRule>> loadRelevantRules({
    required String sourceIdentity,
    required DateTime now,
  }) async => rules;

  @override
  Future<List<ScheduledClassNotification>> loadManifestForWindow({
    required String sourceIdentity,
    required DateTime start,
    required DateTime end,
  }) async {
    manifestWindowReads++;
    return const [];
  }

  @override
  Future<List<ScheduledClassNotification>> loadManifestForSource(
    String sourceIdentity,
  ) async => const [];
}

class _FailOnceReminderRepository extends _MemoryReminderRepository {
  int loadAttempts = 0;

  @override
  Future<List<ClassReminderRule>> loadRelevantRules({
    required String sourceIdentity,
    required DateTime now,
  }) async {
    loadAttempts++;
    if (loadAttempts == 1) throw StateError('first load failed');
    return super.loadRelevantRules(sourceIdentity: sourceIdentity, now: now);
  }
}

class _FakeScheduleProvider extends ScheduleProvider {
  _FakeScheduleProvider(ScheduleSourceProvider source)
    : super(
        source,
        _FakeScheduleEntryRepository(),
        _FakeScheduleQueryInformationRepository(),
        _FakePreferencesProvider(),
        _FakeScheduleFilterRepository(),
      );

  @override
  Future<Schedule> getUnfilteredCachedSchedule(
    DateTime start,
    DateTime end,
  ) async {
    return Schedule();
  }
}

class _FakeScheduleSourceProvider extends ScheduleSourceProvider {
  _FakeScheduleSourceProvider()
    : super(
        _FakePreferencesProvider(),
        false,
        _FakeScheduleEntryRepository(),
        _FakeScheduleQueryInformationRepository(),
      );

  @override
  String get currentSourceIdentity => 'rapla:a';

  @override
  int get sourceGeneration => 1;
}

class _NoopScheduler implements ClassReminderScheduler {
  @override
  Future<void> cancel(int notificationId) async {}

  @override
  Future<void> schedule(ClassReminderNotificationRequest request) async {}
}

class _FakePreferencesProvider extends Fake implements PreferencesProvider {}

class _FakeScheduleEntryRepository extends Fake
    implements ScheduleEntryRepository {}

class _FakeScheduleQueryInformationRepository extends Fake
    implements ScheduleQueryInformationRepository {}

class _FakeScheduleFilterRepository extends Fake
    implements ScheduleFilterRepository {}

class _UnusedDatabaseAccess extends DatabaseAccess {}
