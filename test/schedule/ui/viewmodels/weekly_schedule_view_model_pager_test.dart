import 'dart:async';

import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:fake_async/fake_async.dart';
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
    addTearDown(viewModel.dispose);

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
  });

  test(
    'openWeekContaining skips state mutation when isCurrentRequest reports stale',
    () async {
      final viewModel = WeeklyScheduleViewModel(
        _FakeScheduleProvider(<ScheduleEntry>[
          _entry(DateTime(2026, 2, 9), 'WEEK_A'),
          _entry(DateTime(2026, 2, 16), 'WEEK_B'),
        ]),
        _FakeScheduleSourceProvider(),
        nowProvider: () => DateTime(2026, 2, 10, 10),
      );
      addTearDown(viewModel.dispose);

      await viewModel.openWeekContaining(DateTime(2026, 2, 16));
      expect(viewModel.currentDateStart, DateTime(2026, 2, 16));
      expect(viewModel.weekSchedule?.entries.single.title, 'WEEK_B');

      // A stale request for week A must not overwrite the newer week B state.
      await viewModel.openWeekContaining(
        DateTime(2026, 2, 9),
        isCurrentRequest: () => false,
      );

      expect(viewModel.currentDateStart, DateTime(2026, 2, 16));
      expect(viewModel.weekSchedule?.entries.single.title, 'WEEK_B');
    },
  );

  test(
    'stale openWeekContaining does not schedule a delayed refresh overwriting the newer week',
    () {
      fakeAsync((async) {
        final viewModel = WeeklyScheduleViewModel(
          _FakeScheduleProvider(<ScheduleEntry>[
            _entry(DateTime(2026, 2, 9), 'WEEK_A'),
            _entry(DateTime(2026, 2, 16), 'WEEK_B'),
          ]),
          _FakeScheduleSourceProvider(),
          nowProvider: () => DateTime(2026, 2, 10, 10),
        );

        // Open week B; it becomes the current (newer) week and schedules its own
        // debounced visible refresh.
        unawaited(viewModel.openWeekContaining(DateTime(2026, 2, 16)));
        async.flushMicrotasks();
        expect(viewModel.currentDateStart, DateTime(2026, 2, 16));

        // A stale request for week A must neither commit nor schedule a delayed
        // refresh that overwrites week B (which would also cancel B's refresh).
        unawaited(
          viewModel.openWeekContaining(
            DateTime(2026, 2, 9),
            isCurrentRequest: () => false,
          ),
        );
        async.flushMicrotasks();
        expect(viewModel.currentDateStart, DateTime(2026, 2, 16));

        // Elapsing past the visible-refresh debounce window must not let the
        // stale week A overwrite the newer week B.
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(viewModel.currentDateStart, DateTime(2026, 2, 16));
        viewModel.dispose();
      });
    },
  );

  test(
    'opening a never-fetched empty week schedules forced refresh before visible debounce',
    () {
      fakeAsync((async) {
        final provider = _FakeScheduleProvider(const <ScheduleEntry>[]);
        final viewModel = WeeklyScheduleViewModel(
          provider,
          _FakeScheduleSourceProvider(),
          nowProvider: () => DateTime(2026, 2, 10, 10),
        );

        unawaited(viewModel.openWeekContaining(DateTime(2026, 2, 16)));
        async.flushMicrotasks();

        expect(viewModel.currentDateStart, DateTime(2026, 2, 16));
        expect(viewModel.visibleWeekNeedsInitialFetch, isTrue);
        expect(provider.updatedScheduleRequests, 0);

        async.elapse(const Duration(milliseconds: 120));
        async.flushMicrotasks();

        expect(provider.updatedScheduleRequests, 1);
        viewModel.dispose();
      });
    },
  );

  test('stale open-week requests do not schedule initial refreshes', () {
    fakeAsync((async) {
      final provider = _FakeScheduleProvider(const <ScheduleEntry>[]);
      final viewModel = WeeklyScheduleViewModel(
        provider,
        _FakeScheduleSourceProvider(),
        nowProvider: () => DateTime(2026, 2, 10, 10),
      );

      unawaited(
        viewModel.openWeekContaining(
          DateTime(2026, 2, 16),
          isCurrentRequest: () => false,
        ),
      );
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 120));
      async.flushMicrotasks();

      expect(provider.updatedScheduleRequests, 0);
      viewModel.dispose();
    });
  });

  test('persisted query information treats an empty week as known empty', () {
    fakeAsync((async) {
      final provider = _FakeScheduleProvider(const <ScheduleEntry>[]);
      provider.markWindowQueried(
        DateTime(2026, 2, 16),
        DateTime(2026, 2, 23),
        DateTime(2026, 2, 16, 8, 45),
      );
      final viewModel = WeeklyScheduleViewModel(
        provider,
        _FakeScheduleSourceProvider(),
        nowProvider: () => DateTime(2026, 2, 16, 9),
      );

      unawaited(viewModel.openWeekContaining(DateTime(2026, 2, 16)));
      async.flushMicrotasks();

      expect(viewModel.visibleWeekNeedsInitialFetch, isFalse);

      async.elapse(const Duration(milliseconds: 120));
      async.flushMicrotasks();
      expect(provider.updatedScheduleRequests, 0);

      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      expect(provider.updatedScheduleRequests, 0);
      viewModel.dispose();
    });
  });

  test(
    'switching back to a recently fetched empty week does not refetch immediately',
    () {
      fakeAsync((async) {
        final provider = _FakeScheduleProvider(const <ScheduleEntry>[]);
        final viewModel = WeeklyScheduleViewModel(
          provider,
          _FakeScheduleSourceProvider(),
          nowProvider: () => DateTime(2026, 2, 10, 10),
        );

        unawaited(viewModel.openWeekContaining(DateTime(2026, 2, 9)));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 120));
        async.flushMicrotasks();
        expect(provider.updatedScheduleRequests, 1);

        unawaited(viewModel.openWeekContaining(DateTime(2026, 2, 16)));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 120));
        async.flushMicrotasks();
        expect(provider.updatedScheduleRequests, 2);

        unawaited(viewModel.openWeekContaining(DateTime(2026, 2, 9)));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 120));
        async.flushMicrotasks();
        expect(provider.updatedScheduleRequests, 2);

        viewModel.dispose();
      });
    },
  );

  test(
    'failed initial refresh keeps empty week eligible for another initial fetch',
    () {
      fakeAsync((async) {
        final provider = _FailingFirstUpdateScheduleProvider();
        final viewModel = WeeklyScheduleViewModel(
          provider,
          _FakeScheduleSourceProvider(),
          nowProvider: () => DateTime(2026, 2, 10, 10),
        );

        unawaited(viewModel.openWeekContaining(DateTime(2026, 2, 16)));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 120));
        async.flushMicrotasks();

        expect(provider.updatedScheduleRequests, 1);
        expect(viewModel.visibleWeekNeedsInitialFetch, isTrue);

        unawaited(viewModel.openWeekContaining(DateTime(2026, 2, 16)));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 120));
        async.flushMicrotasks();

        expect(provider.updatedScheduleRequests, 2);
        expect(viewModel.visibleWeekNeedsInitialFetch, isFalse);
        viewModel.dispose();
      });
    },
  );

  test(
    'stale metadata checks do not cancel newer visible initial refresh timers',
    () {
      fakeAsync((async) {
        final provider = _MetadataBlockingScheduleProvider();
        var requestId = 1;
        final viewModel = WeeklyScheduleViewModel(
          provider,
          _FakeScheduleSourceProvider(),
          nowProvider: () => DateTime(2026, 2, 10, 10),
        );

        unawaited(
          viewModel.openWeekContaining(
            DateTime(2026, 2, 16),
            isCurrentRequest: () => requestId == 1,
          ),
        );
        async.flushMicrotasks();

        requestId = 2;
        unawaited(
          viewModel.openWeekContaining(
            DateTime(2026, 2, 23),
            isCurrentRequest: () => requestId == 2,
          ),
        );
        async.flushMicrotasks();

        provider.completeQueryInformation(
          DateTime(2026, 2, 23),
          DateTime(2026, 3, 2),
        );
        async.flushMicrotasks();

        provider.completeQueryInformation(
          DateTime(2026, 2, 16),
          DateTime(2026, 2, 23),
        );
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 120));
        async.flushMicrotasks();

        expect(viewModel.currentDateStart, DateTime(2026, 2, 23));
        expect(provider.updatedScheduleRequests, 1);
        viewModel.dispose();
      });
    },
  );
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
  final Map<String, DateTime> _queryTimesByWindow = <String, DateTime>{};
  int updatedScheduleRequests = 0;

  _FakeScheduleProvider(this._entries);

  void markWindowQueried(DateTime start, DateTime end, DateTime queryTime) {
    _queryTimesByWindow[_windowKey(start, end)] = queryTime;
  }

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
    updatedScheduleRequests += 1;
    markWindowQueried(start, end, DateTime.now());
    return ScheduleQueryResult(await getCachedSchedule(start, end), const []);
  }

  @override
  Future<DateTime?> getLastQueryTimeForWindow(
    DateTime start,
    DateTime end,
  ) async {
    return _queryTimesByWindow[_windowKey(start, end)];
  }

  String _windowKey(DateTime start, DateTime end) {
    return '${start.toIso8601String()}_${end.toIso8601String()}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _FailingFirstUpdateScheduleProvider extends _FakeScheduleProvider {
  var _shouldFail = true;

  _FailingFirstUpdateScheduleProvider() : super(const <ScheduleEntry>[]);

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    updatedScheduleRequests += 1;
    if (_shouldFail) {
      _shouldFail = false;
      throw ScheduleQueryFailedException(Exception('schedule unavailable'));
    }
    markWindowQueried(start, end, DateTime.now());
    return ScheduleQueryResult(await getCachedSchedule(start, end), const []);
  }
}

class _MetadataBlockingScheduleProvider extends _FakeScheduleProvider {
  final Map<String, Completer<DateTime?>> _metadataCompleters =
      <String, Completer<DateTime?>>{};

  _MetadataBlockingScheduleProvider() : super(const <ScheduleEntry>[]);

  @override
  Future<DateTime?> getLastQueryTimeForWindow(DateTime start, DateTime end) {
    return (_metadataCompleters[_windowKey(start, end)] ??=
            Completer<DateTime?>())
        .future;
  }

  void completeQueryInformation(DateTime start, DateTime end) {
    final completer = _metadataCompleters[_windowKey(start, end)];
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(null);
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
