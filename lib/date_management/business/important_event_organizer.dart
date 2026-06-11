import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';

class ImportantEventOrganizer {
  static const String _klausurwocheKeyword = 'klausurwoche';

  List<ImportantEventSection> buildSections(List<ImportantEvent> events) {
    if (events.isEmpty) return [];

    var sortedEvents = List<ImportantEvent>.from(events)
      ..sort((a, b) => a.start.compareTo(b.start));

    var examWeekGroups = _buildExamWeekGroups(sortedEvents);
    var sectionByKey = <String, ImportantEventSection>{};
    var examKeys = <String>{};

    for (var group in examWeekGroups) {
      var exams =
          sortedEvents
              .where(
                (entry) =>
                    entry.type == ScheduleEntryType.Exam &&
                    _eventWithinRange(entry, group.start, group.end),
              )
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

    for (var event in sortedEvents) {
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

      sections.add(ImportantEventSection(header: null, events: [event]));
    }

    sections.sort((a, b) => _sectionDate(a).compareTo(_sectionDate(b)));

    return sections;
  }

  bool _isExamWeek(ImportantEvent event) {
    if (event.type != ScheduleEntryType.SpecialEvent) return false;
    var normalized = _normalizeTitle(event.title);
    return normalized.contains(_klausurwocheKeyword);
  }

  bool _eventWithinRange(ImportantEvent event, DateTime start, DateTime end) {
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

      merged.add(
        ImportantEvent(
          title: groupEvents.first.title,
          start: start,
          end: end,
          type: groupEvents.first.type,
        ),
      );
    });

    merged.sort((a, b) => a.start.compareTo(b.start));
    return merged;
  }

  DateTime _sectionDate(ImportantEventSection section) {
    return section.header?.start ?? section.events.first.start;
  }

  String _normalizeTitle(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[\s\.-]'), '');
  }

  String _eventKey(ImportantEvent event) {
    return '${event.title}-${event.type}-${event.start.toIso8601String()}-${event.end.toIso8601String()}';
  }

  String _examWeekGroupKey(ImportantEvent event) {
    var half = event.start.month <= 6 ? 'H1' : 'H2';
    return '${_normalizeTitle(event.title)}-${event.start.year}-$half';
  }
}
