import 'dart:async';
import 'dart:math';

import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:dualmate/common/logging/crash_reporting.dart';
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

void _debugScheduleError(String message, Object error, StackTrace trace) {
  if (kDebugMode) {
    debugPrint('$message: $error');
    debugPrint('$trace');
  }
}

class WeeklyScheduleViewModel extends BaseViewModel {
  static const Duration weekDuration = Duration(days: 7);
  static const Duration _initialRefreshDelay = Duration(seconds: 8);
  static const Duration _visibleRefreshDebounceDelay = Duration(
    milliseconds: 2500,
  );
  static const int _maxRetainedWeeks = 12;

  final ScheduleProvider scheduleProvider;
  final ScheduleSourceProvider scheduleSourceProvider;
  final DateTime Function() _nowProvider;

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
  bool initializeFailed = false;

  bool isUpdating = false;
  final ScheduleUpdateRequestGate _updateRequestGate =
      ScheduleUpdateRequestGate(minInterval: const Duration(seconds: 1));
  final ScheduleFreshnessGate _freshnessGate = ScheduleFreshnessGate();
  final ScheduleFreshnessGate _entryRefreshGate = ScheduleFreshnessGate(
    staleAfter: const Duration(minutes: 20),
  );
  Schedule? weekSchedule;
  Schedule? _lastCachedSchedule;
  final Map<String, ScheduleFreshnessGate> _windowFreshnessGates = {};
  final Map<String, Schedule> _memoryWeekCache = {};
  final Map<String, Future<void>> _prefetchInFlight = {};
  Timer? _windowRefreshTimer;

  String? scheduleUrl;

  DateTime get now => _nowProvider();

  bool get visibleWeekNeedsInitialFetch {
    if (!_hasCurrentDateRange) {
      return false;
    }
    return _needsInitialFetchForWindow(currentDateStart, currentDateEnd);
  }

  Timer? _errorResetTimer;
  Timer? _updateNowTimer;
  Timer? _visibleRefreshDebounce;
  Timer? _initialRefreshTimer;

  bool _isDisposed = false;

  final CancelableMutex _updateMutex = CancelableMutex();

  DateTime? _widgetLockedStart;
  DateTime? _widgetLockedEnd;
  DateTime? _widgetLockExpiresAt;
  int _visibleUpdateRequestId = 0;

  DateTime? lastRequestedStart;
  DateTime? lastRequestedEnd;

  bool _initialized = false;
  DateTime? _lastWarmedWeekStart;

  WeeklyScheduleViewModel(
    this.scheduleProvider,
    this.scheduleSourceProvider, {
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now {
    final initialStart = _resolveInitialWeekStart(nowProvider);
    currentDateStart = initialStart;
    currentDateEnd = toNextWeek(initialStart);
  }

  static DateTime _resolveInitialWeekStart(DateTime Function()? nowProvider) {
    final now = (nowProvider ?? DateTime.now)();
    return toStartOfDay(toDayOfWeek(now, DateTime.monday));
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _initViewModel();
    } catch (error, trace) {
      initializeFailed = true;
      notifyIfMounted("initializeFailed");
      _debugScheduleError("Weekly schedule init failed", error, trace);
      await reportException(error, trace);
    }
  }

  static WeeklyDisplayRange resolveWeeklyDisplayRange(
    DateTime referenceStart,
    Schedule? schedule,
  ) {
    final weekStart = toStartOfDay(
      toDayOfWeek(referenceStart, DateTime.monday),
    );
    final weekEnd = toStartOfDay(toDayOfWeek(referenceStart, DateTime.friday));

    if (schedule == null) {
      return WeeklyDisplayRange(weekStart, weekEnd);
    }

    var displayEnd = weekEnd;
    final saturday = toStartOfDay(
      toDayOfWeek(referenceStart, DateTime.saturday),
    );

    if (_hasEntriesOnDay(schedule, saturday)) {
      displayEnd = saturday;
    }

    return WeeklyDisplayRange(weekStart, displayEnd);
  }

  Future<void> _initViewModel() async {
    currentDateStart = toStartOfDay(toDayOfWeek(now, DateTime.monday));
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

      scheduleSourceProvider.addDidChangeScheduleSourceCallback(
        _onDidChangeScheduleSource,
      );
    } catch (error, trace) {
      initializeFailed = true;
      notifyIfMounted("initializeFailed");
      _debugScheduleError("Weekly schedule init failed", error, trace);
      await reportException(error, trace);
      ensureUpdateNowTimerRunning();
      _ensureWindowRefreshTimer();
    }
  }

