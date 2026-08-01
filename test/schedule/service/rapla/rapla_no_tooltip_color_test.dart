import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/service/rapla/rapla_response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = <String, ScheduleEntryType>{
    '#eeeeee': ScheduleEntryType.Class,
    '#ff6666': ScheduleEntryType.Exam,
    '#ffff61': ScheduleEntryType.PublicHoliday,
    '#c0e2ff': ScheduleEntryType.SpecialEvent,
    '#123456': ScheduleEntryType.Unknown,
  };

  for (final entry in cases.entries) {
    test('maps a no-tooltip Rapla entry with ${entry.key}', () {
      final result = RaplaResponseParser().parseSchedule(
        _weekResponseWithNoTooltipColor(entry.key),
      );

      expect(result.errors, isEmpty);
      expect(result.schedule.entries, hasLength(1));
      expect(result.schedule.entries.single.type, entry.value);
    });
  }
}

String _weekResponseWithNoTooltipColor(String color) =>
    '''
<!DOCTYPE html>
<html>
<body>
  <select name="year">
    <option selected="selected">2026</option>
  </select>
  <table class="week_table">
    <tr>
      <th class="week_number">KW 1</th>
      <td class="week_header"><nobr>Mo 05.01.</nobr></td>
    </tr>
    <tr>
      <td class="week_block" style="background-color:$color">
        <a href="#synthetic">09:00 -10:00<br/>Synthetic event</a>
      </td>
    </tr>
  </table>
</body>
</html>
''';
