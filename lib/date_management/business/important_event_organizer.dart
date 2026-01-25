import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/date_management/model/date_range.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';

class ImportantEventOrganizer {
  static const String _klausurwocheKeyword = 'klausurwoche';
  static const String _theoriephaseKeyword = 'theoriephase';
  static const String _beginnKeyword = 'beginn';

  List<ImportantEventSection> buildSections(
    List<ImportantEvent> events, {
    bool includeOutsideStudy = false,
  }) {
    if (events.isEmpty) return [];

    var studyPhases = buildStudyPhases(events);
    var filteredEvents = _filterByStudyPhases(
      events,
      studyPhases,
      includeOutsideStudy,
    );

    filteredEvents.sort((a, b) => a.start.compareTo(b.start));

    var examWeekGroups = _buildExamWeekGroups(filteredEvents);
    var sectionByKey = <String, ImportantEventSection>{};
    var examKeys = <String>{};

    for (var group in examWeekGroups) {
      var exams = filteredEvents
          .where((entry) =>
              entry.type == ScheduleEntryType.Exam &&
              _eventWithinRange(entry, group.start, group.end))
          .toList(growable: false)
        ..sort((a, b) => a.start.compareTo(b.start));

      for (var exam in exams) {
        examKeys.add(_eventKey(exam));
      }

      sectionByKey[_examWeekGroupKey(group)] = ImportantEventSection(
        header: group,
        events: exams,
      );
    }

    var sections = <ImportantEventSection>[];
    var addedExamWeeks = <String>{};

    for (var event in filteredEvents) {
      if (_isExamWeek(event)) {
        var key = _examWeekGroupKey(event);
        if (addedExamWeeks.add(key)) {
          var section = sectionByKey[key];
          if (section != null) {
            sections.add(section);
          }
        }
        continue;
      }

      if (event.type == ScheduleEntryType.Exam &&
          examKeys.contains(_eventKey(event))) {
        continue;
      }

      sections.add(ImportantEventSection(
        header: null,
        events: [event],
      ));
    }

    sections.sort((a, b) =>
        _sectionDate(a).compareTo(_sectionDate(b)));

    return sections;
  }

  List<DateRange> buildStudyPhases(List<ImportantEvent> events) {
    var theoryPhaseStarts = events.where(_isTheoryPhaseStart).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    var examWeeks = _buildExamWeekGroups(events)
      ..sort((a, b) => a.start.compareTo(b.start));

    if (theoryPhaseStarts.isEmpty) {
      return [];
    }

    var ranges = <DateRange>[];
    var examIndex = 0;

    for (var startEvent in theoryPhaseStarts) {
      while (examIndex < examWeeks.length &&
          examWeeks[examIndex].end.isBefore(startEvent.start)) {
        examIndex++;
      }

      DateTime end;
      if (examIndex < examWeeks.length &&
          !examWeeks[examIndex].start.isBefore(startEvent.start)) {
        end = examWeeks[examIndex].end;
      } else {
        end = _endOfDay(DateTime(
          startEvent.start.year,
          startEvent.start.month + 3,
          startEvent.start.day,
        ).subtract(const Duration(days: 1)));
      }

      var range = DateRange(
        start: toStartOfDay(startEvent.start),
        end: _endOfDay(end),
      );
      ranges.add(range);
    }

    return DateRange.merge(ranges);
  }

  List<ImportantEvent> _filterByStudyPhases(
    List<ImportantEvent> events,
    List<DateRange> studyPhases,
    bool includeOutsideStudy,
  ) {
    if (includeOutsideStudy || studyPhases.isEmpty) {
      return List<ImportantEvent>.from(events);
    }

    return events
        .where((event) =>
            studyPhases.any((range) =>
                range.overlaps(event.start, event.end)))
        .toList(growable: false);
  }

  bool _isExamWeek(ImportantEvent event) {
    if (event.type != ScheduleEntryType.SpecialEvent) return false;
    var normalized = _normalizeTitle(event.title);
    return normalized.contains(_klausurwocheKeyword);
  }

  bool _isTheoryPhaseStart(ImportantEvent event) {
    var normalized = _normalizeTitle(event.title);
    return normalized.contains(_beginnKeyword) &&
        normalized.contains(_theoriephaseKeyword);
  }

  bool _eventWithinRange(
    ImportantEvent event,
    DateTime start,
    DateTime end,
  ) {
    var eventDay = toStartOfDay(event.start);
    return !eventDay.isBefore(toStartOfDay(start)) &&
        !eventDay.isAfter(toStartOfDay(end));
  }

  List<ImportantEvent> _buildExamWeekGroups(List<ImportantEvent> events) {
    var examWeeks = events.where(_isExamWeek).toList();
    if (examWeeks.isEmpty) return [];

    var grouped = <String, List<ImportantEvent>>{};
    for (var event in examWeeks) {
      var key = _examWeekGroupKey(event);
      grouped.putIfAbsent(key, () => []).add(event);
    }

    var merged = <ImportantEvent>[];
    grouped.forEach((_, groupEvents) {
      groupEvents.sort((a, b) => a.start.compareTo(b.start));
      var start = groupEvents.first.start;
      var end = groupEvents.first.end;
      for (var entry in groupEvents.skip(1)) {
        if (entry.end.isAfter(end)) {
          end = entry.end;
        }
      }

      merged.add(ImportantEvent(
        title: groupEvents.first.title,
        start: start,
        end: end,
        type: groupEvents.first.type,
      ));
    });

    merged.sort((a, b) => a.start.compareTo(b.start));
    return merged;
  }

  DateTime _sectionDate(ImportantEventSection section) {
    return section.header?.start ?? section.events.first.start;
  }

  String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\.-]'), '');
  }

  String _eventKey(ImportantEvent event) {
    return '${event.title}-${event.type}-${event.start.toIso8601String()}-${event.end.toIso8601String()}';
  }

  String _examWeekGroupKey(ImportantEvent event) {
    var half = event.start.month <= 6 ? 'H1' : 'H2';
    return '${_normalizeTitle(event.title)}-${event.start.year}-$half';
  }

  DateTime _endOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59);
  }
}
