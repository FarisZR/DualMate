import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/service/rapla/rapla_schedule_source.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

class RaplaImportantEventsProvider {
  final PreferencesProvider _preferencesProvider;
  final ScheduleProvider _scheduleProvider;
  final ScheduleSourceProvider _scheduleSourceProvider;

  RaplaImportantEventsProvider(
    this._preferencesProvider,
    this._scheduleProvider,
    this._scheduleSourceProvider,
  );

  Future<List<ImportantEvent>> getCachedImportantEvents(
    DateTime start,
    DateTime end,
  ) async {
    var schedule = await _scheduleProvider.getCachedSchedule(start, end);
    return _buildImportantEvents(schedule);
  }

  Future<ScheduleQueryResult?> refreshImportantEvents(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken,
  ) async {
    if (!await _ensureRaplaSource()) {
      return null;
    }

    try {
      var updatedSchedule = await _scheduleProvider.getUpdatedSchedule(
        start,
        end,
        cancellationToken,
      );
      return updatedSchedule;
    } on OperationCancelledException {
      return null;
    } on ScheduleQueryFailedException {
      return null;
    }
  }

  Future<bool> _ensureRaplaSource() async {
    var raplaUrl = await _preferencesProvider.getRaplaUrl();
    if (!RaplaScheduleSource.isValidUrl(raplaUrl)) {
      return false;
    }

    if (!_scheduleSourceProvider.didSetupCorrectly()) {
      await _scheduleSourceProvider.setupScheduleSource();
    }
    return _scheduleSourceProvider.didSetupCorrectly();
  }

  static List<ScheduleEntry> filterImportantEntries(Schedule schedule) {
    var filteredEntries = schedule.entries
        .where((entry) => _isImportantEntry(entry))
        .toList(growable: false);
    return _dedupeEntries(filteredEntries);
  }

  static bool _isImportantEntry(ScheduleEntry entry) {
    return entry.type == ScheduleEntryType.Exam ||
        entry.type == ScheduleEntryType.PublicHoliday ||
        entry.type == ScheduleEntryType.SpecialEvent;
  }

  static List<ScheduleEntry> _dedupeEntries(List<ScheduleEntry> entries) {
    var seenKeys = <String>{};
    var result = <ScheduleEntry>[];

    for (var entry in entries) {
      var key =
          '${entry.title}-${entry.type}-${entry.start.toIso8601String()}-${entry.end.toIso8601String()}-${entry.professor}';
      if (seenKeys.add(key)) {
        result.add(entry);
      }
    }

    return result;
  }

  static List<ImportantEvent> mergeImportantEntries(
      List<ScheduleEntry> entries) {
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
            professor: entry.professor,
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

  static bool _shouldMerge(
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

  List<ImportantEvent> _buildImportantEvents(Schedule schedule) {
    var importantEntries = filterImportantEntries(schedule);
    return mergeImportantEntries(importantEntries);
  }
}
