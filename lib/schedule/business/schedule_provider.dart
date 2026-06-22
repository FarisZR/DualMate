import 'dart:collection';
import 'dart:async';
import 'dart:developer' as developer;

import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_diff_calculator.dart';
import 'package:dualmate/schedule/business/schedule_filter.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_information.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/service/schedule_prettifier.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

typedef ScheduleUpdatedCallback =
    Future<void> Function(Schedule schedule, DateTime start, DateTime end);

typedef ScheduleEntryChangedCallback =
    Future<void> Function(
      ScheduleDiff scheduleDiff,
      ScheduleRefreshOrigin origin,
    );

enum ScheduleRefreshOrigin {
  userBrowsing,
  foregroundMaintenance,
  backgroundPeriodic,
}

extension ScheduleRefreshOriginNotificationEligibility
    on ScheduleRefreshOrigin {
  bool get mayNotify => this == ScheduleRefreshOrigin.backgroundPeriodic;
}

class ScheduleProvider {
  static const int _maxCachedWindows = 6;

  final PreferencesProvider _preferencesProvider;
  final ScheduleSourceProvider _scheduleSource;
  final ScheduleEntryRepository _scheduleEntryRepository;
  final ScheduleFilterRepository _scheduleFilterRepository;
  final ScheduleQueryInformationRepository _scheduleQueryInformationRepository;
  final List<ScheduleUpdatedCallback> _scheduleUpdatedCallbacks =
      <ScheduleUpdatedCallback>[];

  late ScheduleFilter _scheduleFilter;

  final List<ScheduleEntryChangedCallback> _scheduleEntryChangedCallbacks =
      <ScheduleEntryChangedCallback>[];

  final LinkedHashMap<String, Schedule> _cachedSchedulesByWindow =
      LinkedHashMap<String, Schedule>();

  ScheduleProvider(
    this._scheduleSource,
    this._scheduleEntryRepository,
    this._scheduleQueryInformationRepository,
    this._preferencesProvider,
    this._scheduleFilterRepository,
  ) {
    _scheduleFilter = ScheduleFilter(_scheduleFilterRepository);
  }

  Future<void> warmScheduleCache(DateTime start, DateTime end) async {
    await getCachedSchedule(start, end);
  }

  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
    final cacheKey = _windowKey(start, end);
    final inMemorySchedule = _cachedSchedulesByWindow.remove(cacheKey);
    if (inMemorySchedule != null) {
      _cachedSchedulesByWindow[cacheKey] = inMemorySchedule;
      return inMemorySchedule;
    }

    var cachedSchedule = await PerformanceTelemetry.instance.measureTask(
      'schedule.cache.read',
      args: {'isCacheHit': false, 'sourceType': _coarseSourceType()},
      action: (task) async {
        final schedule = await _scheduleEntryRepository
            .queryScheduleBetweenDates(start, end);
        task.setData('cachedEntryCount', schedule.entries.length);
        return schedule;
      },
    );

    _debugLog(
      "Read cached schedule with ${cachedSchedule.entries.length} entries",
    );

    cachedSchedule = await PerformanceTelemetry.instance.measureTask(
      'schedule.entries.filter',
      args: {
        'entryCount': cachedSchedule.entries.length,
        'sourceType': _coarseSourceType(),
      },
      action: (task) async {
        final filtered = await _scheduleFilter.filter(cachedSchedule);
        task.setData('filteredEntryCount', filtered.entries.length);
        return filtered;
      },
    );

    _debugLog(
      "Filtered cached schedule has ${cachedSchedule.entries.length} entries",
    );

