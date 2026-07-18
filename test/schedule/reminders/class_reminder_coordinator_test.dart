import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/reminders/class_reminder_coordinator.dart';
import 'package:dualmate/schedule/reminders/class_reminder_repository.dart';
import 'package:dualmate/schedule/reminders/class_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 20, 8);
  final windowStart = DateTime(2026, 7, 20);
  final windowEnd = DateTime(2026, 7, 27);

  test(
    'every canonical Recht occurrence receives a recurring reminder',
    () async {
      final repository = _MemoryRepository([
        ClassReminderRule(
          id: 'recht',
          scope: ClassReminderScope.recurring,
          canonicalTitle: 'Recht',
          offset: const Duration(minutes: 15),
          sourceIdentity: 'rapla:a',
        ),
      ]);
      final scheduler = _RecordingScheduler();
      final coordinator = ClassReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        now: () => now,
      );
      final schedule = Schedule.fromList([
        _entry(DateTime(2026, 7, 20, 10), 'Online - Recht'),
        _entry(DateTime(2026, 7, 22, 9), 'Recht online'),
        _entry(DateTime(2026, 7, 23, 9), 'Recht II'),
      ]);

      final result = await coordinator.reconcile(
        schedule: schedule,
        start: windowStart,
        end: windowEnd,
        sourceIdentity: 'rapla:a',
      );

      expect(result.scheduleEntriesExamined, 3);
      expect(result.alarmsScheduled, 2);
      expect(scheduler.scheduled, hasLength(2));
    },
  );

  test(
    'unchanged refresh performs no platform calls or manifest writes',
    () async {
      final rule = ClassReminderRule(
        id: 'recht',
        scope: ClassReminderScope.recurring,
        canonicalTitle: 'Recht',
        offset: const Duration(minutes: 15),
        sourceIdentity: 'rapla:a',
      );
      final entry = _entry(DateTime(2026, 7, 20, 10), 'Recht');
      final repository = _MemoryRepository([rule]);
      final scheduler = _RecordingScheduler();
      final coordinator = ClassReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        now: () => now,
      );
      await coordinator.reconcile(
        schedule: Schedule.fromList([entry]),
        start: windowStart,
        end: windowEnd,
        sourceIdentity: 'rapla:a',
      );
      scheduler.scheduled.clear();
      repository.manifestWriteCount = 0;

      final result = await coordinator.reconcile(
        schedule: Schedule.fromList([entry]),
        start: windowStart,
        end: windowEnd,
        sourceIdentity: 'rapla:a',
      );

      expect(result.alarmsScheduled, 0);
      expect(result.alarmsCancelled, 0);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, isEmpty);
      expect(repository.manifestWriteCount, 0);
    },
  );

  test(
    '30-minute reminder is scheduled exactly 30 minutes before class',
    () async {
      final classStart = DateTime(2026, 7, 20, 10);
      final repository = _MemoryRepository([
        ClassReminderRule(
          id: 'recht',
          scope: ClassReminderScope.recurring,
          canonicalTitle: 'Recht',
          offset: const Duration(minutes: 30),
          sourceIdentity: 'rapla:a',
        ),
      ]);
      final scheduler = _RecordingScheduler();
      final coordinator = ClassReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        now: () => now,
      );

      await coordinator.reconcile(
        schedule: Schedule.fromList([_entry(classStart, 'Recht')]),
        start: windowStart,
        end: windowEnd,
        sourceIdentity: 'rapla:a',
      );

      expect(scheduler.scheduled, hasLength(1));
      expect(
        scheduler.scheduled.single.scheduledTime,
        classStart.subtract(const Duration(minutes: 30)),
      );
      expect(scheduler.scheduled.single.classStart, classStart);
      expect(scheduler.scheduled.single.offset, const Duration(minutes: 30));
    },
  );

  test(
    'does not schedule a reminder whose notification time has passed',
    () async {
      final repository = _MemoryRepository([
        ClassReminderRule(
          id: 'recht',
          scope: ClassReminderScope.recurring,
          canonicalTitle: 'Recht',
          offset: const Duration(minutes: 30),
          sourceIdentity: 'rapla:a',
        ),
      ]);
      final scheduler = _RecordingScheduler();
      final coordinator = ClassReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        now: () => now,
      );

      await coordinator.reconcile(
        schedule: Schedule.fromList([
          _entry(now.add(const Duration(minutes: 15)), 'Recht'),
        ]),
        start: windowStart,
        end: windowEnd,
        sourceIdentity: 'rapla:a',
      );

      expect(scheduler.scheduled, isEmpty);
      expect(repository.manifest, isEmpty);
    },
  );

  test(
    'no rules treat the notification manifest as an empty desired set',
    () async {
      final repository = _MemoryRepository([]);
      final coordinator = ClassReminderCoordinator(
        repository: repository,
        scheduler: _RecordingScheduler(),
        now: () => now,
      );

      final result = await coordinator.reconcile(
        schedule: Schedule.fromList([
          _entry(DateTime(2026, 7, 20, 10), 'Recht'),
        ]),
        start: windowStart,
        end: windowEnd,
        sourceIdentity: 'rapla:a',
      );

      expect(result.reminderRulesLoaded, 0);
      expect(result.scheduleEntriesExamined, 0);
      expect(repository.manifestReadCount, 1);
    },
  );

  test('removing the final rule cancels its existing alarm', () async {
    final removedRule = ClassReminderRule(
      id: 'recht',
      scope: ClassReminderScope.recurring,
      canonicalTitle: 'Recht',
      offset: const Duration(minutes: 15),
      sourceIdentity: 'rapla:a',
    );
    final repository = _MemoryRepository([]);
    final row = _manifest(removedRule, DateTime(2026, 7, 20, 10));
    repository.manifest.add(row);
    final scheduler = _RecordingScheduler();
    final coordinator = ClassReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      now: () => now,
    );

    await coordinator.reconcile(
      schedule: Schedule.fromList(const []),
      start: windowStart,
      end: windowEnd,
      sourceIdentity: 'rapla:a',
    );

    expect(scheduler.cancelled, [row.notificationId]);
    expect(repository.manifest, isEmpty);
  });

  test(
    'moved one-time occurrence replaces alarm and updates stored timing',
    () async {
      final original = DateTime(2026, 7, 20, 10);
      final moved = DateTime(2026, 7, 20, 12);
      final rule = ClassReminderRule(
        id: 'one',
        scope: ClassReminderScope.oneTime,
        canonicalTitle: 'Recht',
        offset: const Duration(minutes: 15),
        sourceIdentity: 'rapla:a',
        occurrenceStart: original,
        occurrenceEnd: original.add(const Duration(hours: 2)),
      );
      final repository = _MemoryRepository([rule]);
      final oldManifest = _manifest(rule, original);
      repository.manifest.add(oldManifest);
      final scheduler = _RecordingScheduler();
      final coordinator = ClassReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        now: () => now,
      );

      await coordinator.reconcile(
        schedule: Schedule.fromList([_entry(moved, 'Recht')]),
        start: windowStart,
        end: windowEnd,
        sourceIdentity: 'rapla:a',
      );

      expect(scheduler.cancelled, [oldManifest.notificationId]);
      expect(scheduler.scheduled.single.classStart, moved);
      expect(repository.savedRules.single.occurrenceStart, moved);
    },
  );

  test(
    'one-time reminder survives a title edit at the same occurrence time',
    () async {
      final start = DateTime(2026, 7, 20, 10);
      final rule = ClassReminderRule(
        id: 'one',
        scope: ClassReminderScope.oneTime,
        canonicalTitle: 'Recht',
        offset: const Duration(minutes: 15),
        sourceIdentity: 'rapla:a',
        occurrenceStart: start,
        occurrenceEnd: start.add(const Duration(hours: 2)),
      );
      final repository = _MemoryRepository([rule]);
      final scheduler = _RecordingScheduler();
      final coordinator = ClassReminderCoordinator(
        repository: repository,
        scheduler: scheduler,
        now: () => now,
      );

      await coordinator.reconcile(
        schedule: Schedule.fromList([_entry(start, 'Wirtschaftsrecht')]),
        start: windowStart,
        end: windowEnd,
        sourceIdentity: 'rapla:a',
      );

      expect(scheduler.scheduled, hasLength(1));
      expect(repository.savedRules.single.canonicalTitle, 'Wirtschaftsrecht');
    },
  );

  test('ambiguous one-time rematch removes the obsolete reminder', () async {
    final original = DateTime(2026, 7, 20, 10);
    final rule = ClassReminderRule(
      id: 'one',
      scope: ClassReminderScope.oneTime,
      canonicalTitle: 'Recht',
      offset: const Duration(minutes: 15),
      sourceIdentity: 'rapla:a',
      occurrenceStart: original,
      occurrenceEnd: original.add(const Duration(hours: 2)),
    );
    final repository = _MemoryRepository([rule]);
    final oldManifest = _manifest(rule, original);
    repository.manifest.add(oldManifest);
    final scheduler = _RecordingScheduler();
    final coordinator = ClassReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      now: () => now,
    );

    await coordinator.reconcile(
      schedule: Schedule.fromList([
        _entry(DateTime(2026, 7, 20, 11), 'Recht'),
        _entry(DateTime(2026, 7, 20, 12), 'Recht'),
      ]),
      start: windowStart,
      end: windowEnd,
      sourceIdentity: 'rapla:a',
    );

    expect(scheduler.scheduled, isEmpty);
    expect(scheduler.cancelled, [oldManifest.notificationId]);
    expect(repository.rules, isEmpty);
  });

  test('pausing reminders cancels and removes manifest rows', () async {
    final rule = ClassReminderRule(
      id: 'recht',
      scope: ClassReminderScope.recurring,
      canonicalTitle: 'Recht',
      offset: const Duration(minutes: 15),
      sourceIdentity: 'rapla:a',
    );
    final repository = _MemoryRepository([rule]);
    final row = _manifest(rule, DateTime(2026, 7, 20, 10));
    repository.manifest.add(row);
    final scheduler = _RecordingScheduler();
    final coordinator = ClassReminderCoordinator(
      repository: repository,
      scheduler: scheduler,
      now: () => now,
    );

    final cancelled = await coordinator.pauseWindow(
      start: windowStart,
      end: windowEnd,
      sourceIdentity: 'rapla:a',
    );

    expect(cancelled, 1);
    expect(scheduler.cancelled, [row.notificationId]);
    expect(repository.manifest, isEmpty);
  });
}

