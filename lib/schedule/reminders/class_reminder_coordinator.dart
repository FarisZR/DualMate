import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/reminders/canonical_class_name.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/reminders/class_reminder_repository.dart';
import 'package:dualmate/schedule/reminders/class_reminder_scheduler.dart';

class ReminderReconciliationResult {
  final int scheduleEntriesExamined;
  final int reminderRulesLoaded;
  final int manifestRowsLoaded;
  final int alarmsScheduled;
  final int alarmsCancelled;
  final int expiredRowsDeleted;

  const ReminderReconciliationResult({
    this.scheduleEntriesExamined = 0,
    this.reminderRulesLoaded = 0,
    this.manifestRowsLoaded = 0,
    this.alarmsScheduled = 0,
    this.alarmsCancelled = 0,
    this.expiredRowsDeleted = 0,
  });
}

class ClassReminderCoordinator {
  final ClassReminderRepositoryApi _repository;
  final ClassReminderScheduler _scheduler;
  final DateTime Function() _now;

  ClassReminderCoordinator({
    required ClassReminderRepositoryApi repository,
    required ClassReminderScheduler scheduler,
    DateTime Function()? now,
  }) : _repository = repository,
       _scheduler = scheduler,
       _now = now ?? DateTime.now;

  Future<ReminderReconciliationResult> reconcile({
    required Schedule schedule,
    required DateTime start,
    required DateTime end,
    required String sourceIdentity,
  }) async {
    final now = _now();
    var expiredRowsDeleted = 0;
    try {
      expiredRowsDeleted = (await _repository.deleteExpired(now)).total;
    } catch (_) {
      // Cleanup is best-effort and must never block schedule reconciliation.
    }

    final rules = await _repository.loadRelevantRules(
      sourceIdentity: sourceIdentity,
      now: now,
    );
    final entries = rules.isEmpty
        ? const <ScheduleEntry>[]
        : schedule.entries
              .where(
                (entry) =>
                    entry.start.isBefore(end) &&
                    entry.end.isAfter(start) &&
                    entry.start.isAfter(now),
              )
              .toList(growable: false);
    final canonicalByEntry = <ScheduleEntry, String>{
      for (final entry in entries)
        entry: CanonicalClassName.fromTitle(entry.title),
    };

    final desired = <String, _DesiredNotification>{};
    final movedOneTimeRules = <ClassReminderRule>[];
    final removedOneTimeRuleIds = <String>[];
    for (final rule in rules) {
      final matches = rule.scope == ClassReminderScope.recurring
          ? entries
                .where(
                  (entry) => canonicalByEntry[entry] == rule.canonicalTitle,
                )
                .toList(growable: false)
          : _matchOneTime(rule, entries, canonicalByEntry, start, end);

      if (rule.isOneTime && matches.isEmpty) {
        final originalStart = rule.occurrenceStart;
        if (originalStart != null &&
            !originalStart.isBefore(start) &&
            originalStart.isBefore(end)) {
          removedOneTimeRuleIds.add(rule.id);
        }
      }

      for (final entry in matches) {
        final scheduledTime = entry.start.subtract(rule.offset);
        if (!scheduledTime.isAfter(now)) continue;
        final canonicalTitle = canonicalByEntry[entry]!;
        final occurrenceIdentity = ClassReminderIdentity.occurrence(
          canonicalTitle: canonicalTitle,
          occurrenceStart: entry.start,
          sourceIdentity: sourceIdentity,
        );
        final notificationId = ClassReminderIdentity.notificationId(
          ruleId: rule.id,
          occurrenceStart: entry.start,
          sourceIdentity: sourceIdentity,
        );
        final manifest = ScheduledClassNotification(
          ruleId: rule.id,
          occurrenceIdentity: occurrenceIdentity,
          sourceIdentity: sourceIdentity,
          notificationId: notificationId,
          scheduledTime: scheduledTime,
          classStart: entry.start,
          contentFingerprint: contentFingerprint(
            title: canonicalTitle,
            start: entry.start,
            room: entry.room,
            offset: rule.offset,
          ),
        );
        desired[_manifestKey(manifest)] = _DesiredNotification(
          manifest: manifest,
          request: ClassReminderNotificationRequest(
            notificationId: notificationId,
            className: canonicalTitle,
            classStart: entry.start,
            scheduledTime: scheduledTime,
            offset: rule.offset,
            room: entry.room,
            occurrenceIdentity: occurrenceIdentity,
          ),
        );

        if (rule.isOneTime &&
            (rule.occurrenceStart != entry.start ||
                rule.canonicalTitle != canonicalTitle)) {
          movedOneTimeRules.add(
            ClassReminderRule(
              id: rule.id,
              scope: rule.scope,
              canonicalTitle: canonicalTitle,
              offset: rule.offset,
              sourceIdentity: rule.sourceIdentity,
              occurrenceStart: entry.start,
              occurrenceEnd: entry.end,
            ),
          );
        }
      }
    }

    final existingRows = await _repository.loadManifestForWindow(
      sourceIdentity: sourceIdentity,
      start: start,
      end: end,
    );
    final existing = {for (final row in existingRows) _manifestKey(row): row};
    final removals = <ScheduledClassNotification>[];
    final upserts = <ScheduledClassNotification>[];
    final requests = <ClassReminderNotificationRequest>[];

    for (final entry in existing.entries) {
      final wanted = desired[entry.key]?.manifest;
      if (wanted == null || !_manifestMatches(entry.value, wanted)) {
        removals.add(entry.value);
      }
    }
    for (final entry in desired.entries) {
      final old = existing[entry.key];
      if (old == null || !_manifestMatches(old, entry.value.manifest)) {
        upserts.add(entry.value.manifest);
        requests.add(entry.value.request);
      }
    }

    for (final row in removals) {
      await _scheduler.cancel(row.notificationId);
    }
    for (final request in requests) {
      await _scheduler.schedule(request);
    }
    if (upserts.isNotEmpty || removals.isNotEmpty) {
      await _repository.applyManifestChanges(
        upserts: upserts,
        removals: removals,
      );
    }
    if (movedOneTimeRules.isNotEmpty || removedOneTimeRuleIds.isNotEmpty) {
      await _repository.applyRuleChanges(
        upserts: movedOneTimeRules,
        removedRuleIds: removedOneTimeRuleIds,
      );
    }

    return ReminderReconciliationResult(
      scheduleEntriesExamined: entries.length,
      reminderRulesLoaded: rules.length,
      manifestRowsLoaded: existingRows.length,
      alarmsScheduled: requests.length,
      alarmsCancelled: removals.length,
      expiredRowsDeleted: expiredRowsDeleted,
    );
  }

