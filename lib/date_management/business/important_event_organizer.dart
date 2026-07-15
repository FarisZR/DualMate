import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/date_management/business/important_event_ordering.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';

class ImportantEventOrganizer {
  static const String _examWeekKeyword = 'klausurwoche';

  List<ImportantEventSection> buildSections(List<ImportantEvent> events) {
    if (events.isEmpty) return const [];

    final sortedEvents = sortImportantEvents(events);
    final examWeekHeaders = _deduplicateExamWeekHeaders(sortedEvents);
    final examEventIdentities = <String>{};
    final sections = <ImportantEventSection>[];

    for (final header in examWeekHeaders) {
      final exams = sortedEvents
          .where(
            (event) =>
                event.type == ScheduleEntryType.Exam &&
                _eventWithinRange(event, header.start, header.end),
          )
          .toList(growable: false);
      for (final exam in exams) {
        examEventIdentities.add(importantEventStableIdentity(exam));
      }
      sections.add(
        ImportantEventSection(
          kind: ImportantEventSectionKind.examWeek,
          header: header,
          events: exams,
        ),
      );
    }

    for (final event in sortedEvents) {
      if (_isExamWeek(event)) continue;
      if (event.type == ScheduleEntryType.Exam &&
          examEventIdentities.contains(importantEventStableIdentity(event))) {
        continue;
      }
      sections.add(
        ImportantEventSection(
          kind: ImportantEventSectionKind.standalone,
          header: null,
          events: <ImportantEvent>[event],
        ),
      );
    }

    return _sortSections(sections);
  }

  bool _isExamWeek(ImportantEvent event) {
    return event.type == ScheduleEntryType.SpecialEvent &&
        normalizeImportantEventTitle(event.title).contains(_examWeekKeyword);
  }

  bool _eventWithinRange(ImportantEvent event, DateTime start, DateTime end) {
    final eventDay = toStartOfDay(event.start);
    return !eventDay.isBefore(toStartOfDay(start)) &&
        !eventDay.isAfter(toStartOfDay(end));
  }

  List<ImportantEvent> _deduplicateExamWeekHeaders(
    List<ImportantEvent> sortedEvents,
  ) {
    final byIdentity = <String, ImportantEvent>{};
    for (final event in sortedEvents) {
      if (!_isExamWeek(event)) continue;
      byIdentity.putIfAbsent(_examWeekIdentity(event), () => event);
    }
    return byIdentity.values.toList(growable: false);
  }

  String _examWeekIdentity(ImportantEvent event) {
    return '${normalizeImportantEventTitle(event.title)}|'
        '${_calendarDayIdentity(event.start)}|'
        '${_calendarDayIdentity(event.end)}';
  }

  String _calendarDayIdentity(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  List<ImportantEventSection> _sortSections(
    List<ImportantEventSection> sections,
  ) {
    final keyed = sections.map(_SectionSortKey.new).toList(growable: false)
      ..sort((first, second) {
        var comparison = first.anchorStart.compareTo(second.anchorStart);
        if (comparison != 0) return comparison;
        if (first.section.kind != second.section.kind) {
          return first.section.kind == ImportantEventSectionKind.examWeek
              ? -1
              : 1;
        }
        return first.anchorOrdering.compareTo(second.anchorOrdering);
      });
    return keyed.map((key) => key.section).toList(growable: false);
  }
}

class _SectionSortKey {
  final ImportantEventSection section;
  final DateTime anchorStart;
  final ImportantEventOrderingKey anchorOrdering;

  _SectionSortKey(this.section)
    : anchorStart = section.header?.start ?? section.events.single.start,
      anchorOrdering = ImportantEventOrderingKey(
        section.header ?? section.events.single,
      );
}
