import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:test/test.dart';

void main() {
  test('defaults to Monday through Friday when schedule is empty', () {
    final reference = DateTime(2026, 2, 4);
    final range = WeeklyScheduleViewModel.resolveWeeklyDisplayRange(
      reference,
      null,
    );

    expect(range.start, DateTime(2026, 2, 2));
    expect(range.end, DateTime(2026, 2, 6));
  });

  test('keeps Monday through Friday when no Saturday entries exist', () {
    final reference = DateTime(2026, 2, 4);
    final schedule = Schedule.fromList([
      ScheduleEntry(
        start: DateTime(2026, 2, 2, 9),
        end: DateTime(2026, 2, 2, 10),
        title: 'Math',
        details: 'Lecture',
        professor: 'Prof',
        room: 'Room 1',
        type: ScheduleEntryType.Class,
      ),
      ScheduleEntry(
        start: DateTime(2026, 2, 5, 13),
        end: DateTime(2026, 2, 5, 14),
        title: 'Networks',
        details: 'Lab',
        professor: 'Prof',
        room: 'Room 2',
        type: ScheduleEntryType.Class,
      ),
    ]);

    final range = WeeklyScheduleViewModel.resolveWeeklyDisplayRange(
      reference,
      schedule,
    );

    expect(range.start, DateTime(2026, 2, 2));
    expect(range.end, DateTime(2026, 2, 6));
  });

  test('extends to Saturday when Saturday entries exist', () {
    final reference = DateTime(2026, 2, 4);
    final schedule = Schedule.fromList([
      ScheduleEntry(
        start: DateTime(2026, 2, 7, 9),
        end: DateTime(2026, 2, 7, 10),
        title: 'Saturday Seminar',
        details: 'Seminar',
        professor: 'Prof',
        room: 'Room 3',
        type: ScheduleEntryType.SpecialEvent,
      ),
    ]);

    final range = WeeklyScheduleViewModel.resolveWeeklyDisplayRange(
      reference,
      schedule,
    );

    expect(range.start, DateTime(2026, 2, 2));
    expect(range.end, DateTime(2026, 2, 7));
  });
}