  Future<int> pauseWindow({
    required DateTime start,
    required DateTime end,
    required String sourceIdentity,
  }) async {
    final existing = await _repository.loadManifestForWindow(
      sourceIdentity: sourceIdentity,
      start: start,
      end: end,
    );
    for (final row in existing) {
      await _scheduler.cancel(row.notificationId);
    }
    if (existing.isNotEmpty) {
      await _repository.applyManifestChanges(
        upserts: const [],
        removals: existing,
      );
    }
    return existing.length;
  }

  static String contentFingerprint({
    required String title,
    required DateTime start,
    required String room,
    required Duration offset,
  }) {
    final input =
        '$title|${start.toUtc().millisecondsSinceEpoch}|$room|${offset.inMinutes}';
    var hash = 0x811c9dc5;
    for (final byte in input.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  List<ScheduleEntry> _matchOneTime(
    ClassReminderRule rule,
    List<ScheduleEntry> entries,
    Map<ScheduleEntry, String> canonicalByEntry,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final candidates = entries
        .where((entry) => canonicalByEntry[entry] == rule.canonicalTitle)
        .toList(growable: false);
    if (rule.occurrenceStart == null) return const [];
    final sameTime = candidates.where(
      (entry) => entry.start == rule.occurrenceStart,
    );
    if (sameTime.isNotEmpty) return [sameTime.first];
    if (candidates.isNotEmpty) {
      candidates.sort(
        (a, b) => a.start
            .difference(rule.occurrenceStart!)
            .abs()
            .compareTo(b.start.difference(rule.occurrenceStart!).abs()),
      );
      return [candidates.first];
    }
    final renamedAtSameTime = entries
        .where((entry) => entry.start == rule.occurrenceStart)
        .toList(growable: false);
    return renamedAtSameTime.length == 1 ? renamedAtSameTime : const [];
  }

  static String _manifestKey(ScheduledClassNotification row) =>
      '${row.ruleId}|${row.occurrenceIdentity}';

  static bool _manifestMatches(
    ScheduledClassNotification old,
    ScheduledClassNotification wanted,
  ) =>
      old.notificationId == wanted.notificationId &&
      old.scheduledTime == wanted.scheduledTime &&
      old.classStart == wanted.classStart &&
      old.contentFingerprint == wanted.contentFingerprint;
}

class _DesiredNotification {
  final ScheduledClassNotification manifest;
  final ClassReminderNotificationRequest request;

  const _DesiredNotification({required this.manifest, required this.request});
}
