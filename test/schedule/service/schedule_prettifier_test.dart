import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/service/schedule_prettifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('course-code separator is moved to details exactly once', () {
    final result = SchedulePrettifier().prettifyScheduleEntry(
      _entry(title: 'ABC12 - Seminar', details: 'Bring notes'),
    );

    expect(result.title, 'Seminar');
    expect(result.details, 'ABC12 - Bring notes');
  });

  test('trimming alone does not mark a class as online', () {
    final result = SchedulePrettifier().prettifyScheduleEntry(
      _entry(title: ' Seminar '),
    );

    expect(result.title, ' Seminar ');
    expect(result.type, ScheduleEntryType.Class);
  });
}

ScheduleEntry _entry({required String title, String details = ''}) =>
    ScheduleEntry(
      start: DateTime(2026, 7, 20, 9),
      end: DateTime(2026, 7, 20, 11),
      title: title,
      details: details,
      professor: '',
      room: '',
      type: ScheduleEntryType.Class,
    );
