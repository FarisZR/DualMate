import 'package:dhbwstudentapp/date_management/model/important_event.dart';
import 'package:dhbwstudentapp/schedule/model/schedule_entry.dart';
import 'package:test/test.dart';

void main() {
  test('ImportantEvent identifies single day events', () {
    var event = ImportantEvent(
      title: 'Klausur Informatik',
      start: DateTime(2026, 7, 31),
      end: DateTime(2026, 7, 31),
      type: ScheduleEntryType.Exam,
    );

    expect(event.isSingleDay, true);
    expect(event.durationDays, 1);
  });

  test('ImportantEvent supports multi day ranges', () {
    var event = ImportantEvent(
      title: 'Klausurwoche',
      start: DateTime(2026, 7, 27),
      end: DateTime(2026, 7, 31),
      type: ScheduleEntryType.SpecialEvent,
    );

    expect(event.isSingleDay, false);
    expect(event.durationDays, 5);
  });

  test('ImportantEvent equality uses content', () {
    var event1 = ImportantEvent(
      title: 'Hl. 3 Koenige',
      start: DateTime(2026, 1, 6),
      end: DateTime(2026, 1, 6),
      type: ScheduleEntryType.PublicHoliday,
    );
    var event2 = ImportantEvent(
      title: 'Hl. 3 Koenige',
      start: DateTime(2026, 1, 6),
      end: DateTime(2026, 1, 6),
      type: ScheduleEntryType.PublicHoliday,
    );

    expect(event1, event2);
  });
}