  void _scheduleInitialRefresh() {
    _initialRefreshTimer?.cancel();
    _initialRefreshTimer = Timer(_initialRefreshDelay, () async {
      if (_isDisposed) return;
      try {
        if (!scheduleSourceProvider.didSetupCorrectly()) {
          return;
        }
        await updateSchedule(currentDateStart, currentDateEnd);
      } catch (error, trace) {
        _debugScheduleError("Weekly schedule refresh failed", error, trace);
        await reportException(error, trace);
      }
    });
  }

  void _ensureWindowRefreshTimer() {
    _windowRefreshTimer?.cancel();
    _windowRefreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => refreshWidgetRangeInBackground(),
    );
  }

  Future<void> refreshWidgetRangeInBackground() async {
    if (_isDisposed) return;
    var start = toStartOfDay(now);
    var end = addDays(start, 14);
    try {
      // Keep widget data fresh without changing the currently visible week.
      await updateSchedule(start, end, force: true, applyToVisibleState: false);
    } catch (error, trace) {
      _debugScheduleError(
        "Weekly schedule widget refresh failed",
        error,
        trace,
      );
      await reportException(error, trace);
    }
  }

  Future<void> _onDidChangeScheduleSource(
    ScheduleSource newSource,
    bool setupSuccess,
  ) async {
    if (setupSuccess) {
      try {
        _memoryWeekCache.clear();
        _windowFreshnessGates.clear();
        _lastWarmedWeekStart = null;
        _freshnessGate.reset();
        _entryRefreshGate.reset();
        if (weekSchedule == null) {
          await _openWeekFromCache(currentDateStart, currentDateEnd);
        }
        if (_isDisposed) return;
        await updateSchedule(currentDateStart, currentDateEnd, force: true);
      } catch (error, trace) {
        _debugScheduleError(
          "Weekly schedule source refresh failed",
          error,
          trace,
        );
        await reportException(error, trace);
      }
    }
  }

  void _setSchedule(Schedule? schedule, DateTime start, DateTime end) {
    if (schedule != null && initializeFailed) {
      initializeFailed = false;
      notifyIfMounted("initializeFailed");
    }
    final shouldWarmAdjacent =
        _hasCurrentDateRange && !isAtSameDay(currentDateStart, start);
    weekSchedule = schedule;
    _lastCachedSchedule = schedule;
    if (schedule != null) {
      _memoryWeekCache[_windowKey(start, end)] = schedule;
    } else {
      _memoryWeekCache.remove(_windowKey(start, end));
    }
    if (_hasCurrentDateRange) {
      didUpdateScheduleIntoFuture = currentDateStart.isBefore(start);
    } else {
      didUpdateScheduleIntoFuture = false;
      _hasCurrentDateRange = true;
    }
    currentDateStart = start;
    currentDateEnd = end;
    _evictDistantWindowData(start);

    if (weekSchedule != null) {
      var displayRange = resolveWeeklyDisplayRange(
        currentDateStart,
        weekSchedule,
      );
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
    if (shouldWarmAdjacent && _lastWarmedWeekStart != start) {
      _lastWarmedWeekStart = start;
      unawaited(_warmAdjacentWeeks(start));
    }
  }

  Future nextWeek() async {
    final nextStart = toNextWeek(currentDateStart);
    final nextEnd = toNextWeek(currentDateEnd);
    await _openWeekFromCache(nextStart, nextEnd);
    _debounceVisibleRefresh(nextStart, nextEnd);
  }

  Future previousWeek() async {
    final previousStart = toPreviousWeek(currentDateStart);
    final previousEnd = toPreviousWeek(currentDateEnd);
    await _openWeekFromCache(previousStart, previousEnd);
    _debounceVisibleRefresh(previousStart, previousEnd);
  }

  Future goToToday() async {
    currentDateStart = toStartOfDay(toDayOfWeek(now, DateTime.monday));
    currentDateEnd = toNextWeek(currentDateStart);
    await _openWeekFromCache(currentDateStart, currentDateEnd);
    _debounceVisibleRefresh(currentDateStart, currentDateEnd);
  }

  Future openWeekContaining(DateTime date) async {
    final weekStart = toStartOfDay(toDayOfWeek(date, DateTime.monday));
    final weekEnd = toNextWeek(weekStart);
    await _openWeekFromCache(weekStart, weekEnd);
    _debounceVisibleRefresh(weekStart, weekEnd);
  }

  Future<void> refreshVisibleWeek() {
    return updateSchedule(
      currentDateStart,
      currentDateEnd,
      force: true,
      awaitRefresh: true,
    );
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
      final cacheKey = _windowKey(start, end);
      final cachedSchedule =
          getCachedWeek(start, end) ??
          await scheduleProvider.getCachedSchedule(start, end);
      if (_isDisposed) return;
      _memoryWeekCache[cacheKey] = cachedSchedule;
      _setSchedule(cachedSchedule, start, end);
    } catch (error, trace) {
      _debugScheduleError("Failed to open cached week", error, trace);
      await reportException(error, trace);
    }
  }

  Future updateSchedule(
    DateTime start,
    DateTime end, {
    bool force = false,
    bool applyToVisibleState = true,
    bool awaitRefresh = false,
  }) async {
    if (_isDisposed) return;

    if (_shouldSkipUpdate(start, end)) {
      return;
    }

    final nowValue = now;
    if (!_updateRequestGate.shouldAllow(start, end, nowValue, force: force)) {
      return;
    }

    if (!force && !_entryRefreshGate.isStale(start, end, nowValue)) {
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

    int? visibleUpdateRequestId;
    var launchedBackgroundRefresh = false;

    try {
      if (applyToVisibleState) {
        visibleUpdateRequestId = ++_visibleUpdateRequestId;
        isUpdating = true;
        notifyIfMounted("isUpdating");
      }

      if (!scheduleSourceProvider.didSetupCorrectly()) {
        if (applyToVisibleState) {
          updateFailed = true;
          notifyIfMounted("updateFailed");
          _cancelErrorInFuture();
        }
        _updateMutex.cancel();
        return;
      }

      launchedBackgroundRefresh = await _doUpdateSchedule(
        start,
        end,
        visibleUpdateRequestId: visibleUpdateRequestId,
        applyToVisibleState: applyToVisibleState,
        awaitRefresh: awaitRefresh,
        origin: applyToVisibleState
            ? ScheduleRefreshOrigin.userBrowsing
            : ScheduleRefreshOrigin.foregroundMaintenance,
      );
    } finally {
      _updateMutex.release();
      if (applyToVisibleState && !launchedBackgroundRefresh) {
        _endVisibleUpdateIfCurrent(visibleUpdateRequestId);
      }
    }
  }

  Future<bool> _doUpdateSchedule(
    DateTime start,
    DateTime end, {
    int? visibleUpdateRequestId,
    bool applyToVisibleState = true,
    bool awaitRefresh = false,
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    final task = PerformanceTelemetry.instance.startTask(
      'schedule.refresh',
      args: {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'origin': origin.name,
        'applyToVisibleState': applyToVisibleState,
      },
    );

    var cancellationToken = _updateMutex.token;

    scheduleUrl = null;

    final cacheTask = PerformanceTelemetry.instance.startTask(
      'schedule.cache',
      args: {'start': start.toIso8601String(), 'end': end.toIso8601String()},
    );
    var cacheKey = _windowKey(start, end);
    var cachedSchedule =
        _memoryWeekCache[cacheKey] ??
        await scheduleProvider.getCachedSchedule(start, end);
    _memoryWeekCache[cacheKey] = cachedSchedule;
    unawaited(cacheTask.finish());
    cancellationToken.throwIfCancelled();
    if (_isDisposed) return false;

    if (applyToVisibleState) {
      _setSchedule(cachedSchedule, start, end);
    }

    final nowValue = now;
    final shouldForceFetch =
        awaitRefresh ||
        (cachedSchedule.entries.isEmpty &&
            scheduleSourceProvider.currentScheduleSource.canQuery());
    final isStale = shouldForceFetch || _isWindowStale(start, end, nowValue);

    if (!isStale) {
      unawaited(task.finish());
      return false;
    }

    final refreshFuture = _refreshScheduleInBackground(
      start,
      end,
      cancellationToken,
      task,
      visibleUpdateRequestId: visibleUpdateRequestId,
      applyToVisibleState: applyToVisibleState,
      origin: origin,
    );

    if (awaitRefresh) {
      await refreshFuture;
    } else {
      unawaited(refreshFuture);
    }

    return true;
  }

  Future<void> _refreshScheduleInBackground(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken,
    PerformanceTelemetryTask task, {
    int? visibleUpdateRequestId,
    bool applyToVisibleState = true,
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    ScheduleQueryResult? updatedSchedule;
    try {
      try {
        updatedSchedule = await _readScheduleFromService(
          start,
          end,
          cancellationToken,
          origin: origin,
        );
        _freshnessGate.markFetched(start, end, now);
        _markWindowFetched(start, end, now);
      } on OperationCancelledException {
        return;
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint("Schedule update failed: $e");
        }
        task.setTag('result', 'failed');
        task.setData('error', '$e');
        await reportException(e, stack);
        await task.fail(e);
      }

      try {
        cancellationToken.throwIfCancelled();
      } on OperationCancelledException {
        return;
      }

      if (_isDisposed) {
        return;
      }

      if (!applyToVisibleState) {
        return;
      }

      if (currentDateStart != start || currentDateEnd != end) {
        return;
      }

      if (updatedSchedule != null) {
        var schedule = updatedSchedule.schedule;
        _memoryWeekCache[_windowKey(start, end)] = schedule;

        _setSchedule(schedule, start, end);

        _hasQueryErrors = updatedSchedule.hasError;
        notifyIfMounted("hasQueryErrors");

        if (updatedSchedule.hasError) {
          _queryFailedCallback?.call();
        }

        scheduleUrl = schedule.urls.isNotEmpty ? schedule.urls[0] : null;
      }

      if (updatedSchedule != null) {
        _entryRefreshGate.markFetched(start, end, now);
      }

      updateFailed = (updatedSchedule == null);
      notifyIfMounted("updateFailed");

      if (updateFailed) {
        _cancelErrorInFuture();
      }
    } catch (error, trace) {
      _debugScheduleError(
        "Weekly schedule background refresh failed",
        error,
        trace,
      );
      await AppDiagnostics.instance.reportCaughtException(
        error,
        trace,
        message: 'Weekly schedule background refresh failed',
        tags: {'feature': 'schedule', 'origin': origin.name},
        contexts: {
          'schedule_refresh': {
            'start': start.toIso8601String(),
            'end': end.toIso8601String(),
            'applyToVisibleState': applyToVisibleState,
          },
        },
      );
      await task.fail(error);
    } finally {
      if (applyToVisibleState) {
        _endVisibleUpdateIfCurrent(visibleUpdateRequestId);
      }
      if (task.isFinished) return;
      await task.finish();
    }
  }

  void _endVisibleUpdateIfCurrent(int? requestId) {
    if (requestId == null) return;
    if (requestId != _visibleUpdateRequestId) {
      return;
    }
    if (!isUpdating) {
      return;
    }
    isUpdating = false;
    notifyIfMounted("isUpdating");
  }

  Future<ScheduleQueryResult?> _readScheduleFromService(
    DateTime start,
    DateTime end,
    CancellationToken token, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    try {
      return await scheduleProvider.getUpdatedSchedule(
        start,
        end,
        token,
        origin: origin,
      );
    } on ScheduleQueryFailedException {
      return null;
    }
  }

  void _cancelErrorInFuture() {
    _errorResetTimer?.cancel();

    _errorResetTimer = Timer(const Duration(seconds: 5), () {
      if (_isDisposed) return;
      updateFailed = false;
      notifyIfMounted("updateFailed");
    });
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

  bool _needsInitialFetchForWindow(DateTime start, DateTime end) {
    return !_windowFreshnessGates.containsKey(_windowKey(start, end));
  }

  void _markWindowFetched(DateTime start, DateTime end, DateTime now) {
    var key = _windowKey(start, end);
    var gate = _windowFreshnessGates[key] ??= ScheduleFreshnessGate();
    gate.markFetched(start, end, now);
  }

  String _windowKey(DateTime start, DateTime end) {
    return '${start.toIso8601String()}_${end.toIso8601String()}';
  }

  Future<void> _warmAdjacentWeeks(DateTime weekStart) async {
    if (_isDisposed) return;
    final previousStart = toPreviousWeek(weekStart);
    final nextStart = toNextWeek(weekStart);
    final previousEnd = toNextWeek(previousStart);
    final nextEnd = toNextWeek(nextStart);

    final previousKey = _windowKey(previousStart, previousEnd);
    final nextKey = _windowKey(nextStart, nextEnd);

    if (!_memoryWeekCache.containsKey(previousKey)) {
      try {
        _memoryWeekCache[previousKey] = await scheduleProvider
            .getCachedSchedule(previousStart, previousEnd);
      } catch (_) {}
    }

    if (_isDisposed) return;

    if (!_memoryWeekCache.containsKey(nextKey)) {
      try {
        _memoryWeekCache[nextKey] = await scheduleProvider.getCachedSchedule(
          nextStart,
          nextEnd,
        );
      } catch (_) {}
    }

    _evictDistantWindowData(weekStart);
  }

  Schedule? getCachedWeek(DateTime start, DateTime end) {
    final cacheKey = _windowKey(start, end);
    final cachedSchedule = _memoryWeekCache[cacheKey];
    if (cachedSchedule != null) {
      return cachedSchedule;
    }

    if (currentDateStart == start && currentDateEnd == end) {
      return weekSchedule;
    }
    return null;
  }

  Future<void> prefetchWeek(DateTime start, DateTime end) async {
    if (_isDisposed) return;
    final cacheKey = _windowKey(start, end);
    if (_memoryWeekCache.containsKey(cacheKey)) {
      return;
    }

    final existingRequest = _prefetchInFlight[cacheKey];
    if (existingRequest != null) {
      await existingRequest;
      return;
    }

    final request = _prefetchWeekInternal(cacheKey, start, end);
    _prefetchInFlight[cacheKey] = request;
    await request;
  }

  Future<void> _prefetchWeekInternal(
    String cacheKey,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final schedule = await scheduleProvider.getCachedSchedule(start, end);
      if (_isDisposed) return;
      _memoryWeekCache[cacheKey] = schedule;
    } catch (_) {
      // Best-effort warmup only.
    } finally {
      _prefetchInFlight.remove(cacheKey);
    }
  }

  void _debounceVisibleRefresh(DateTime start, DateTime end) {
    _visibleRefreshDebounce?.cancel();
    _visibleRefreshDebounce = Timer(_visibleRefreshDebounceDelay, () {
      if (_isDisposed) return;
      unawaited(updateSchedule(start, end));
    });
  }

  void _evictDistantWindowData(DateTime centerWeekStart) {
    if (_memoryWeekCache.length <= _maxRetainedWeeks &&
        _windowFreshnessGates.length <= _maxRetainedWeeks) {
      return;
    }

    final sortedKeys = _memoryWeekCache.keys.toList()
      ..sort((a, b) {
        final distanceA = _windowDistanceFromCenter(a, centerWeekStart).abs();
        final distanceB = _windowDistanceFromCenter(b, centerWeekStart).abs();
        return distanceA.compareTo(distanceB);
      });

    final retained = sortedKeys.take(_maxRetainedWeeks).toSet();
    _memoryWeekCache.removeWhere((key, _) => !retained.contains(key));
    _windowFreshnessGates.removeWhere((key, _) => !retained.contains(key));
  }

  int _windowDistanceFromCenter(String key, DateTime centerWeekStart) {
    final separator = key.indexOf('_');
    if (separator <= 0) return 1 << 20;

    final startString = key.substring(0, separator);
    final parsedStart = DateTime.tryParse(startString);
    if (parsedStart == null) return 1 << 20;

    return parsedStart.difference(centerWeekStart).inDays ~/ 7;
  }

  @override
  void dispose() {
    _isDisposed = true;

    scheduleSourceProvider.removeDidChangeScheduleSourceCallback(
      _onDidChangeScheduleSource,
    );

    _updateMutex.cancel();

    _updateNowTimer?.cancel();
    _windowRefreshTimer?.cancel();
    _visibleRefreshDebounce?.cancel();
    _initialRefreshTimer?.cancel();

    _errorResetTimer?.cancel();
    _prefetchInFlight.clear();

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
    _widgetLockExpiresAt = now.add(const Duration(seconds: 6));
  }

  bool _shouldSkipUpdate(DateTime start, DateTime end) {
    final expiresAt = _widgetLockExpiresAt;
    if (expiresAt == null) return false;
    if (now.isAfter(expiresAt)) {
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
