import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached week commit updates weekSchedule after pager settles', () async {
    final viewModel = WeeklyScheduleViewModel(
      _FakeScheduleProvider(<ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), 'CURRENT_WEEK'),
        _entry(DateTime(2026, 2, 16), 'NEXT_WEEK'),
      ]),
      _FakeScheduleSourceProvider(),
      nowProvider: () => DateTime(2026, 2, 10, 10),
    );

    await viewModel.updateSchedule(
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 16),
      force: true,
    );
    await viewModel.prefetchWeek(DateTime(2026, 2, 16), DateTime(2026, 2, 23));

    var visibleWeekNotifications = 0;
    var weekScheduleNotifications = 0;
    viewModel.addListener((_) => visibleWeekNotifications += 1, const [
      'visibleWeek',
    ]);
    viewModel.addListener((_) => weekScheduleNotifications += 1, const [
      'weekSchedule',
    ]);

    await viewModel.openWeekContaining(DateTime(2026, 2, 16));

    expect(viewModel.currentDateStart, DateTime(2026, 2, 16));
    expect(visibleWeekNotifications, 0);
    expect(weekScheduleNotifications, 1);

    viewModel.dispose();
  });
}

ScheduleEntry _entry(DateTime day, String title) {
  return ScheduleEntry(
    start: DateTime(day.year, day.month, day.day, 9),
    end: DateTime(day.year, day.month, day.day, 10),
    title: title,
    details: 'Lecture',
    professor: 'Prof',
    room: 'R1',
    type: ScheduleEntryType.Class,
  );
}

class _FakeScheduleProvider implements ScheduleProvider {
  final List<ScheduleEntry> _entries;

  _FakeScheduleProvider(this._entries);

  @override
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
    final entries = _entries.where((entry) {
      return start.isBefore(entry.end) && end.isAfter(entry.start);
    }).toList();
    return Schedule.fromList(entries);
  }

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    return ScheduleQueryResult(await getCachedSchedule(start, end), const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source = _FakeScheduleSource();

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  bool didSetupCorrectly() => true;

  @override
  void addDidChangeScheduleSourceCallback(OnDidChangeScheduleSource callback) {}

  @override
  void removeDidChangeScheduleSourceCallback(
    OnDidChangeScheduleSource callback,
  ) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleSourceProvider call: $invocation',
    );
  }
}

class _FakeScheduleSource implements ScheduleSource {
  @override
  bool canQuery() => true;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    return ScheduleQueryResult(Schedule(), const []);
  }
}
