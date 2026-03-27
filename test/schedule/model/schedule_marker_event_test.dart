import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_marker_event.dart';
import 'package:test/test.dart';

void main() {
  test('recognizes klausurwoche special events as markers', () {
    final entry = _entry(
      title: 'Klausurwoche 2. Semester',
      type: ScheduleEntryType.SpecialEvent,
    );

    expect(ScheduleMarkerEvent.isMarkerEntry(entry), isTrue);
  });

  test('recognizes theoriephase start events as markers', () {
    final entry = _entry(
      title: 'Beginn der 1. Theoriephase',
      type: ScheduleEntryType.SpecialEvent,
    );

    expect(ScheduleMarkerEvent.isMarkerEntry(entry), isTrue);
  });

  test('does not treat exams as markers', () {
    final entry = _entry(
      title: 'Klausur Informatik 2',
      type: ScheduleEntryType.Exam,
    );

    expect(ScheduleMarkerEvent.isMarkerEntry(entry), isFalse);
  });
}

ScheduleEntry _entry({required String title, required ScheduleEntryType type}) {
  return ScheduleEntry(
    start: DateTime(2026, 4, 1, 8),
    end: DateTime(2026, 4, 1, 9),
    title: title,
    details: '',
    professor: '',
    room: '',
    type: type,
  );
}
