import 'dart:async';

import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/reminders/canonical_class_name.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/reminders/class_reminder_coordinator.dart';
import 'package:dualmate/schedule/reminders/class_reminder_repository.dart';
import 'package:dualmate/schedule/reminders/class_reminder_scheduler.dart';
import 'package:dualmate/schedule/reminders/reminder_sync_queue.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter/foundation.dart';

enum ReminderActivationResult { active, permissionsRequired, ignoredPastEvent }

class ClassReminderController extends ChangeNotifier {
  static const Duration upcomingWindow = Duration(days: 14);
  static const Duration resumeCleanupStaleness = Duration(hours: 6);
  static const Duration missedReminderGracePeriod = Duration(minutes: 10);

  final ClassReminderRepository _repository;
  final ScheduleProvider _scheduleProvider;
  final ScheduleSourceProvider _sourceProvider;
  final ClassReminderCoordinator _coordinator;
  final ClassReminderScheduler _scheduler;
  final NotificationApi? Function() _notificationApi;
  final DateTime Function() _now;
  late final ReminderSyncQueue _queue;

  List<ClassReminderRule> _rules = const [];
  Map<String, ClassReminderRule> _recurringRulesByTitle = const {};
  Map<String, ClassReminderRule> _oneTimeRulesByOccurrence = const {};
  bool _permissionsGranted = false;
  bool _permissionStateKnown = false;
  bool _hasLikelyMissedReminder = false;
  bool _initialized = false;
  Future<void>? _initializationFuture;
  Future<void>? _permissionRefreshFuture;
  int _reloadRevision = 0;
  Future<void> _sourceChangeFuture = Future<void>.value();
  DateTime? _lastCleanup;
  String _activeSourceIdentity = 'none';

  ClassReminderController({
    required ClassReminderRepository repository,
    required ScheduleProvider scheduleProvider,
    required ScheduleSourceProvider sourceProvider,
    required ClassReminderScheduler scheduler,
    required NotificationApi? Function() notificationApi,
    DateTime Function()? now,
  }) : _repository = repository,
       _scheduleProvider = scheduleProvider,
       _sourceProvider = sourceProvider,
       _scheduler = scheduler,
       _coordinator = ClassReminderCoordinator(
         repository: repository,
         scheduler: scheduler,
         now: now,
       ),
       _notificationApi = notificationApi,
       _now = now ?? DateTime.now {
    _queue = ReminderSyncQueue(
      reconcile: _processRequest,
      currentGeneration: () => _sourceProvider.sourceGeneration,
      onError: _reportQueueFailure,
    );
    _scheduleProvider.addSchedulePersistedCallback(_scheduleUpdated);
    _sourceProvider.addDidChangeScheduleSourceCallback(_sourceChanged);
  }

