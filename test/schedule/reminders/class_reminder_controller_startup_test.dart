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
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/schedule/reminders/class_reminder_repository.dart';
import 'package:dualmate/schedule/reminders/class_reminder_scheduler.dart';
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

      permissions.complete(notification: true, exactAlarm: true);
      await initialization;
      await tester.pump();

      expect(find.text('paused banner'), findsNothing);
      expect(find.text('schedule'), findsOneWidget);
    },
  );

  for (final missingPermission in ['notifications', 'exact alarm']) {
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
          exactAlarm: missingPermission != 'exact alarm',
        );
        await initialization;
        await tester.pump();

        expect(find.text('paused banner'), findsOneWidget);
      },
    );
  }
}

class _DelayedNotificationApi extends VoidNotificationApi {
  final Completer<void> checksStarted = Completer<void>();
  final Completer<bool> _notificationPermission = Completer<bool>();
  final Completer<bool> _exactAlarmPermission = Completer<bool>();
  var _checks = 0;

  void complete({required bool notification, required bool exactAlarm}) {
    _notificationPermission.complete(notification);
    _exactAlarmPermission.complete(exactAlarm);
  }

  void _didStartCheck() {
    _checks += 1;
    if (_checks == 2) checksStarted.complete();
  }

  @override
  Future<bool> areNotificationsEnabled() {
    _didStartCheck();
    return _notificationPermission.future;
  }

  @override
  Future<bool> canScheduleExactNotifications() {
    _didStartCheck();
    return _exactAlarmPermission.future;
  }
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
  }) async => const [];

  @override
  Future<List<ScheduledClassNotification>> loadManifestForSource(
    String sourceIdentity,
  ) async => const [];
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
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
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
