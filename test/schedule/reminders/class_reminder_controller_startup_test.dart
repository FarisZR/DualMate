import 'dart:async';

import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/logging/diagnostic_exception_filter.dart';
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

  test(
    'permission check throws after granted: state becomes denied and pause path cancels alarms',
    () async {
      final scheduler = _RecordingScheduler();
      final repository = _ManifestReminderRepository();
      final source = _FakeScheduleSourceProvider();
      // Start with granted; switch to throwing after initialization.
      var throwOnCheck = false;
      NotificationApi? apiFactory() {
        if (throwOnCheck) return _ThrowingNotificationApi();
        return _GrantedNotificationApi();
      }

      final controller = ClassReminderController(
        repository: repository,
        scheduleProvider: _FakeScheduleProvider(source),
        sourceProvider: source,
        scheduler: scheduler,
        notificationApi: apiFactory,
        now: () => DateTime(2026, 7, 20, 8),
      );
      addTearDown(controller.dispose);

      // Initialize with granted permissions.
      await controller.initialize();
      expect(controller.permissionsGranted, isTrue);
      expect(controller.permissionStateKnown, isTrue);

      // Second check throws: state must flip to known/denied and pause path runs.
      throwOnCheck = true;
      await controller.refreshPermissionState();

      expect(controller.permissionStateKnown, isTrue);
      expect(controller.permissionsGranted, isFalse);
      expect(controller.remindersPaused, isTrue);
      expect(
        scheduler.cancelledIds,
        contains(_ManifestReminderRepository.manifestNotificationId),
      );
    },
  );

  test(
    'initialization detects an overdue pending alarm before expired cleanup',
    () async {
      final now = DateTime(2026, 7, 20, 8);
      final row = _manifestRow(
        id: 42,
        scheduledTime: now.subtract(const Duration(minutes: 30)),
        classStart: now.subtract(const Duration(minutes: 5)),
      );
      final harness = _ReminderHarness(
        now: now,
        manifest: [row],
        pendingIds: {42},
      );
      addTearDown(harness.controller.dispose);

      await harness.controller.initialize();

      expect(harness.controller.hasLikelyMissedReminder, isTrue);
      expect(harness.permissions.pendingReads, 1);
      expect(harness.scheduler.cancelledIds, [42]);
      expect(harness.repository.manifest, isEmpty);
      expect(harness.repository.deleteExpiredCalls, greaterThanOrEqualTo(1));
    },
  );

  test(
    'overdue alarm absent from pending queue is not treated as missed',
    () async {
      final now = DateTime(2026, 7, 20, 8);
      final row = _manifestRow(
        id: 42,
        scheduledTime: now.subtract(const Duration(minutes: 30)),
        classStart: now.add(const Duration(hours: 1)),
      );
      final harness = _ReminderHarness(now: now, manifest: [row]);
      addTearDown(harness.controller.dispose);

      await harness.controller.initialize();

      expect(harness.controller.hasLikelyMissedReminder, isFalse);
      expect(harness.permissions.pendingReads, 1);
      expect(harness.scheduler.cancelledIds, isEmpty);
      expect(harness.repository.manifest, [row]);
    },
  );

  test('pending queue is not queried when no alarm is overdue', () async {
    final now = DateTime(2026, 7, 20, 8);
    final row = _manifestRow(
      id: 42,
      scheduledTime: now.subtract(const Duration(minutes: 9)),
      classStart: now.add(const Duration(hours: 1)),
    );
    final harness = _ReminderHarness(
      now: now,
      manifest: [row],
      pendingIds: {42},
    );
    addTearDown(harness.controller.dispose);

    await harness.controller.initialize();

    expect(harness.controller.hasLikelyMissedReminder, isFalse);
    expect(harness.permissions.pendingReads, 0);
  });

  test(
    'denied permissions suppress battery warning and keep paused flow',
    () async {
      final now = DateTime(2026, 7, 20, 8);
      final harness = _ReminderHarness(
        now: now,
        rules: [_recurringRule()],
        manifest: [
          _manifestRow(
            id: 42,
            scheduledTime: now.subtract(const Duration(minutes: 30)),
            classStart: now.add(const Duration(hours: 1)),
          ),
        ],
        permissionsGranted: false,
        pendingIds: {42},
      );
      addTearDown(harness.controller.dispose);

      await harness.controller.initialize();

      expect(harness.controller.remindersPaused, isTrue);
      expect(harness.controller.hasLikelyMissedReminder, isFalse);
      expect(harness.permissions.pendingReads, 0);
    },
  );

  test(
    'multiple overdue pending alarms produce one notice and are consumed',
    () async {
      final now = DateTime(2026, 7, 20, 8);
      final harness = _ReminderHarness(
        now: now,
        manifest: [
          _manifestRow(
            id: 42,
            scheduledTime: now.subtract(const Duration(minutes: 30)),
            classStart: now.add(const Duration(hours: 1)),
          ),
          _manifestRow(
            id: 43,
            scheduledTime: now.subtract(const Duration(minutes: 11)),
            classStart: now.add(const Duration(hours: 2)),
          ),
        ],
        pendingIds: {42, 43},
      );
      addTearDown(harness.controller.dispose);

      await harness.controller.initialize();

      expect(harness.controller.hasLikelyMissedReminder, isTrue);
      expect(harness.scheduler.cancelledIds, containsAll([42, 43]));
      expect(harness.repository.manifest, isEmpty);
    },
  );

  test(
    'missed reminder notice can be dismissed and settings clear on success',
    () async {
      final now = DateTime(2026, 7, 20, 8);
      final harness = _ReminderHarness(
        now: now,
        manifest: [
          _manifestRow(
            id: 42,
            scheduledTime: now.subtract(const Duration(minutes: 30)),
            classStart: now.add(const Duration(hours: 1)),
          ),
        ],
        pendingIds: {42},
      );
      addTearDown(harness.controller.dispose);
      await harness.controller.initialize();

      harness.controller.dismissLikelyMissedReminder();
      expect(harness.controller.hasLikelyMissedReminder, isFalse);

      harness.repository.manifest.add(
        _manifestRow(
          id: 43,
          scheduledTime: now.subtract(const Duration(minutes: 20)),
          classStart: now.add(const Duration(hours: 2)),
        ),
      );
      harness.permissions.pendingIds.add(43);
      await harness.controller.onAppResumed();
      expect(harness.controller.hasLikelyMissedReminder, isTrue);

      harness.permissions.batterySettingsResult = false;
      await harness.controller.openBatterySettingsForMissedReminder();
      expect(harness.controller.hasLikelyMissedReminder, isTrue);

      harness.permissions.batterySettingsResult = true;
      await harness.controller.openBatterySettingsForMissedReminder();
      expect(harness.controller.hasLikelyMissedReminder, isFalse);
      expect(harness.permissions.batterySettingsOpens, 2);
    },
  );

  test(
    'saving a reminder for an already-started entry is ignored early',
    () async {
      final now = DateTime(2026, 7, 20, 10);
      final harness = _ReminderHarness(now: now);
      addTearDown(harness.controller.dispose);

      final result = await harness.controller.saveReminder(
        entry: _entry(start: now),
        offset: const Duration(minutes: 15),
        scope: ClassReminderScope.oneTime,
      );

      expect(result, ReminderActivationResult.ignoredPastEvent);
      expect(harness.permissions.permissionReads, 0);
      expect(harness.repository.ruleChangeCalls, 0);
      expect(harness.scheduleProvider.cacheReads, 0);
    },
  );

  test(
    'saving a future reminder retains the existing permission flow',
    () async {
      final now = DateTime(2026, 7, 20, 10);
      final harness = _ReminderHarness(now: now);
      addTearDown(harness.controller.dispose);

      final result = await harness.controller.saveReminder(
        entry: _entry(start: now.add(const Duration(hours: 1))),
        offset: const Duration(minutes: 15),
        scope: ClassReminderScope.oneTime,
      );
      await harness.controller.queue.drain();

      expect(result, ReminderActivationResult.active);
      expect(harness.permissions.permissionReads, greaterThanOrEqualTo(3));
      expect(harness.repository.ruleChangeCalls, greaterThanOrEqualTo(1));
      expect(harness.scheduleProvider.cacheReads, 1);
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

class _PendingNotificationApi extends VoidNotificationApi {
  final bool permissionsGranted;
  final Set<int> pendingIds;
  int pendingReads = 0;
  int permissionReads = 0;
  int batterySettingsOpens = 0;
  bool batterySettingsResult = true;

  _PendingNotificationApi({
    this.permissionsGranted = true,
    Set<int>? pendingIds,
  }) : pendingIds = pendingIds ?? <int>{};

  @override
  Future<bool> areNotificationsEnabled() async {
    permissionReads++;
    return permissionsGranted;
  }

  @override
  Future<bool> areClassRemindersEnabled() async {
    permissionReads++;
    return permissionsGranted;
  }

  @override
  Future<bool> canScheduleExactNotifications() async {
    permissionReads++;
    return permissionsGranted;
  }

  @override
  Future<Set<int>> pendingNotificationIds() async {
    pendingReads++;
    return Set<int>.from(pendingIds);
  }

  @override
  Future<bool> openClassReminderBatterySettings() async {
    batterySettingsOpens++;
    return batterySettingsResult;
  }
}

class _ReminderHarness {
  late final _TrackingReminderRepository repository;
  late final _PendingNotificationApi permissions;
  late final _RecordingScheduler scheduler;
  late final _FakeScheduleSourceProvider source;
  late final _TrackingScheduleProvider scheduleProvider;
  late final ClassReminderController controller;

  _ReminderHarness({
    required DateTime now,
    List<ClassReminderRule>? rules,
    List<ScheduledClassNotification>? manifest,
    bool permissionsGranted = true,
    Set<int>? pendingIds,
  }) {
    repository = _TrackingReminderRepository(rules: rules, manifest: manifest);
    permissions = _PendingNotificationApi(
      permissionsGranted: permissionsGranted,
      pendingIds: pendingIds,
    );
    scheduler = _RecordingScheduler();
    source = _FakeScheduleSourceProvider();
    scheduleProvider = _TrackingScheduleProvider(source);
    controller = ClassReminderController(
      repository: repository,
      scheduleProvider: scheduleProvider,
      sourceProvider: source,
      scheduler: scheduler,
      notificationApi: () => permissions,
      now: () => now,
    );
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

class _TrackingScheduleProvider extends _FakeScheduleProvider {
  int cacheReads = 0;

  _TrackingScheduleProvider(super.source);

  @override
  Future<Schedule> getUnfilteredCachedSchedule(
    DateTime start,
    DateTime end,
  ) async {
    cacheReads++;
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

class _ThrowingNotificationApi extends VoidNotificationApi {
  @override
  Future<bool> areNotificationsEnabled() =>
      Future.error(_PermissionCheckFailure());
}

/// An [ExpectedExternalFailure] so AppDiagnostics suppresses it without
/// calling Sentry (which requires path_provider in tests).
class _PermissionCheckFailure implements ExpectedExternalFailure, Exception {
  @override
  String toString() => 'Simulated permission check failure';
}

class _RecordingScheduler implements ClassReminderScheduler {
  final List<int> cancelledIds = [];

  @override
  Future<void> cancel(int notificationId) async {
    cancelledIds.add(notificationId);
  }

  @override
  Future<void> schedule(ClassReminderNotificationRequest request) async {}
}

/// Repository that exposes a single manifest row so _pauseSource has something
/// to cancel.
class _ManifestReminderRepository extends _MemoryReminderRepository {
  static const int manifestNotificationId = 42;

  @override
  Future<List<ScheduledClassNotification>> loadManifestForSource(
    String sourceIdentity,
  ) async => [
    ScheduledClassNotification(
      ruleId: 'recht',
      occurrenceIdentity: 'occ1',
      sourceIdentity: 'rapla:a',
      notificationId: manifestNotificationId,
      scheduledTime: DateTime.utc(2026, 7, 20, 10),
      classStart: DateTime.utc(2026, 7, 20, 10),
      contentFingerprint: 'fp',
    ),
  ];

  @override
  Future<void> applyManifestChanges({
    required List<ScheduledClassNotification> upserts,
    required List<ScheduledClassNotification> removals,
  }) async {
    // No-op: no real database in tests.
  }
}

class _TrackingReminderRepository extends ClassReminderRepository {
  final List<ClassReminderRule> rules;
  final List<ScheduledClassNotification> manifest;
  int deleteExpiredCalls = 0;
  int ruleChangeCalls = 0;

  _TrackingReminderRepository({
    List<ClassReminderRule>? rules,
    List<ScheduledClassNotification>? manifest,
  }) : rules = rules ?? <ClassReminderRule>[],
       manifest = manifest ?? <ScheduledClassNotification>[],
       super(_UnusedDatabaseAccess());

  @override
  Future<List<ClassReminderRule>> loadRelevantRules({
    required String sourceIdentity,
    required DateTime now,
  }) async => List<ClassReminderRule>.from(rules);

  @override
  Future<List<ScheduledClassNotification>> loadManifestForSource(
    String sourceIdentity,
  ) async => manifest
      .where((row) => row.sourceIdentity == sourceIdentity)
      .toList(growable: false);

  @override
  Future<List<ScheduledClassNotification>> loadManifestForWindow({
    required String sourceIdentity,
    required DateTime start,
    required DateTime end,
  }) async => manifest
      .where(
        (row) =>
            row.sourceIdentity == sourceIdentity &&
            !row.classStart.isBefore(start) &&
            row.classStart.isBefore(end),
      )
      .toList(growable: false);

  @override
  Future<void> applyManifestChanges({
    required List<ScheduledClassNotification> upserts,
    required List<ScheduledClassNotification> removals,
  }) async {
    final removedKeys = {
      for (final row in removals) '${row.ruleId}|${row.occurrenceIdentity}',
    };
    manifest.removeWhere(
      (row) => removedKeys.contains('${row.ruleId}|${row.occurrenceIdentity}'),
    );
    for (final row in upserts) {
      manifest.removeWhere(
        (existing) =>
            existing.ruleId == row.ruleId &&
            existing.occurrenceIdentity == row.occurrenceIdentity,
      );
      manifest.add(row);
    }
  }

  @override
  Future<void> applyRuleChanges({
    required List<ClassReminderRule> upserts,
    required List<String> removedRuleIds,
  }) async {
    ruleChangeCalls++;
    rules.removeWhere((rule) => removedRuleIds.contains(rule.id));
    for (final rule in upserts) {
      rules.removeWhere((existing) => existing.id == rule.id);
      rules.add(rule);
    }
  }

  @override
  Future<ExpiredReminderDeletionCount> deleteExpired(DateTime now) async {
    deleteExpiredCalls++;
    final previousManifestLength = manifest.length;
    manifest.removeWhere((row) => !row.classStart.isAfter(now));
    return ExpiredReminderDeletionCount(
      oneTimeRules: 0,
      manifestRows: previousManifestLength - manifest.length,
    );
  }
}

ClassReminderRule _recurringRule() => const ClassReminderRule(
  id: 'recht',
  scope: ClassReminderScope.recurring,
  canonicalTitle: 'Recht',
  offset: Duration(minutes: 30),
  sourceIdentity: 'rapla:a',
);

ScheduledClassNotification _manifestRow({
  required int id,
  required DateTime scheduledTime,
  required DateTime classStart,
}) => ScheduledClassNotification(
  ruleId: 'rule-$id',
  occurrenceIdentity: 'occurrence-$id',
  sourceIdentity: 'rapla:a',
  notificationId: id,
  scheduledTime: scheduledTime,
  classStart: classStart,
  contentFingerprint: 'fingerprint-$id',
);

ScheduleEntry _entry({required DateTime start}) => ScheduleEntry(
  start: start,
  end: start.add(const Duration(hours: 1)),
  title: 'Recht',
  details: '',
  professor: '',
  room: '',
  type: ScheduleEntryType.Class,
);
