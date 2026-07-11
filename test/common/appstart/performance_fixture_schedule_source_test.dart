import 'package:dualmate/common/appstart/performance_fixture_schedule_source.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fixture schedule source returns deterministic populated local content',
    () async {
      final source = PerformanceFixtureScheduleSource();

      final result = await source.querySchedule(
        DateTime(2026, 7, 20),
        DateTime(2026, 7, 27),
        CancellationToken(),
      );

      expect(source.canQuery(), isTrue);
      expect(
        result.schedule.entries.map((entry) => entry.title),
        contains(PerformanceFixtureScheduleSource.refreshedEntryTitle),
      );
    },
  );
}
