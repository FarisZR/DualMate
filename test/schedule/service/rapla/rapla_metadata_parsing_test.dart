import 'dart:io';

import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/service/rapla/rapla_response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main() async {
  final v2NoTooltipResponse = await File(
    '${Directory.current.absolute.path}/test/schedule/service/rapla/'
    'html_resources/rapla_v2_metadata_response.html',
  ).readAsString();

  test('preserves v1 tooltip metadata and classification', () {
    final result = RaplaResponseParser().parseSchedule(_v1TooltipResponse);

    expect(result.errors, isEmpty);
    expect(result.schedule.entries, hasLength(1));

    final entry = result.schedule.entries.single;
    expect(entry.title, 'Legacy & Module');
    expect(entry.details, 'Bring <lab> notes & examples');
    expect(entry.professor, 'Dr. Ada & Lin');
    expect(entry.room, 'Room & Lab');
    expect(entry.type, ScheduleEntryType.Class);
  });

  test('extracts v2 no-tooltip metadata from sibling spans', () {
    final result = RaplaResponseParser().parseSchedule(v2NoTooltipResponse);

    expect(result.errors, isEmpty);
    expect(result.schedule.entries, hasLength(1));

    final entry = result.schedule.entries.single;
    expect(entry.start, DateTime(2026, 10, 5, 9));
    expect(entry.end, DateTime(2026, 10, 5, 10, 30));
    expect(entry.title, 'Modern & Module');
    expect(entry.details, isEmpty);
    expect(entry.professor, 'Dr. Ada & Lin, Prof. Bea');
    expect(entry.room, 'Room & Lab, Room 2');
    expect(entry.type, ScheduleEntryType.Class);
  });
}

const _v1TooltipResponse = '''
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
      <td class="week_block" style="background-color:#99ccff">
        <a href="#legacy">09:00&#160;-10:30<br/>Legacy &amp; Module<span class="tooltip">
          <strong>Vorlesung / Lehrbetrieb</strong>
          <table class="infotable">
            <tr><td class="label">Veranstaltungsname:</td><td class="value">Legacy &amp; Module</td></tr>
            <tr><td class="label">Bemerkung:</td><td class="value">Bring &lt;lab&gt; notes &amp; examples</td></tr>
            <tr><td class="label">Personen:</td><td class="value">Dr. Ada &amp; Lin,</td></tr>
            <tr><td class="label">Ressourcen:</td><td class="value">Room &amp; Lab</td></tr>
          </table>
        </span></a>
        <br><span class="person">Dr. Ada &amp; Lin,</span>
        <br><span class="resource">Room &amp; Lab</span>
      </td>
    </tr>
  </table>
</body>
</html>
''';
