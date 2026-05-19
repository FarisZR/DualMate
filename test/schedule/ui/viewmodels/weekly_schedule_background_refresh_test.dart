import 'dart:async';

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
  test(
    'background range refresh keeps the currently visible week anchored',
    () async {
      final entries = <ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), 'Mon'),
        _entry(DateTime(2026, 2, 10), 'Tue'),
        _entry(DateTime(2026, 2, 16), 'Mon'),
        _entry(DateTime(2026, 2, 17), 'Tue'),
        _entry(DateTime(2026, 2, 23), 'Mon'),
      ];
      final provider = _FakeScheduleProvider(entries);
      final sourceProvider = _FakeScheduleSourceProvider();
      final viewModel = WeeklyScheduleViewModel(provider, sourceProvider);

      final visibleWeekStart = DateTime(2026, 2, 9);
      final visibleWeekEnd = DateTime(2026, 2, 16);

      await viewModel.updateSchedule(
        visibleWeekStart,
        visibleWeekEnd,
        force: true,
      );

      expect(provider.origins, [ScheduleRefreshOrigin.userBrowsing]);

      expect(viewModel.currentDateStart, visibleWeekStart);
      expect(viewModel.currentDateEnd, visibleWeekEnd);

      final widgetRefreshStart = DateTime(2026, 2, 10);
      final widgetRefreshEnd = DateTime(2026, 2, 24);

      await viewModel.updateSchedule(
        widgetRefreshStart,
        widgetRefreshEnd,
        force: true,
        applyToVisibleState: false,
      );

      expect(
        provider.origins.last,
        ScheduleRefreshOrigin.foregroundMaintenance,
      );

      expect(viewModel.currentDateStart, visibleWeekStart);
      expect(viewModel.currentDateEnd, visibleWeekEnd);
      expect(viewModel.currentDateStart.weekday, DateTime.monday);

      await viewModel.nextWeek();
      expect(viewModel.currentDateStart.weekday, DateTime.monday);
    },
  );

  test(
    'midweek background refresh keeps previous weekdays in visible schedule',
    () async {
      var nowValue = DateTime(2026, 2, 11, 11, 0); // Wednesday
      final entries = <ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), 'MONDAY_PREVIOUS'),
        _entry(DateTime(2026, 2, 10), 'TUESDAY_PREVIOUS'),
        _entry(DateTime(2026, 2, 11), 'WEDNESDAY_TODAY'),
      ];
      final provider = _FakeScheduleProvider(entries);
      final sourceProvider = _FakeScheduleSourceProvider();
      final viewModel = WeeklyScheduleViewModel(
        provider,
        sourceProvider,
        nowProvider: () => nowValue,
      );

      final visibleWeekStart = DateTime(2026, 2, 9);
      final visibleWeekEnd = DateTime(2026, 2, 16);
      await viewModel.updateSchedule(
        visibleWeekStart,
        visibleWeekEnd,
        force: true,
      );

      final titlesBefore =
          viewModel.weekSchedule!.entries.map((entry) => entry.title).toList();
      expect(titlesBefore, contains('Course_MONDAY_PREVIOUS'));
      expect(titlesBefore, contains('Course_TUESDAY_PREVIOUS'));

      await viewModel.refreshWidgetRangeInBackground();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(viewModel.currentDateStart, visibleWeekStart);
      expect(viewModel.currentDateEnd, visibleWeekEnd);
      expect(viewModel.currentDateStart.weekday, DateTime.monday);

      final titlesAfter =
          viewModel.weekSchedule!.entries.map((entry) => entry.title).toList();
      expect(titlesAfter, contains('Course_MONDAY_PREVIOUS'));
      expect(titlesAfter, contains('Course_TUESDAY_PREVIOUS'));
    },
  );

  test('visible range updates still replace the current week window', () async {
    final entries = <ScheduleEntry>[
      _entry(DateTime(2026, 2, 9), 'Mon'),
      _entry(DateTime(2026, 2, 10), 'Tue'),
      _entry(DateTime(2026, 2, 16), 'Mon'),
    ];
    final provider = _FakeScheduleProvider(entries);
    final sourceProvider = _FakeScheduleSourceProvider();
    final viewModel = WeeklyScheduleViewModel(provider, sourceProvider);

    final initialStart = DateTime(2026, 2, 9);
    final initialEnd = DateTime(2026, 2, 16);
    await viewModel.updateSchedule(initialStart, initialEnd, force: true);

    final updatedStart = DateTime(2026, 2, 10);
    final updatedEnd = DateTime(2026, 2, 24);
    await viewModel.updateSchedule(updatedStart, updatedEnd, force: true);

    expect(viewModel.currentDateStart, updatedStart);
    expect(viewModel.currentDateEnd, updatedEnd);
  });

  test('switching back to a recently fetched week does not refetch immediately',
      () async {
    var nowValue = DateTime(2026, 2, 9, 8, 0);
    final entries = <ScheduleEntry>[
      _entry(DateTime(2026, 2, 9), 'Mon_A'),
      _entry(DateTime(2026, 2, 16), 'Mon_B'),
    ];
    final provider = _CountingScheduleProvider(entries);
    final sourceProvider = _FakeScheduleSourceProvider();
    final viewModel = WeeklyScheduleViewModel(
      provider,
      sourceProvider,
      nowProvider: () => nowValue,
    );

    final weekAStart = DateTime(2026, 2, 9);
    final weekAEnd = DateTime(2026, 2, 16);
    final weekBStart = DateTime(2026, 2, 16);
    final weekBEnd = DateTime(2026, 2, 23);

    await viewModel.updateSchedule(weekAStart, weekAEnd, force: true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(provider.updatedScheduleRequests, 1);

    nowValue = nowValue.add(const Duration(seconds: 2));
    await viewModel.updateSchedule(weekBStart, weekBEnd, force: true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(provider.updatedScheduleRequests, 2);

    nowValue = nowValue.add(const Duration(seconds: 2));
    await viewModel.updateSchedule(weekAStart, weekAEnd);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(provider.updatedScheduleRequests, 2);
  });

  test('isUpdating stays true while visible background refresh is in flight',
      () async {
    final provider = _BlockingScheduleProvider();
    final sourceProvider = _FakeScheduleSourceProvider();
    final viewModel = WeeklyScheduleViewModel(provider, sourceProvider);

    final weekStart = DateTime(2026, 2, 9);
    final weekEnd = DateTime(2026, 2, 16);

    await viewModel.updateSchedule(weekStart, weekEnd, force: true);
    expect(viewModel.isUpdating, isTrue);

    provider.complete(
      ScheduleQueryResult(Schedule(), const []),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(viewModel.isUpdating, isFalse);
  });
}

ScheduleEntry _entry(DateTime start, String suffix) {
  return ScheduleEntry(
    start: DateTime(start.year, start.month, start.day, 9),
    end: DateTime(start.year, start.month, start.day, 10),
    title: 'Course_$suffix',
    details: 'Lecture',
    professor: 'Prof',
    room: 'R1',
    type: ScheduleEntryType.Class,
  );
}

class _FakeScheduleProvider implements ScheduleProvider {
  final List<ScheduleEntry> _entries;
  final List<ScheduleRefreshOrigin> origins = <ScheduleRefreshOrigin>[];

  _FakeScheduleProvider(this._entries);

  @override
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
    return _trim(start, end);
  }

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    origins.add(origin);
    return ScheduleQueryResult(_trim(start, end), const []);
  }

  Schedule _trim(DateTime start, DateTime end) {
    final entries = _entries.where((entry) {
      return start.isBefore(entry.end) && end.isAfter(entry.start);
    }).toList();
    return Schedule.fromList(entries);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _CountingScheduleProvider extends _FakeScheduleProvider {
  int updatedScheduleRequests = 0;

  _CountingScheduleProvider(super.entries);

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    updatedScheduleRequests += 1;
    return super.getUpdatedSchedule(
      start,
      end,
      cancellationToken,
      origin: origin,
    );
  }
}

class _BlockingScheduleProvider extends _FakeScheduleProvider {
  final Completer<ScheduleQueryResult> _updatedScheduleCompleter =
      Completer<ScheduleQueryResult>();

  _BlockingScheduleProvider() : super(const <ScheduleEntry>[]);

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) {
    origins.add(origin);
    return _updatedScheduleCompleter.future;
  }

  void complete(ScheduleQueryResult result) {
    if (_updatedScheduleCompleter.isCompleted) {
      return;
    }
    _updatedScheduleCompleter.complete(result);
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
