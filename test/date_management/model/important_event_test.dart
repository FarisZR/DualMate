import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter_test/flutter_test.dart';

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
      professor: 'Prof. Schmidt',
      type: ScheduleEntryType.PublicHoliday,
    );
    var event2 = ImportantEvent(
      title: 'Hl. 3 Koenige',
      start: DateTime(2026, 1, 6),
      end: DateTime(2026, 1, 6),
      professor: 'Prof. Schmidt',
      type: ScheduleEntryType.PublicHoliday,
    );

    expect(event1, event2);
  });

  test('ImportantEvent hashCode preserves field order', () {
    final first = ImportantEvent(
      title: 'Title A',
      start: DateTime(2026, 1, 6),
      end: DateTime(2026, 1, 6),
      professor: 'Professor B',
      type: ScheduleEntryType.PublicHoliday,
    );
    final swapped = ImportantEvent(
      title: 'Professor B',
      start: DateTime(2026, 1, 6),
      end: DateTime(2026, 1, 6),
      professor: 'Title A',
      type: ScheduleEntryType.PublicHoliday,
    );

    expect(first, isNot(swapped));
    expect(first.hashCode, isNot(swapped.hashCode));
  });

  test('ImportantEvent serializes all schedule detail fields', () {
    var event = ImportantEvent(
      title: 'Klausur',
      start: DateTime(2026, 7, 31, 8),
      end: DateTime(2026, 7, 31, 10),
      professor: 'Prof. Mueller, Prof. Fischer',
      details: 'Bring a calculator',
      room: 'A 101',
      type: ScheduleEntryType.Exam,
    );

    var restored = ImportantEvent.fromJson(event.toJson());

    expect(restored, event);
    expect(restored.professor, 'Prof. Mueller, Prof. Fischer');
    expect(restored.details, 'Bring a calculator');
    expect(restored.room, 'A 101');
  });
}
