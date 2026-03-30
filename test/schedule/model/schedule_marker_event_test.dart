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

  test('does not treat theoriephase without beginn as marker', () {
    final entry = _entry(
      title: 'Theoriephase 2. Semester',
      type: ScheduleEntryType.SpecialEvent,
    );

    expect(ScheduleMarkerEvent.isMarkerEntry(entry), isFalse);
  });

  test('does not treat exams as markers', () {
    final entry = _entry(
      title: 'Klausur Informatik 2',
      type: ScheduleEntryType.Exam,
    );

    expect(ScheduleMarkerEvent.isMarkerEntry(entry), isFalse);
  });

  test('does not treat unrelated special events as markers', () {
    final entry = _entry(
      title: 'Career Fair',
      type: ScheduleEntryType.SpecialEvent,
    );

    expect(ScheduleMarkerEvent.isMarkerEntry(entry), isFalse);
  });

  test('recognizes klausurwoche exams as markers', () {
    final entry = _entry(
      title: 'Klausurwoche 2. Semester',
      type: ScheduleEntryType.Exam,
    );

    expect(ScheduleMarkerEvent.isMarkerEntry(entry), isTrue);
  });

  test('treats public holidays as markers', () {
    final entry = _entry(
      title: 'Karfreitag',
      type: ScheduleEntryType.PublicHoliday,
    );

    expect(ScheduleMarkerEvent.isMarkerEntry(entry), isTrue);
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
