import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/date_management/business/rapla_important_events_provider.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:test/test.dart';

void main() {
  test('rapla refresh uses a silent foreground maintenance origin', () async {
    final scheduleProvider = _TrackingScheduleProvider();
    final provider = RaplaImportantEventsProvider(
      _FakePreferencesProvider(),
      scheduleProvider,
      _FakeScheduleSourceProvider(),
    );

    await provider.refreshImportantEvents(
      DateTime(2026, 3, 1),
      DateTime(2026, 6, 1),
      CancellationToken(),
    );

    expect(scheduleProvider.origins, [
      ScheduleRefreshOrigin.foregroundMaintenance,
    ]);
  });
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

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  Future<String> getRaplaUrl() async => 'https://rapla.dhbw.example?key=test';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected PreferencesProvider call: $invocation');
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