ScheduleEntry _entry(DateTime start, String title) => ScheduleEntry(
  start: start,
  end: start.add(const Duration(hours: 2)),
  title: title,
  details: '',
  professor: 'Professor',
  room: 'A101',
  type: ScheduleEntryType.Class,
);

ScheduledClassNotification _manifest(ClassReminderRule rule, DateTime start) {
  final occurrence = ClassReminderIdentity.occurrence(
    canonicalTitle: rule.canonicalTitle,
    occurrenceStart: start,
    sourceIdentity: rule.sourceIdentity,
  );
  return ScheduledClassNotification(
    ruleId: rule.id,
    occurrenceIdentity: occurrence,
    sourceIdentity: rule.sourceIdentity,
    notificationId: ClassReminderIdentity.notificationId(
      ruleId: rule.id,
      occurrenceStart: start,
      sourceIdentity: rule.sourceIdentity,
    ),
    scheduledTime: start.subtract(rule.offset),
    classStart: start,
    contentFingerprint: ClassReminderCoordinator.contentFingerprint(
      title: rule.canonicalTitle,
      start: start,
      room: 'A101',
      offset: rule.offset,
    ),
  );
}

class _MemoryRepository implements ClassReminderRepositoryApi {
  final List<ClassReminderRule> rules;
  final List<ScheduledClassNotification> manifest = [];
  final List<ClassReminderRule> savedRules = [];
  int manifestReadCount = 0;
  int manifestWriteCount = 0;

