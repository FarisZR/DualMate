import 'dart:io';

import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/service/rapla/rapla_response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main() async {
  var importantEventsPage = await File(Directory.current.absolute.path +
          '/test/schedule/service/rapla/html_resources/rapla_important_events_week.html')
      .readAsString();

  test('Rapla parses important events by color', () async {
    var parser = RaplaResponseParser();

    var schedule = parser.parseSchedule(importantEventsPage).schedule;

    expect(schedule.entries.length, 3);

    var examEntry = schedule.entries.firstWhere(
      (entry) => entry.title == 'Klausur Informatik 2 (90 min)',
    );
    expect(examEntry.type, ScheduleEntryType.Exam);

    var specialEntry = schedule.entries.firstWhere(
      (entry) => entry.title == 'Klausurwoche 2. Semester',
    );
    expect(specialEntry.type, ScheduleEntryType.SpecialEvent);

    var holidayEntry = schedule.entries.firstWhere(
      (entry) => entry.title == 'Sommerferien',
    );
    expect(holidayEntry.type, ScheduleEntryType.PublicHoliday);
  });
}