  bool get hasReminders => _rules.isNotEmpty;
  bool get permissionsGranted => _permissionsGranted;
  bool get permissionStateKnown => _permissionStateKnown;
  bool get isInitialized => _initialized;
  bool get remindersPaused =>
      hasReminders && _permissionStateKnown && !_permissionsGranted;
  bool get hasLikelyMissedReminder => _hasLikelyMissedReminder;
  ReminderSyncQueue get queue => _queue;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializationFuture ??= _initializeWithRetry();
  }

  Future<void> _initializeWithRetry() async {
    try {
      await _initialize();
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    await _reloadRules();
    await refreshPermissionState(scheduleWhenRestored: false);
    await _detectLikelyMissedReminders();
    await _cleanupIfNeeded(force: true);
    if (hasReminders && permissionsGranted) {
      await reconcileUpcoming(waitForCompletion: true);
    } else if (remindersPaused) {
      await _pauseSource(_activeSourceIdentity);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> onAppResumed() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    final permissionsWereGranted = _permissionsGranted;
    await _reloadRules();
    await refreshPermissionState(scheduleWhenRestored: false);
    await _detectLikelyMissedReminders();
    await _cleanupIfNeeded();
    if (!permissionsWereGranted && permissionsGranted && hasReminders) {
      await reconcileUpcoming(waitForCompletion: false);
    }
  }

  Future<void> refreshPermissionState({bool scheduleWhenRestored = true}) {
    return _permissionRefreshFuture ??= _refreshPermissionState(
      scheduleWhenRestored: scheduleWhenRestored,
    ).whenComplete(() => _permissionRefreshFuture = null);
  }

  Future<void> _refreshPermissionState({
    required bool scheduleWhenRestored,
  }) async {
    final previous = _permissionsGranted;
    final wasKnown = _permissionStateKnown;
    final api = _notificationApi();
    if (api == null) return;
    try {
      final results = await Future.wait([
        api.areNotificationsEnabled(),
        api.areClassRemindersEnabled(),
        api.canScheduleExactNotifications(),
      ]);
      _permissionsGranted = results.every((granted) => granted);
    } catch (error, trace) {
      _permissionsGranted = false;
      _permissionStateKnown = true;
      await _reportQueueFailure(error, trace);
    }
    _permissionStateKnown = true;
    if (!wasKnown || previous != _permissionsGranted) notifyListeners();
    if (_permissionsGranted == false &&
        hasReminders &&
        (!wasKnown || previous != _permissionsGranted)) {
      await _pauseSource(_activeSourceIdentity);
    }
    if (scheduleWhenRestored &&
        !previous &&
        _permissionsGranted &&
        hasReminders) {
      await reconcileUpcoming(waitForCompletion: false);
    }
  }

  Future<void> openReliablePermissionSettings() async {
    final api = _notificationApi();
    if (api == null) return;
    try {
      if (!await api.areNotificationsEnabled()) {
        await api.requestRuntimePermission();
        return;
      }
      if (!await api.areClassRemindersEnabled()) {
        await api.openClassReminderSettings();
        return;
      }
      if (!await api.canScheduleExactNotifications()) {
        await api.requestExactAlarmPermission();
      }
    } finally {
      await refreshPermissionState();
    }
  }

  void dismissLikelyMissedReminder() {
    if (!_hasLikelyMissedReminder) return;
    _hasLikelyMissedReminder = false;
    notifyListeners();
  }

  Future<void> openBatterySettingsForMissedReminder() async {
    final api = _notificationApi();
    if (api == null) return;
    final opened = await api.openClassReminderBatterySettings();
    if (opened) dismissLikelyMissedReminder();
  }

  ClassReminderRule? ruleFor(ScheduleEntry entry) {
    final canonical = CanonicalClassName.fromTitle(entry.title);
    return _oneTimeRulesByOccurrence[_occurrenceRuleKey(
          canonical,
          entry.start,
        )] ??
        _recurringRulesByTitle[canonical];
  }

  bool hasReminderForTitle(String title) {
    final canonical = CanonicalClassName.fromTitle(title);
    return _rules.any((rule) => rule.canonicalTitle == canonical);
  }

  Future<void> removeRemindersForTitle(String title) async {
    final canonical = CanonicalClassName.fromTitle(title);
    final ruleIds = _rules
        .where((rule) => rule.canonicalTitle == canonical)
        .map((rule) => rule.id)
        .toList(growable: false);
    if (ruleIds.isEmpty) return;
    await _repository.applyRuleChanges(
      upserts: const [],
      removedRuleIds: ruleIds,
    );
    await _reloadRules();
    await reconcileUpcoming(waitForCompletion: false);
  }

  Future<ReminderActivationResult> saveReminder({
    required ScheduleEntry entry,
    required Duration offset,
    required ClassReminderScope scope,
  }) async {
    if (!entry.start.isAfter(_now())) {
      return ReminderActivationResult.ignoredPastEvent;
    }
    await refreshPermissionState(scheduleWhenRestored: false);
    if (!_permissionsGranted)
      return ReminderActivationResult.permissionsRequired;

    final canonical = CanonicalClassName.fromTitle(entry.title);
    final obsoleteRuleIds = _applicableRuleIds(entry, canonical: canonical);
    final rule = ClassReminderRule(
      id: ClassReminderIdentity.ruleId(
        scope: scope,
        canonicalTitle: canonical,
        sourceIdentity: _sourceProvider.currentSourceIdentity,
        occurrenceStart: scope == ClassReminderScope.oneTime
            ? entry.start
            : null,
      ),
      scope: scope,
      canonicalTitle: canonical,
      offset: offset,
      sourceIdentity: _sourceProvider.currentSourceIdentity,
      occurrenceStart: scope == ClassReminderScope.oneTime ? entry.start : null,
      occurrenceEnd: scope == ClassReminderScope.oneTime ? entry.end : null,
    );
    await _repository.applyRuleChanges(
      upserts: [rule],
      removedRuleIds: obsoleteRuleIds.where((id) => id != rule.id).toList(),
    );
    await _reloadRules();
    await reconcileUpcoming(waitForCompletion: false);
    return ReminderActivationResult.active;
  }

  Future<void> removeReminder(ScheduleEntry entry) async {
    final ruleIds = _applicableRuleIds(
      entry,
      canonical: CanonicalClassName.fromTitle(entry.title),
    );
    await _repository.applyRuleChanges(
      upserts: const [],
      removedRuleIds: ruleIds,
    );
    await _reloadRules();
    await reconcileUpcoming(waitForCompletion: false);
  }

  Future<void> clearForSourceChange({String? sourceIdentity}) async {
    final identity = sourceIdentity ?? _activeSourceIdentity;
    await _queue.runSerialized(() async {
      await _pauseSource(identity);
      await _repository.clearSource(identity);
      _reloadRevision += 1;
      _rules = const [];
      _rebuildRuleIndexes();
      _activeSourceIdentity = 'none';
      notifyListeners();
    });
  }

  Future<void> waitForSourceChange() => _sourceChangeFuture;

  Future<void> reconcileUpcoming({required bool waitForCompletion}) async {
    final now = _now();
    final end = now.add(upcomingWindow);
    final schedule = await _scheduleProvider.getUnfilteredCachedSchedule(
      now,
      end,
    );
    _enqueue(schedule, now, end);
    if (waitForCompletion) await _queue.drain();
  }

  void _scheduleUpdated(Schedule schedule, DateTime start, DateTime end) {
    if (!hasReminders) return;
    _enqueue(schedule, start, end);
  }

  void _sourceChanged(ScheduleSource _, bool setupSuccess) {
    if (!setupSuccess) return;
    _sourceChangeFuture = () async {
      final previousIdentity = _activeSourceIdentity;
      final currentIdentity = _sourceProvider.currentSourceIdentity;
      if (previousIdentity != 'none' && previousIdentity != currentIdentity) {
        await _queue.runSerialized(() async {
          await _pauseSource(previousIdentity);
          await _repository.clearSource(previousIdentity);
        });
      }
      await _reloadRules();
      if (hasReminders && permissionsGranted) {
        await reconcileUpcoming(waitForCompletion: false);
      }
    }();
    unawaited(
      _sourceChangeFuture.catchError((Object error, StackTrace trace) async {
        await _reportQueueFailure(error, trace);
      }),
    );
  }

  void _enqueue(Schedule schedule, DateTime start, DateTime end) {
    _queue.enqueue(
      ReminderSyncRequest(
        schedule: schedule,
        start: start,
        end: end,
        sourceIdentity: _sourceProvider.currentSourceIdentity,
        sourceGeneration: _sourceProvider.sourceGeneration,
      ),
    );
  }

  Future<void> _processRequest(ReminderSyncRequest request) async {
    await refreshPermissionState(scheduleWhenRestored: false);
    if (!_permissionStateKnown) return;
    if (!_permissionsGranted) {
      await _coordinator.pauseWindow(
        start: request.start,
        end: request.end,
        sourceIdentity: request.sourceIdentity,
      );
      return;
    }

    final queueWait = _now().difference(request.enqueuedAt);
    await PerformanceTelemetry.instance.measureTask(
      'schedule.reminders.reconcile',
      args: {
        'windowStart': _dateOnly(request.start),
        'windowEnd': _dateOnly(request.end),
        'queueWaitMs': queueWait.inMilliseconds,
        'coalescedRequestCount': request.coalescedRequestCount,
      },
      action: (task) async {
        final result = await _coordinator.reconcile(
          schedule: request.schedule,
          start: request.start,
          end: request.end,
          sourceIdentity: request.sourceIdentity,
        );
        task.setData('scheduleEntriesExamined', result.scheduleEntriesExamined);
        task.setData('reminderRulesLoaded', result.reminderRulesLoaded);
        task.setData('manifestRowsLoaded', result.manifestRowsLoaded);
        task.setData('alarmsScheduled', result.alarmsScheduled);
        task.setData('alarmsCancelled', result.alarmsCancelled);
        task.setData('expiredRowsDeleted', result.expiredRowsDeleted);
      },
    );
    await _reloadRules();
  }

  List<String> _applicableRuleIds(
    ScheduleEntry entry, {
    required String canonical,
  }) {
    final applicable = _rules.where(
      (rule) =>
          rule.canonicalTitle == canonical &&
          (rule.scope == ClassReminderScope.recurring ||
              rule.occurrenceStart == entry.start),
    );
    return applicable.map((rule) => rule.id).toList(growable: false);
  }

  Future<void> _reloadRules() async {
    final revision = ++_reloadRevision;
    final sourceIdentity = _sourceProvider.currentSourceIdentity;
    final rules = sourceIdentity == 'none'
        ? const <ClassReminderRule>[]
        : await _repository.loadRelevantRules(
            sourceIdentity: sourceIdentity,
            now: _now(),
          );
    if (revision != _reloadRevision ||
        sourceIdentity != _sourceProvider.currentSourceIdentity) {
      return;
    }
    final sortedRules = List<ClassReminderRule>.from(rules)
      ..sort((left, right) => left.id.compareTo(right.id));
    final didChange =
        _activeSourceIdentity != sourceIdentity ||
        !_sameRules(_rules, sortedRules);
    _activeSourceIdentity = sourceIdentity;
    _rules = sortedRules;
    _rebuildRuleIndexes();
    if (didChange) notifyListeners();
  }

  void _rebuildRuleIndexes() {
    _recurringRulesByTitle = {
      for (final rule in _rules)
        if (rule.scope == ClassReminderScope.recurring)
          rule.canonicalTitle: rule,
    };
    _oneTimeRulesByOccurrence = {
      for (final rule in _rules)
        if (rule.scope == ClassReminderScope.oneTime &&
            rule.occurrenceStart != null)
          _occurrenceRuleKey(rule.canonicalTitle, rule.occurrenceStart!): rule,
    };
  }

  String _occurrenceRuleKey(String canonicalTitle, DateTime start) =>
      '$canonicalTitle|${start.toUtc().millisecondsSinceEpoch}';

  bool _sameRules(
    List<ClassReminderRule> previous,
    List<ClassReminderRule> next,
  ) {
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index++) {
      final left = previous[index];
      final right = next[index];
      if (left.id != right.id ||
          left.scope != right.scope ||
          left.canonicalTitle != right.canonicalTitle ||
          left.offset != right.offset ||
          left.sourceIdentity != right.sourceIdentity ||
          left.occurrenceStart != right.occurrenceStart ||
          left.occurrenceEnd != right.occurrenceEnd) {
        return false;
      }
    }
    return true;
  }

  Future<void> _pauseSource(String sourceIdentity) async {
    if (sourceIdentity == 'none') return;
    final manifest = await _repository.loadManifestForSource(sourceIdentity);
    for (final row in manifest) {
      await _scheduler.cancel(row.notificationId);
    }
    if (manifest.isNotEmpty) {
      await _repository.applyManifestChanges(
        upserts: const [],
        removals: manifest,
      );
    }
  }

  Future<void> _cleanupIfNeeded({bool force = false}) async {
    final now = _now();
    if (!force &&
        _lastCleanup != null &&
        now.difference(_lastCleanup!) < resumeCleanupStaleness) {
      return;
    }
    try {
      await _repository.deleteExpired(now);
      _lastCleanup = now;
    } catch (error, trace) {
      await _reportQueueFailure(error, trace);
    }
  }

  Future<void> _detectLikelyMissedReminders() async {
    if (!_permissionStateKnown || !_permissionsGranted) return;
    final sourceIdentity = _sourceProvider.currentSourceIdentity;
    if (sourceIdentity == 'none') return;
    final api = _notificationApi();
    if (api == null) return;

    try {
      final cutoff = _now().subtract(missedReminderGracePeriod);
      final manifest = await _repository.loadManifestForSource(sourceIdentity);
      final overdue = manifest
          .where((row) => !row.scheduledTime.isAfter(cutoff))
          .toList(growable: false);
      if (overdue.isEmpty) return;

      final pendingIds = await api.pendingNotificationIds();
      final missed = overdue
          .where((row) => pendingIds.contains(row.notificationId))
          .toList(growable: false);
      if (missed.isEmpty) return;

      for (final row in missed) {
        await _scheduler.cancel(row.notificationId);
      }
      await _repository.applyManifestChanges(
        upserts: const [],
        removals: missed,
      );
      if (!_hasLikelyMissedReminder) {
        _hasLikelyMissedReminder = true;
        notifyListeners();
      }
    } catch (error, trace) {
      await _reportQueueFailure(error, trace);
    }
  }

  Future<void> _reportQueueFailure(Object error, StackTrace trace) {
    return AppDiagnostics.instance.reportCaughtException(
      error,
      trace,
      message: 'Class reminder reconciliation failed',
      tags: {'feature': 'class_reminders'},
    );
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _scheduleProvider.removeSchedulePersistedCallback(_scheduleUpdated);
    _sourceProvider.removeDidChangeScheduleSourceCallback(_sourceChanged);
    super.dispose();
  }
}
