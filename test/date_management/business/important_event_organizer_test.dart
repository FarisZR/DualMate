import 'package:dualmate/date_management/business/important_event_organizer.dart';
import 'package:dualmate/date_management/model/important_event.dart';
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
}

List<String> _sectionTitles(List sections) {
  return sections
      .expand((section) => [section.header, ...section.events])
      .whereType<ImportantEvent>()
      .map((event) => event.title)
      .toList();
}
