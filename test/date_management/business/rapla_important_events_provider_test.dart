import 'package:dualmate/date_management/business/rapla_important_events_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:test/test.dart';

void main() {
  test('Filters only important entry types', () {
    var schedule = Schedule.fromList([
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 8),
        end: DateTime(2026, 7, 27, 9),
        title: 'Lecture',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.Class,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 9),
        end: DateTime(2026, 7, 27, 10),
        title: 'Exam',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 28, 8),
        end: DateTime(2026, 7, 28, 9),
        title: 'Holiday',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.PublicHoliday,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 29, 8),
        end: DateTime(2026, 7, 29, 9),
        title: 'Test Week',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
    ]);

    var filtered = RaplaImportantEventsProvider.filterImportantEntries(
      schedule,
    );

    expect(filtered.length, 3);
    expect(
      filtered.any((entry) => entry.type == ScheduleEntryType.Class),
      false,
    );
  });

  test('Merges consecutive same-title events', () {
    var entries = [
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 7),
        end: DateTime(2026, 7, 27, 8),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 28, 7),
        end: DateTime(2026, 7, 28, 8),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 29, 7),
        end: DateTime(2026, 7, 29, 8),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
    ];

    var merged = RaplaImportantEventsProvider.mergeImportantEntries(entries);

    expect(merged.length, 1);
    expect(merged.first.start, DateTime(2026, 7, 27, 7));
    expect(merged.first.end, DateTime(2026, 7, 29, 8));
  });

  test('Keeps separate events when there is a gap', () {
    var entries = [
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 7),
        end: DateTime(2026, 7, 27, 8),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 29, 7),
        end: DateTime(2026, 7, 29, 8),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
    ];

    var merged = RaplaImportantEventsProvider.mergeImportantEntries(entries);

    expect(merged.length, 2);
  });

  test('Does not merge exams across days', () {
    var entries = [
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 7),
        end: DateTime(2026, 7, 27, 8),
        title: 'Klausur',
        details: '',
        professor: 'Prof. Schmidt',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 28, 7),
        end: DateTime(2026, 7, 28, 8),
        title: 'Klausur',
        details: '',
        professor: 'Prof. Becker',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
    ];

    var merged = RaplaImportantEventsProvider.mergeImportantEntries(entries);

    expect(merged.length, 2);
  });

  test('Preserves professor names for exam entries', () {
    var entries = [
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 7),
        end: DateTime(2026, 7, 27, 8),
        title: 'Klausur',
        details: '',
        professor: 'Prof. Schmidt',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 28, 7),
        end: DateTime(2026, 7, 28, 8),
        title: 'Klausur',
        details: '',
        professor: 'Prof. Becker',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
    ];

    var merged = RaplaImportantEventsProvider.mergeImportantEntries(entries);

    expect(merged.length, 2);
    expect(merged[0].professor, 'Prof. Schmidt');
    expect(merged[1].professor, 'Prof. Becker');
  });

  test('Preserves both professors for same-slot exam collisions', () {
    var entries = [
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 7),
        end: DateTime(2026, 7, 27, 8),
        title: 'Klausur',
        details: '',
        professor: 'Prof. Schmidt',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 7),
        end: DateTime(2026, 7, 27, 8),
        title: 'Klausur',
        details: '',
        professor: 'Prof. Becker',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
    ];

    var merged = RaplaImportantEventsProvider.mergeImportantEntries(entries);

    expect(merged.length, 2);
    expect(merged[0].professor, 'Prof. Becker');
    expect(merged[1].professor, 'Prof. Schmidt');
  });

  test('Keeps same-slot important entries with different professors', () {
    var schedule = Schedule.fromList([
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 9),
        end: DateTime(2026, 7, 27, 10),
        title: 'Klausur',
        details: '',
        professor: 'Prof. Schmidt',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 9),
        end: DateTime(2026, 7, 27, 10),
        title: 'Klausur',
        details: '',
        professor: 'Prof. Becker',
        room: '',
        type: ScheduleEntryType.Exam,
      ),
    ]);

    var filtered = RaplaImportantEventsProvider.filterImportantEntries(
      schedule,
    );

    expect(filtered.length, 2);
    expect(filtered[0].professor, 'Prof. Schmidt');
    expect(filtered[1].professor, 'Prof. Becker');
  });

  test('Deduplicates identical entries', () {
    var schedule = Schedule.fromList([
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 9),
        end: DateTime(2026, 7, 27, 10),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
      ScheduleEntry(
        start: DateTime(2026, 7, 27, 9),
        end: DateTime(2026, 7, 27, 10),
        title: 'Klausurwoche',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.SpecialEvent,
      ),
    ]);

    var filtered = RaplaImportantEventsProvider.filterImportantEntries(
      schedule,
    );

    expect(filtered.length, 1);
  });
}
