import 'dart:async';
import 'dart:math';

import 'dart:developer' as developer;

import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/util/cancelable_mutex.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_freshness_gate.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_update_request_gate.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class WeeklyScheduleViewModel extends BaseViewModel {
  static const Duration weekDuration = Duration(days: 7);

  final ScheduleProvider scheduleProvider;
  final ScheduleSourceProvider scheduleSourceProvider;

  late DateTime currentDateStart;
  late DateTime currentDateEnd;

  bool _hasCurrentDateRange = false;

  DateTime? clippedDateStart;
  DateTime? clippedDateEnd;

  bool didUpdateScheduleIntoFuture = true;

  int displayStartHour = 7;
  int displayEndHour = 17;

  bool _hasQueryErrors = false;

  bool get hasQueryErrors => _hasQueryErrors;

  VoidCallback? _queryFailedCallback;

  bool updateFailed = false;

  bool isUpdating = false;
  final ScheduleUpdateRequestGate _updateRequestGate =
      ScheduleUpdateRequestGate(minInterval: const Duration(seconds: 1));
  final ScheduleFreshnessGate _freshnessGate = ScheduleFreshnessGate();
  final ScheduleFreshnessGate _entryRefreshGate =
      ScheduleFreshnessGate(staleAfter: const Duration(minutes: 20));
  Schedule? weekSchedule;
  Schedule? _lastCachedSchedule;
  final Map<String, ScheduleFreshnessGate> _windowFreshnessGates = {};
  Timer? _windowRefreshTimer;

  String? scheduleUrl;

  DateTime get now => DateTime.now();

  Timer? _errorResetTimer;
  Timer? _updateNowTimer;

  bool _isDisposed = false;

  final CancelableMutex _updateMutex = CancelableMutex();

  DateTime? _widgetLockedStart;
  DateTime? _widgetLockedEnd;
  DateTime? _widgetLockExpiresAt;

  DateTime? lastRequestedStart;
  DateTime? lastRequestedEnd;

  bool _initialized = false;

  WeeklyScheduleViewModel(
    this.scheduleProvider,
    this.scheduleSourceProvider,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _initViewModel();
    } catch (error, trace) {
      print("Weekly schedule init failed: $error");
      print(trace);
    }
  }

  static WeeklyDisplayRange resolveWeeklyDisplayRange(
    DateTime referenceStart,
    Schedule? schedule,
  ) {
    final weekStart =
        toStartOfDay(toDayOfWeek(referenceStart, DateTime.monday));
    final weekEnd = toStartOfDay(toDayOfWeek(referenceStart, DateTime.friday));

    if (schedule == null) {
      return WeeklyDisplayRange(weekStart, weekEnd);
    }

    var displayEnd = weekEnd;
    final saturday =
        toStartOfDay(toDayOfWeek(referenceStart, DateTime.saturday));

    if (_hasEntriesOnDay(schedule, saturday)) {
      displayEnd = saturday;
    }

    return WeeklyDisplayRange(weekStart, displayEnd);
  }

  Future<void> _initViewModel() async {
    currentDateStart =
        toStartOfDay(toDayOfWeek(DateTime.now(), DateTime.monday));
    currentDateEnd = toNextWeek(currentDateStart);
    try {
      if (_lastCachedSchedule != null) {
        // Keep cached schedule for warm starts.
        _setSchedule(_lastCachedSchedule!, currentDateStart, currentDateEnd);
      }
      var cachedSchedule = await scheduleProvider.getCachedSchedule(
        currentDateStart,
        currentDateEnd,
      );
      _setSchedule(cachedSchedule, currentDateStart, currentDateEnd);
      _lastCachedSchedule = cachedSchedule;
      _scheduleInitialRefresh();
      ensureUpdateNowTimerRunning();
      _ensureWindowRefreshTimer();

      scheduleSourceProvider
          .addDidChangeScheduleSourceCallback(_onDidChangeScheduleSource);
    } catch (error, trace) {
      print("Weekly schedule init failed: $error");
      print(trace);
      ensureUpdateNowTimerRunning();
      _ensureWindowRefreshTimer();
    }
  }

  void _scheduleInitialRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_isDisposed) return;
      try {
        await Future.delayed(const Duration(milliseconds: 150));
        if (_isDisposed) return;
        if (!scheduleSourceProvider.didSetupCorrectly()) {
          return;
        }
        await updateSchedule(currentDateStart, currentDateEnd);
      } catch (error, trace) {
        print("Weekly schedule refresh failed: $error");
        print(trace);
      }
    });
  }

  void _ensureWindowRefreshTimer() {
    _windowRefreshTimer?.cancel();
    _windowRefreshTimer = Timer.periodic(
        const Duration(minutes: 15), (_) => _refreshWidgetRange());
  }

  Future<void> _refreshWidgetRange() async {
    if (_isDisposed) return;
    var start = toStartOfDay(DateTime.now());
    var end = addDays(start, 14);
    try {
      await updateSchedule(start, end, force: true);
    } catch (error, trace) {
      print("Weekly schedule widget refresh failed: $error");
      print(trace);
    }
  }

  Future<void> _onDidChangeScheduleSource(
    ScheduleSource newSource,
    bool setupSuccess,
  ) async {
    if (setupSuccess) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_isDisposed) return;
        await updateSchedule(currentDateStart, currentDateEnd);
      } catch (error, trace) {
        print("Weekly schedule source refresh failed: $error");
        print(trace);
      }
    }
  }

  void _setSchedule(Schedule? schedule, DateTime start, DateTime end) {
    weekSchedule = schedule;
    _lastCachedSchedule = schedule;
    if (_hasCurrentDateRange) {
      didUpdateScheduleIntoFuture = currentDateStart.isBefore(start);
    } else {
      didUpdateScheduleIntoFuture = false;
      _hasCurrentDateRange = true;
    }
    currentDateStart = start;
    currentDateEnd = end;

    if (weekSchedule != null) {
      var displayRange =
          resolveWeeklyDisplayRange(currentDateStart, weekSchedule);
      clippedDateStart = displayRange.start;
      clippedDateEnd = displayRange.end;

      displayStartHour = weekSchedule?.getStartTime()?.hour ?? 23;
      displayStartHour = min(7, displayStartHour);

      displayEndHour = weekSchedule?.getEndTime()?.hour ?? 0;
      displayEndHour = max(displayEndHour + 1, 17);
    } else {
      var displayRange = resolveWeeklyDisplayRange(currentDateStart, null);
      clippedDateStart = displayRange.start;
      clippedDateEnd = displayRange.end;
    }

    notifyIfMounted("weekSchedule");
  }

  Future nextWeek() async {
    final nextStart = toNextWeek(currentDateStart);
    final nextEnd = toNextWeek(currentDateEnd);
    await _openWeekFromCache(nextStart, nextEnd);
    await updateSchedule(nextStart, nextEnd);
  }

  Future previousWeek() async {
    final previousStart = toPreviousWeek(currentDateStart);
    final previousEnd = toPreviousWeek(currentDateEnd);
    await _openWeekFromCache(previousStart, previousEnd);
    await updateSchedule(previousStart, previousEnd);
  }

  Future goToToday() async {
    currentDateStart =
        toStartOfDay(toDayOfWeek(DateTime.now(), DateTime.monday));
    currentDateEnd = toNextWeek(currentDateStart);
    await _openWeekFromCache(currentDateStart, currentDateEnd);
    await updateSchedule(currentDateStart, currentDateEnd);
  }

  Future openWeekContaining(DateTime date) async {
    final weekStart = toStartOfDay(toDayOfWeek(date, DateTime.monday));
    final weekEnd = toNextWeek(weekStart);
    await _openWeekFromCache(weekStart, weekEnd);
    await updateSchedule(weekStart, weekEnd);
  }

  Future openWeekContainingFromWidget(DateTime date) async {
    final weekStart = toStartOfDay(toDayOfWeek(date, DateTime.monday));
    final weekEnd = toNextWeek(weekStart);
    _lockWidgetWeek(weekStart, weekEnd);
    _updateMutex.cancel();

    await _openWeekFromCache(weekStart, weekEnd);
    await updateSchedule(weekStart, weekEnd, force: true);
  }

  Future<void> _openWeekFromCache(DateTime start, DateTime end) async {
    try {
      final cachedSchedule =
          await scheduleProvider.getCachedSchedule(start, end);
      if (_isDisposed) return;
      _setSchedule(cachedSchedule, start, end);
    } catch (error, trace) {
      print("Failed to open cached week: $error");
      print(trace);
    }
  }

  Future updateSchedule(DateTime start, DateTime end,
      {bool force = false}) async {
    if (_isDisposed) return;

    if (_shouldSkipUpdate(start, end)) {
      return;
    }

    var now = DateTime.now();
    if (!force && !_updateRequestGate.shouldAllow(start, end, now)) {
      return;
    }

    if (!force && !_entryRefreshGate.isStale(start, end, now)) {
      return;
    }

    lastRequestedEnd = end;
    lastRequestedStart = start;

    await _updateMutex.acquireAndCancelOther();

    if (_isDisposed) {
      _updateMutex.release();
      return;
    }

    if (lastRequestedStart != start || lastRequestedEnd != end) {
      _updateMutex.release();
      return;
    }

    try {
      isUpdating = true;
      notifyIfMounted("isUpdating");

      if (!scheduleSourceProvider.didSetupCorrectly()) {
        updateFailed = true;
        notifyIfMounted("updateFailed");
        _cancelErrorInFuture();
        _updateMutex.cancel();
        return;
      }

      await _doUpdateSchedule(start, end);
    } finally {
      isUpdating = false;
      _updateMutex.release();
      notifyIfMounted("isUpdating");
    }
  }

  Future _doUpdateSchedule(DateTime start, DateTime end) async {
    print("Refreshing schedule...");
    final task = PerformanceTelemetry.instance
        .startTask('schedule.refresh.${start.toIso8601String()}');

    var cancellationToken = _updateMutex.token;

    scheduleUrl = null;

    final cacheTask = PerformanceTelemetry.instance.startTask(
      'schedule.cache.${start.toIso8601String()}',
    );
    var cachedSchedule = await scheduleProvider.getCachedSchedule(start, end);
    cacheTask.finish();
    cancellationToken.throwIfCancelled();
    if (_isDisposed) return;

    _setSchedule(cachedSchedule, start, end);

    final now = DateTime.now();
    final shouldForceFetch = cachedSchedule.entries.isEmpty &&
        scheduleSourceProvider.currentScheduleSource.canQuery();
    final isStale = shouldForceFetch ||
        _freshnessGate.isStale(start, end, now) ||
        _isWindowStale(start, end, now);

    if (!isStale) {
      print("Schedule fresh; skip network fetch");
      task.finish();
      return;
    }

    unawaited(
      _refreshScheduleInBackground(start, end, cancellationToken, task),
    );
  }

  Future<void> _refreshScheduleInBackground(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken,
    developer.TimelineTask task,
  ) async {
    ScheduleQueryResult? updatedSchedule;
    try {
      updatedSchedule = await _readScheduleFromService(
        start,
        end,
        cancellationToken,
      );
      _freshnessGate.markFetched(start, end, DateTime.now());
      _markWindowFetched(start, end, DateTime.now());
    } on OperationCancelledException {
      task.finish();
      return;
    } catch (e) {
      print("Schedule update failed: $e");
    }

    try {
      cancellationToken.throwIfCancelled();
    } on OperationCancelledException {
      task.finish();
      return;
    }

    if (_isDisposed) {
      task.finish();
      return;
    }

    if (currentDateStart != start || currentDateEnd != end) {
      task.finish();
      return;
    }

    try {
      if (updatedSchedule != null) {
        var schedule = updatedSchedule.schedule;

        _setSchedule(schedule, start, end);

        _hasQueryErrors = updatedSchedule.hasError;
        notifyIfMounted("hasQueryErrors");

        if (updatedSchedule.hasError) {
          _queryFailedCallback?.call();
        }

        scheduleUrl = schedule.urls.isNotEmpty ? schedule.urls[0] : null;
      }

      if (updatedSchedule != null) {
        _entryRefreshGate.markFetched(start, end, DateTime.now());
      }

      updateFailed = (updatedSchedule == null);
      notifyIfMounted("updateFailed");

      if (updateFailed) {
        _cancelErrorInFuture();
      }

      print("Refreshing done");
    } catch (error, trace) {
      print("Weekly schedule background refresh failed: $error");
      print(trace);
    } finally {
      task.finish();
    }
  }

  Future<ScheduleQueryResult?> _readScheduleFromService(
    DateTime start,
    DateTime end,
    CancellationToken token,
  ) async {
    try {
      return await scheduleProvider.getUpdatedSchedule(
        start,
        end,
        token,
      );
    } on ScheduleQueryFailedException {
      return null;
    }
  }

  void _cancelErrorInFuture() {
    _errorResetTimer?.cancel();

    _errorResetTimer = Timer(
      const Duration(seconds: 5),
      () {
        if (_isDisposed) return;
        updateFailed = false;
        notifyIfMounted("updateFailed");
      },
    );
  }

  void ensureUpdateNowTimerRunning() {
    if (_updateNowTimer == null || !_updateNowTimer!.isActive) {
      _updateNowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (_isDisposed) return;
        notifyIfMounted("now");
      });
    }
  }

  bool _isWindowStale(DateTime start, DateTime end, DateTime now) {
    var gate = _windowFreshnessGates[_windowKey(start, end)];
    return gate == null || gate.isStale(start, end, now);
  }

  void _markWindowFetched(DateTime start, DateTime end, DateTime now) {
    var key = _windowKey(start, end);
    var gate = _windowFreshnessGates[key] ??= ScheduleFreshnessGate();
    gate.markFetched(start, end, now);
  }

  String _windowKey(DateTime start, DateTime end) {
    return '${start.toIso8601String()}_${end.toIso8601String()}';
  }

  @override
  void dispose() {
    _isDisposed = true;

    scheduleSourceProvider
        .removeDidChangeScheduleSourceCallback(_onDidChangeScheduleSource);

    _updateMutex.cancel();

    _updateNowTimer?.cancel();
    _windowRefreshTimer?.cancel();

    _errorResetTimer?.cancel();

    super.dispose();
  }

  void setQueryFailedCallback(VoidCallback callback) {
    _queryFailedCallback = callback;
  }

  ScheduleEntry? resolveEntryFromPayload(WidgetScheduleEntryPayload payload) {
    final schedule = weekSchedule;
    if (schedule == null) return null;
    return resolveScheduleEntry(schedule.entries, payload);
  }

  void _lockWidgetWeek(DateTime start, DateTime end) {
    _widgetLockedStart = start;
    _widgetLockedEnd = end;
    _widgetLockExpiresAt = DateTime.now().add(const Duration(seconds: 6));
  }

  bool _shouldSkipUpdate(DateTime start, DateTime end) {
    final expiresAt = _widgetLockExpiresAt;
    if (expiresAt == null) return false;
    if (DateTime.now().isAfter(expiresAt)) {
      _widgetLockedStart = null;
      _widgetLockedEnd = null;
      _widgetLockExpiresAt = null;
      return false;
    }
    if (_widgetLockedStart == null || _widgetLockedEnd == null) return false;
    return _widgetLockedStart != start || _widgetLockedEnd != end;
  }
}

class WeeklyDisplayRange {
  final DateTime start;
  final DateTime end;

  WeeklyDisplayRange(this.start, this.end);
}

bool _hasEntriesOnDay(Schedule schedule, DateTime dayStart) {
  final start = toStartOfDay(dayStart);
  final end = tomorrow(start);
  return schedule.trim(start, end).entries.isNotEmpty;
}
