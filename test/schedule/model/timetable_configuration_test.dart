import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary defaults include future modules; additions opt in', () {
    final primary = configuration('b4', includeAll: true, exceptions: {'Math'});
    final additional = configuration('b6', exceptions: {'Math'});
    expect(primary.includes('Math'), isFalse);
    expect(primary.includes('New module'), isTrue);
    expect(additional.includes('Math'), isTrue);
    expect(additional.includes('New module'), isFalse);
    expect(primary.withModule('Math', true).includes('Math'), isTrue);
    expect(primary.includes('Math'), isFalse);
  });
}

TimetableConfiguration configuration(
  String id, {
  bool includeAll = false,
  Set<String> exceptions = const {},
}) => TimetableConfiguration(
  id: id,
  label: id,
  type: ScheduleSourceType.Ical,
  value: 'https://example.com/$id.ics',
  includeAll: includeAll,
  exceptions: exceptions,
);