    _cacheWindow(start, end, cachedSchedule);
    return cachedSchedule;
  }

  Future<DateTime?> getLastQueryTimeForWindow(
    DateTime start,
    DateTime end,
  ) async {
    final queryInformation = await _scheduleQueryInformationRepository
        .getQueryInformationBetweenDates(start, end);

    DateTime? newestQueryTime;
    for (final information in queryInformation) {
      final queryTime = information.queryTime;
      if (newestQueryTime == null || queryTime.isAfter(newestQueryTime)) {
        newestQueryTime = queryTime;
      }
    }

    return newestQueryTime;
  }

  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    _debugLog(
      "Fetching schedule for ${DateFormat.yMd().format(start)} - ${DateFormat.yMd().format(end)}",
    );
    try {
      var updatedSchedule = await PerformanceTelemetry.instance.measureTask(
        'schedule.remote.fetch',
        args: {'sourceType': _coarseSourceType()},
        successStatusForResult: (result) =>
            result.schedule.entries.isEmpty ? 'empty' : 'success',
        action: (task) async {
          final result = await _scheduleSource.currentScheduleSource
              .querySchedule(start, end, cancellationToken);
          task.setData('loadedEntryCount', result.schedule.entries.length);
          return result;
        },
      );

      var schedule = updatedSchedule.schedule;

      schedule = await PerformanceTelemetry.instance.measureTask(
        'schedule.remote.parse',
        args: {
          'entryCount': schedule.entries.length,
          'sourceType': _coarseSourceType(),
        },
        successStatus: updatedSchedule.errors.isEmpty
            ? 'success'
            : 'parse_error',
        action: (task) async {
          var parsedSchedule = schedule;
          if (await _preferencesProvider.getPrettifySchedule()) {
            parsedSchedule = SchedulePrettifier().prettifySchedule(
              parsedSchedule,
            );
          }
          task.setData('loadedEntryCount', parsedSchedule.entries.length);
          return parsedSchedule;
        },
      );

      _debugLog("Schedule returned with ${schedule.entries.length} entries");

      await PerformanceTelemetry.instance.measureTask(
        'schedule.state.apply',
        args: {
          'entryCount': schedule.entries.length,
          'sourceType': _coarseSourceType(),
        },
        action: (_) async {
          await _diffToCache(start, end, schedule, origin);
          await _scheduleEntryRepository.deleteScheduleEntriesBetween(
            start,
            end,
          );
          await _scheduleEntryRepository.saveSchedule(schedule);
          await _scheduleQueryInformationRepository
              .saveScheduleQueryInformation(
                ScheduleQueryInformation(start, end, DateTime.now()),
              );
        },
      );

      schedule = await PerformanceTelemetry.instance.measureTask(
        'schedule.entries.filter',
        args: {
          'entryCount': schedule.entries.length,
          'sourceType': _coarseSourceType(),
        },
        action: (task) async {
          final filtered = await _scheduleFilter.filter(schedule);
          task.setData('filteredEntryCount', filtered.entries.length);
          return filtered;
        },
      );

      _cacheWindow(start, end, schedule);

      _debugLog("Filtered schedule has ${schedule.entries.length} entries");

      for (final error in updatedSchedule.errors) {
        unawaited(
          reportException(
            StateError('Schedule parse error: ${error.object}'),
            StackTrace.fromString(error.trace),
          ),
        );
      }

      for (var c in _scheduleUpdatedCallbacks) {
        await c(schedule, start, end);
      }

      updatedSchedule = ScheduleQueryResult(schedule, updatedSchedule.errors);

      return updatedSchedule;
    } on ScheduleQueryFailedException catch (e, trace) {
      _debugLog("Failed to fetch schedule!");
      _debugLog(e.innerException.toString());
      _debugLog('$trace');
      rethrow;
    }
  }

  Future _diffToCache(
    DateTime start,
    DateTime end,
    Schedule updatedSchedule,
    ScheduleRefreshOrigin origin,
  ) async {
    var oldSchedule = await _scheduleEntryRepository.queryScheduleBetweenDates(
      start,
      end,
    );

    var diff = ScheduleDiffCalculator().calculateDiff(
      oldSchedule,
      updatedSchedule,
    );

    var cleanedDiff = await _cleanDiffFromNewlyQueriedEntries(start, end, diff);

    if (cleanedDiff.didSomethingChange()) {
      for (var c in _scheduleEntryChangedCallbacks) {
        await c(cleanedDiff, origin);
      }
    }
  }

  void addScheduleUpdatedCallback(ScheduleUpdatedCallback callback) {
    _scheduleUpdatedCallbacks.add(callback);
  }

  void removeScheduleUpdatedCallback(ScheduleUpdatedCallback callback) {
    if (_scheduleUpdatedCallbacks.contains(callback))
      _scheduleUpdatedCallbacks.remove(callback);
  }

  void addScheduleEntryChangedCallback(ScheduleEntryChangedCallback callback) {
    _scheduleEntryChangedCallbacks.add(callback);
  }

  void removeScheduleEntryChangedCallback(
    ScheduleEntryChangedCallback callback,
  ) {
    if (_scheduleEntryChangedCallbacks.contains(callback))
      _scheduleEntryChangedCallbacks.remove(callback);
  }

  Future<ScheduleDiff> _cleanDiffFromNewlyQueriedEntries(
    DateTime start,
    DateTime end,
    ScheduleDiff diff,
  ) async {
    var queryInformation = await _scheduleQueryInformationRepository
        .getQueryInformationBetweenDates(start, end);

    var cleanedAddedEntries = <ScheduleEntry>[];

    for (var addedEntry in diff.addedEntries) {
      if (queryInformation.any(
        (i) =>
            addedEntry.end.isAfter(i.start) && addedEntry.start.isBefore(i.end),
      )) {
        cleanedAddedEntries.add(addedEntry);
      }
    }

    return ScheduleDiff(
      addedEntries: cleanedAddedEntries,
      removedEntries: diff.removedEntries,
      updatedEntries: diff.updatedEntries,
    );
  }

  void invalidateScheduleCache() {
    _cachedSchedulesByWindow.clear();
  }

  void _cacheWindow(DateTime start, DateTime end, Schedule schedule) {
    final cacheKey = _windowKey(start, end);
    _cachedSchedulesByWindow.remove(cacheKey);
    _cachedSchedulesByWindow[cacheKey] = schedule;

    while (_cachedSchedulesByWindow.length > _maxCachedWindows) {
      _cachedSchedulesByWindow.remove(_cachedSchedulesByWindow.keys.first);
    }
  }

  String _windowKey(DateTime start, DateTime end) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    return '${normalizedStart.toIso8601String()}_${normalizedEnd.toIso8601String()}';
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    developer.log(message, name: 'schedule_provider');
  }

  String _coarseSourceType() {
    try {
      switch (_scheduleSource.currentScheduleSourceType) {
        case ScheduleSourceType.Rapla:
          return 'rapla';
        case ScheduleSourceType.Ical:
          return 'ical';
        case ScheduleSourceType.Mannheim:
          return 'mannheim';
        case ScheduleSourceType.Dualis:
        case ScheduleSourceType.None:
          return 'unknown';
      }
    } catch (_) {
      return 'unknown';
    }
  }
}
