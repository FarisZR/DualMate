import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/background/calendar_synchronizer.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delayed calendar sync is skipped when local calendar is disabled', () {
    fakeAsync((async) {
      final scheduleProvider = _TrackingScheduleProvider();
      final scheduleSourceProvider = _FakeScheduleSourceProvider();
      final synchronizer = CalendarSynchronizer(
        scheduleProvider,
        scheduleSourceProvider,
        _FakePreferencesProvider(),
      );

      synchronizer.scheduleSyncInAFewSeconds();
      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();

      expect(scheduleProvider.origins, isEmpty);
    });
  });

  test(
    'enabled delayed calendar sync uses a silent foreground maintenance origin',
    () {
      fakeAsync((async) {
        final scheduleProvider = _TrackingScheduleProvider();
        final scheduleSourceProvider = _FakeScheduleSourceProvider();
        final synchronizer = CalendarSynchronizer(
          scheduleProvider,
          scheduleSourceProvider,
          _FakePreferencesProvider(),
          localCalendarEnabled: true,
        );

        synchronizer.scheduleSyncInAFewSeconds();
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(scheduleProvider.origins, [
          ScheduleRefreshOrigin.foregroundMaintenance,
        ]);
      });
    },
  );
}

class _TrackingScheduleProvider implements ScheduleProvider {
  final List<ScheduleRefreshOrigin> origins = <ScheduleRefreshOrigin>[];

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    origins.add(origin);
    return ScheduleQueryResult(Schedule(), const []);
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

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected PreferencesProvider call: $invocation');
  }
}