  _MemoryRepository(this.rules);

  @override
  Future<List<ClassReminderRule>> loadRelevantRules({
    required String sourceIdentity,
    required DateTime now,
  }) async => List.of(rules);

  @override
  Future<List<ScheduledClassNotification>> loadManifestForWindow({
    required String sourceIdentity,
    required DateTime start,
    required DateTime end,
  }) async {
    manifestReadCount++;
    return List.of(manifest);
  }

  @override
  Future<void> applyManifestChanges({
    required List<ScheduledClassNotification> upserts,
    required List<ScheduledClassNotification> removals,
  }) async {
    manifestWriteCount++;
    manifest.removeWhere(
      (row) => removals.any(
        (removed) =>
            removed.ruleId == row.ruleId &&
            removed.occurrenceIdentity == row.occurrenceIdentity,
      ),
    );
    for (final row in upserts) {
      manifest.removeWhere(
        (old) =>
            old.ruleId == row.ruleId &&
            old.occurrenceIdentity == row.occurrenceIdentity,
      );
      manifest.add(row);
    }
  }

  @override
  Future<void> applyRuleChanges({
    required List<ClassReminderRule> upserts,
    required List<String> removedRuleIds,
  }) async {
    rules.removeWhere((rule) => removedRuleIds.contains(rule.id));
    for (final rule in upserts) {
      rules.removeWhere((old) => old.id == rule.id);
      rules.add(rule);
      savedRules.add(rule);
    }
  }

  @override
  Future<ExpiredReminderDeletionCount> deleteExpired(DateTime now) async =>
      const ExpiredReminderDeletionCount(oneTimeRules: 0, manifestRows: 0);

  @override
  Future<void> saveRule(ClassReminderRule rule) async {
    savedRules.add(rule);
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    rules.removeWhere((rule) => rule.id == ruleId);
  }
}

class _RecordingScheduler implements ClassReminderScheduler {
  final List<ClassReminderNotificationRequest> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> schedule(ClassReminderNotificationRequest request) async {
    scheduled.add(request);
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
  }
}
