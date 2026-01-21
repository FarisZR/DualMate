import 'dart:convert';

import 'package:dhbwstudentapp/common/data/preferences/preferences_provider.dart';
import 'package:dhbwstudentapp/common/util/cancellation_token.dart';
import 'package:dhbwstudentapp/common/util/date_utils.dart';
import 'package:dhbwstudentapp/date_management/model/important_event.dart';
import 'package:dhbwstudentapp/schedule/model/schedule.dart';
import 'package:dhbwstudentapp/schedule/model/schedule_query_result.dart';
import 'package:dhbwstudentapp/schedule/model/schedule_entry.dart';
import 'package:dhbwstudentapp/schedule/service/rapla/rapla_schedule_source.dart';

class RaplaImportantEventsProvider {
  final PreferencesProvider _preferencesProvider;
  final RaplaScheduleSource _scheduleSource;

  RaplaImportantEventsProvider(
    this._preferencesProvider, {
    RaplaScheduleSource? scheduleSource,
  }) : _scheduleSource = scheduleSource ?? RaplaScheduleSource();

  Future<List<ImportantEvent>> getImportantEvents(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    bool forceRefresh = false,
  }) async {
    var raplaUrl = await _preferencesProvider.getRaplaUrl();
    if (!RaplaScheduleSource.isValidUrl(raplaUrl)) {
      return [];
    }

    var cached = await _readCache(start, end, raplaUrl);
    if (cached != null && !forceRefresh) {
      return cached;
    }

    _scheduleSource.setEndpointUrl(raplaUrl);
    ScheduleQueryResult scheduleResult;
    try {
      scheduleResult =
          await _scheduleSource.querySchedule(start, end, cancellationToken);
    } catch (error, trace) {
      print("Failed to query Rapla schedule");
      print(error);
      print(trace);
      return cached ?? [];
    }

    if (scheduleResult.hasError) {
      return cached ?? [];
    }

    var importantEntries = filterImportantEntries(scheduleResult.schedule);
    var mergedEntries = mergeImportantEntries(importantEntries);
    await _writeCache(start, end, raplaUrl, mergedEntries);
    return mergedEntries;
  }

  List<ScheduleEntry> filterImportantEntries(Schedule schedule) {
    var filteredEntries = schedule.entries
        .where((entry) => _isImportantEntry(entry))
        .toList(growable: false);
    return _dedupeEntries(filteredEntries);
  }

  bool _isImportantEntry(ScheduleEntry entry) {
    return entry.type == ScheduleEntryType.Exam ||
        entry.type == ScheduleEntryType.PublicHoliday ||
        entry.type == ScheduleEntryType.SpecialEvent;
  }

  Future<List<ImportantEvent>?> _readCache(
    DateTime start,
    DateTime end,
    String raplaUrl,
  ) async {
    try {
      var cacheJson = await _preferencesProvider.getRaplaImportantEventsCache();
      if (cacheJson == null || cacheJson.isEmpty) return null;

      var decoded = jsonDecode(cacheJson) as Map<String, dynamic>;
      var cacheStart = DateTime.parse(decoded['start'] as String);
      var cacheEnd = DateTime.parse(decoded['end'] as String);
      var cacheUrl = decoded['raplaUrl'] as String?;
      if (cacheUrl == null || cacheUrl != raplaUrl) {
        return null;
      }
      if (!_isSameMoment(cacheStart, start) || !_isSameMoment(cacheEnd, end)) {
        return null;
      }

      var events = (decoded['events'] as List<dynamic>)
          .map(
              (event) => ImportantEvent.fromJson(event as Map<String, dynamic>))
          .toList(growable: false);
      return events;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    DateTime start,
    DateTime end,
    String raplaUrl,
    List<ImportantEvent> events,
  ) async {
    var payload = {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'raplaUrl': raplaUrl,
      'storedAt': DateTime.now().toIso8601String(),
      'events': events.map((event) => event.toJson()).toList(growable: false),
    };

    await _preferencesProvider
        .setRaplaImportantEventsCache(jsonEncode(payload));
  }

  bool _isSameMoment(DateTime first, DateTime second) {
    return first.isAtSameMomentAs(second);
  }

  List<ScheduleEntry> _dedupeEntries(List<ScheduleEntry> entries) {
    var seenKeys = <String>{};
    var result = <ScheduleEntry>[];

    for (var entry in entries) {
      var key =
          '${entry.title}-${entry.type}-${entry.start.toIso8601String()}-${entry.end.toIso8601String()}';
      if (seenKeys.add(key)) {
        result.add(entry);
      }
    }

    return result;
  }

  List<ImportantEvent> mergeImportantEntries(List<ScheduleEntry> entries) {
    if (entries.isEmpty) return [];

    var grouped = <String, List<ScheduleEntry>>{};
    for (var entry in entries) {
      var key = '${entry.title}-${entry.type}';
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    var mergedEntries = <ImportantEvent>[];
    grouped.forEach((_, groupEntries) {
      groupEntries.sort((a, b) => a.start.compareTo(b.start));
      if (groupEntries.first.type == ScheduleEntryType.Exam) {
        for (var entry in groupEntries) {
          mergedEntries.add(ImportantEvent(
            title: entry.title,
            start: entry.start,
            end: entry.end,
            type: entry.type,
          ));
        }
        return;
      }

      var currentEnd = toStartOfDay(groupEntries.first.start);
      var currentTitle = groupEntries.first.title;
      var currentType = groupEntries.first.type;
      var currentEventStart = groupEntries.first.start;
      var currentEventEnd = groupEntries.first.end;

      void flushCurrent() {
        mergedEntries.add(ImportantEvent(
          title: currentTitle,
          start: currentEventStart,
          end: currentEventEnd,
          type: currentType,
        ));
      }

      for (var i = 1; i < groupEntries.length; i++) {
        var entry = groupEntries[i];
        var entryDate = toStartOfDay(entry.start);

        if (_shouldMerge(entry, currentTitle, currentType, currentEnd)) {
          currentEnd = entryDate;
          if (entry.end.isAfter(currentEventEnd)) {
            currentEventEnd = entry.end;
          }
          continue;
        }

        flushCurrent();
        currentTitle = entry.title;
        currentType = entry.type;
        currentEnd = entryDate;
        currentEventStart = entry.start;
        currentEventEnd = entry.end;
      }

      flushCurrent();
    });

    mergedEntries.sort((a, b) => a.start.compareTo(b.start));
    return mergedEntries;
  }

  bool _shouldMerge(
    ScheduleEntry entry,
    String currentTitle,
    ScheduleEntryType currentType,
    DateTime currentEnd,
  ) {
    if (entry.type != currentType) return false;
    if (entry.title != currentTitle) return false;
    if (entry.type == ScheduleEntryType.Exam) return false;

    var entryDate = toStartOfDay(entry.start);
    return isAtSameDay(entryDate, addDays(currentEnd, 1));
  }
}
