import 'package:dualmate/date_management/business/important_event_organizer.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Groups exams under exam week', () {
    var organizer = ImportantEventOrganizer();
    var events = [
      ImportantEvent(
        title: 'Beginn der 1. Theoriephase',
        start: DateTime(2026, 7, 1, 8),
        end: DateTime(2026, 7, 1, 9),
        type: ScheduleEntryType.SpecialEvent,
      ),
      ImportantEvent(
        title: 'Klausurwoche',
        start: DateTime(2026, 9, 21, 8),
        end: DateTime(2026, 9, 25, 8),
        type: ScheduleEntryType.SpecialEvent,
      ),
      ImportantEvent(
        title: 'Exam 1',
        start: DateTime(2026, 9, 22, 8),
        end: DateTime(2026, 9, 22, 10),
        type: ScheduleEntryType.Exam,
      ),
      ImportantEvent(
        title: 'Exam 2',
        start: DateTime(2026, 9, 24, 8),
        end: DateTime(2026, 9, 24, 10),
        type: ScheduleEntryType.Exam,
      ),
      ImportantEvent(
        title: 'Exam 3',
        start: DateTime(2026, 9, 25, 9),
        end: DateTime(2026, 9, 25, 11),
        type: ScheduleEntryType.Exam,
      ),
      ImportantEvent(
        title: 'Exam outside',
        start: DateTime(2026, 10, 2, 8),
        end: DateTime(2026, 10, 2, 10),
        type: ScheduleEntryType.Exam,
      ),
    ];

    var sections = organizer.buildSections(events);

    var klausurSection = sections.firstWhere(
      (section) => section.header?.title == 'Klausurwoche',
    );
    expect(klausurSection.kind, ImportantEventSectionKind.examWeek);
    expect(klausurSection.events.length, 3);
    expect(klausurSection.events[0].title, 'Exam 1');
    expect(klausurSection.events[1].title, 'Exam 2');
    expect(klausurSection.events[2].title, 'Exam 3');
    expect(
      sections.any(
        (section) =>
            section.header == null &&
            section.events.first.title == 'Exam outside',
      ),
      true,
    );
  });

  test('Keeps events outside study phases', () {
    var organizer = ImportantEventOrganizer();
    var events = [
      ImportantEvent(
        title: 'Beginn der 1. Theoriephase',
        start: DateTime(2026, 7, 1, 8),
        end: DateTime(2026, 7, 1, 9),
        type: ScheduleEntryType.SpecialEvent,
      ),
      ImportantEvent(
        title: 'Klausurwoche',
        start: DateTime(2026, 9, 21, 8),
        end: DateTime(2026, 9, 25, 18),
        type: ScheduleEntryType.SpecialEvent,
      ),
      ImportantEvent(
        title: 'Holiday inside',
        start: DateTime(2026, 8, 3, 8),
        end: DateTime(2026, 8, 3, 18),
        type: ScheduleEntryType.PublicHoliday,
      ),
      ImportantEvent(
        title: 'Holiday outside',
        start: DateTime(2027, 2, 1, 8),
        end: DateTime(2027, 2, 1, 18),
        type: ScheduleEntryType.PublicHoliday,
      ),
    ];

    var sections = organizer.buildSections(events);

    var titles = sections
        .expand((section) => [section.header, ...section.events])
        .whereType<ImportantEvent>()
        .map((event) => event.title)
        .toList();

    expect(titles.contains('Holiday inside'), true);
    expect(titles.contains('Holiday outside'), true);
  });

  test('Keeps semester events without needing phase markers', () {
    var organizer = ImportantEventOrganizer();
    var events = [
      ImportantEvent(
        title: 'Beginn Theorie 2. Semester',
        start: DateTime(2026, 5, 4, 7),
        end: DateTime(2026, 5, 4, 7, 30),
        type: ScheduleEntryType.SpecialEvent,
      ),
      ImportantEvent(
        title: 'Klausurwoche 2. Semester',
        start: DateTime(2026, 7, 27, 7),
        end: DateTime(2026, 7, 31, 7, 30),
        type: ScheduleEntryType.SpecialEvent,
      ),
      ImportantEvent(
        title: 'Klausur Analysis',
        start: DateTime(2026, 7, 27, 9),
        end: DateTime(2026, 7, 27, 11),
        type: ScheduleEntryType.Exam,
      ),
      ImportantEvent(
        title: 'Holiday outside',
        start: DateTime(2027, 2, 1, 8),
        end: DateTime(2027, 2, 1, 18),
        type: ScheduleEntryType.PublicHoliday,
      ),
    ];

    var sections = organizer.buildSections(events);
    var titles = _sectionTitles(sections);

    expect(titles.contains('Beginn Theorie 2. Semester'), true);
    expect(titles.contains('Klausurwoche 2. Semester'), true);
    expect(titles.contains('Klausur Analysis'), true);
    expect(titles.contains('Holiday outside'), true);
  });

  test(
    'Keeps current phase exams and Rapla notice after later phase loads',
    () {
      var organizer = ImportantEventOrganizer();
      var events = [
        ImportantEvent(
          title: 'Wdh-Klausur theor. Inf. I - nur geladene Studenten TINF25',
          start: DateTime(2026, 6, 22, 9),
          end: DateTime(2026, 6, 22, 11, 30),
          type: ScheduleEntryType.Exam,
        ),
        ImportantEvent(
          title: 'Klausur Webengineering',
          start: DateTime(2026, 6, 29, 8, 30),
          end: DateTime(2026, 6, 29, 10, 30),
          type: ScheduleEntryType.Exam,
        ),
        ImportantEvent(
          title: 'Klausurwoche 2. Semester',
          start: DateTime(2026, 7, 27, 7),
          end: DateTime(2026, 7, 31, 7, 30),
          type: ScheduleEntryType.SpecialEvent,
        ),
        ImportantEvent(
          title: 'Klausur Analysis',
          start: DateTime(2026, 7, 27, 9),
          end: DateTime(2026, 7, 27, 11),
          type: ScheduleEntryType.Exam,
        ),
        ImportantEvent(
          title: 'Beginn Theoriephase 3+5. Semester',
          start: DateTime(2026, 9, 28, 8),
          end: DateTime(2026, 9, 28, 8, 30),
          type: ScheduleEntryType.SpecialEvent,
        ),
        ImportantEvent(
          title: 'Bitte nutzen Sie ab 1.10.2026  die neue Version von RaPla',
          start: DateTime(2026, 9, 28, 8),
          end: DateTime(2026, 9, 28, 17),
          type: ScheduleEntryType.Exam,
        ),
        ImportantEvent(
          title: 'Holiday outside',
          start: DateTime(2027, 2, 1, 8),
          end: DateTime(2027, 2, 1, 18),
          type: ScheduleEntryType.PublicHoliday,
        ),
      ];

      var sections = organizer.buildSections(events);
      var titles = _sectionTitles(sections);

      expect(
        titles.contains(
          'Wdh-Klausur theor. Inf. I - nur geladene Studenten TINF25',
        ),
        true,
      );
      expect(titles.contains('Klausur Webengineering'), true);
      expect(titles.contains('Klausurwoche 2. Semester'), true);
      expect(titles.contains('Klausur Analysis'), true);
      expect(titles.contains('Beginn Theoriephase 3+5. Semester'), true);
      expect(
        titles.contains(
          'Bitte nutzen Sie ab 1.10.2026  die neue Version von RaPla',
        ),
        true,
      );
      expect(titles.contains('Holiday outside'), true);
    },
  );

  test('keeps same-title exam weeks separate when calendar ranges differ', () {
    final organizer = ImportantEventOrganizer();
    final sections = organizer.buildSections([
      _event('Klausurwoche', DateTime(2026, 2, 2), DateTime(2026, 2, 6)),
      _event(
        'Exam A',
        DateTime(2026, 2, 3, 9),
        DateTime(2026, 2, 3, 11),
        type: ScheduleEntryType.Exam,
      ),
      _event('Klausurwoche', DateTime(2026, 5, 4), DateTime(2026, 5, 8)),
      _event(
        'Exam B',
        DateTime(2026, 5, 5, 9),
        DateTime(2026, 5, 5, 11),
        type: ScheduleEntryType.Exam,
      ),
    ]);

    final examWeeks = sections
        .where((section) => section.kind == ImportantEventSectionKind.examWeek)
        .toList();
    expect(examWeeks, hasLength(2));
    expect(examWeeks[0].events.single.title, 'Exam A');
    expect(examWeeks[1].events.single.title, 'Exam B');
    expect(examWeeks[0].header!.end, DateTime(2026, 2, 6));
    expect(examWeeks[1].header!.end, DateTime(2026, 5, 8));
  });

  test(
    'deduplicates duplicate exam-week markers for the exact calendar range',
    () {
      final organizer = ImportantEventOrganizer();
      final sections = organizer.buildSections([
        _event(
          'Klausur-Woche',
          DateTime(2026, 7, 27, 7),
          DateTime(2026, 7, 31, 8),
        ),
        _event(
          'Klausur Woche',
          DateTime(2026, 7, 27, 9),
          DateTime(2026, 7, 31, 18),
        ),
      ]);

      expect(sections, hasLength(1));
      expect(sections.single.kind, ImportantEventSectionKind.examWeek);
    },
  );

  test('keeps an exam-week section with no matching exams', () {
    final organizer = ImportantEventOrganizer();
    final sections = organizer.buildSections([
      _event('Klausurwoche', DateTime(2026, 7, 27), DateTime(2026, 7, 31)),
    ]);

    expect(sections, hasLength(1));
    expect(sections.single.kind, ImportantEventSectionKind.examWeek);
    expect(sections.single.header, isNotNull);
    expect(sections.single.events, isEmpty);
  });

  test(
    'orders equal-time events deterministically by full shared comparator',
    () {
      final organizer = ImportantEventOrganizer();
      final start = DateTime(2026, 8, 3, 9);
      final end = DateTime(2026, 8, 3, 10);
      final sections = organizer.buildSections([
        _event('beta', start, end, professor: 'Zed'),
        _event('Alpha', start, end, professor: 'Zed'),
        _event('alpha', start, end, professor: 'Ada'),
      ]);

      expect(
        sections
            .expand((section) => section.events)
            .map((event) => event.professor),
        ['Ada', 'Zed', 'Zed'],
      );
      expect(
        sections
            .expand((section) => section.events)
            .map((event) => event.title),
        ['alpha', 'Alpha', 'beta'],
      );
      expect(
        sections.every(
          (section) => section.kind == ImportantEventSectionKind.standalone,
        ),
        isTrue,
      );
    },
  );

  test('enforces standalone and exam-week section invariants', () {
    final event = _event('Event', DateTime(2026, 1, 1), DateTime(2026, 1, 1));

    expect(
      () => ImportantEventSection(
        kind: ImportantEventSectionKind.standalone,
        header: event,
        events: <ImportantEvent>[event],
      ),
      throwsAssertionError,
    );
    expect(
      () => ImportantEventSection(
        kind: ImportantEventSectionKind.standalone,
        header: null,
        events: const <ImportantEvent>[],
      ),
      throwsAssertionError,
    );
    expect(
      () => ImportantEventSection(
        kind: ImportantEventSectionKind.examWeek,
        header: null,
        events: const <ImportantEvent>[],
      ),
      throwsAssertionError,
    );
  });
}

ImportantEvent _event(
  String title,
  DateTime start,
  DateTime end, {
  String professor = '',
  ScheduleEntryType type = ScheduleEntryType.SpecialEvent,
}) {
  return ImportantEvent(
    title: title,
    start: start,
    end: end,
    professor: professor,
    type: type,
  );
}

List<String> _sectionTitles(List sections) {
  return sections
      .expand((section) => [section.header, ...section.events])
      .whereType<ImportantEvent>()
      .map((event) => event.title)
      .toList();
}
