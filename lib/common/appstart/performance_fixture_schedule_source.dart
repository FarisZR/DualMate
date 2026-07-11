import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

/// Local Schedule source used exclusively after the opt-in profile fixture has
/// validated the user's configured source. It lets the harness exercise the
/// normal refresh-required week path without using the network.
class PerformanceFixtureScheduleSource extends ScheduleSource {
  static const String refreshedEntryTitle = 'Fixture refreshed schedule entry';

  @override
  bool canQuery() => true;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    final token = cancellationToken ?? CancellationToken();
    token.throwIfCancelled();
    final weekStart = toStartOfDay(toDayOfWeek(from, DateTime.monday));
    final entries = <ScheduleEntry>[
      ScheduleEntry(
        start: weekStart.add(const Duration(days: 1, hours: 8)),
        end: weekStart.add(const Duration(days: 1, hours: 10)),
        title: refreshedEntryTitle,
        details:
            'Deterministic local refresh fixture for performance profiling',
        professor: 'Prof. Fixture',
        room: 'H 301',
        type: ScheduleEntryType.Class,
      ),
      ScheduleEntry(
        start: weekStart.add(const Duration(days: 3, hours: 13)),
        end: weekStart.add(const Duration(days: 3, hours: 15)),
        title: 'Fixture refreshed seminar',
        details: 'Locally generated populated Schedule content',
        professor: 'Prof. Fixture',
        room: 'H 302',
        type: ScheduleEntryType.Class,
      ),
    ];
    token.throwIfCancelled();
    return ScheduleQueryResult(Schedule.fromList(entries), const []);
  }
}
