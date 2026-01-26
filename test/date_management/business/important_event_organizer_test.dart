import 'package:dualmate/date_management/business/important_event_organizer.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:test/test.dart';

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

    var sections = organizer.buildSections(events, includeOutsideStudy: true);

    var klausurSection = sections
        .firstWhere((section) => section.header?.title == 'Klausurwoche');
    expect(klausurSection.events.length, 3);
    expect(klausurSection.events[0].title, 'Exam 1');
    expect(klausurSection.events[1].title, 'Exam 2');
    expect(klausurSection.events[2].title, 'Exam 3');
    expect(
      sections.any((section) =>
          section.header == null && section.events.first.title == 'Exam outside'),
      true,
    );
  });

  test('Hides events outside study phases by default', () {
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
        start: DateTime(2026, 12, 25, 8),
        end: DateTime(2026, 12, 25, 18),
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
    expect(titles.contains('Holiday outside'), false);
  });
}
