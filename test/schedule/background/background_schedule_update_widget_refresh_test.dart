import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/native/widget/background_widget_refresher.dart';
import 'package:dualmate/schedule/background/background_schedule_update.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:test/test.dart';

void main() {
  test('calls widget refresher after successful schedule update', () async {
    final provider = _FakeScheduleProvider();
    final sourceProvider = _FakeScheduleSourceProvider(canQuery: true);
    final scheduler = _FakeWorkSchedulerService();
    final refresher = _FakeBackgroundWidgetRefresher();

    final subject = BackgroundScheduleUpdate(
      provider,
      sourceProvider,
      scheduler,
      refresher,
    );

    await subject.updateSchedule();

    expect(provider.updateCallCount, 1);
    expect(refresher.requestCallCount, 1);
  });

  test('does not update schedule when source can not query', () async {
    final provider = _FakeScheduleProvider();
    final sourceProvider = _FakeScheduleSourceProvider(canQuery: false);
    final scheduler = _FakeWorkSchedulerService();
    final refresher = _FakeBackgroundWidgetRefresher();

    final subject = BackgroundScheduleUpdate(
      provider,
      sourceProvider,
      scheduler,
      refresher,
    );

    await subject.updateSchedule();

    expect(provider.updateCallCount, 0);
    expect(refresher.requestCallCount, 0);
  });

  test('handles schedule query failure without widget refresh', () async {
    final provider = _FakeScheduleProvider(
      shouldThrowFailure: true,
    );
    final sourceProvider = _FakeScheduleSourceProvider(canQuery: true);
    final scheduler = _FakeWorkSchedulerService();
    final refresher = _FakeBackgroundWidgetRefresher();

    final subject = BackgroundScheduleUpdate(
      provider,
      sourceProvider,
      scheduler,
      refresher,
    );

    await subject.updateSchedule();

    expect(provider.updateCallCount, 1);
    expect(refresher.requestCallCount, 0);
  });
}

class _FakeScheduleProvider implements ScheduleProvider {
  int updateCallCount = 0;
  final bool shouldThrowFailure;

  _FakeScheduleProvider({
    this.shouldThrowFailure = false,
  });

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken,
  ) async {
    updateCallCount++;

    if (shouldThrowFailure) {
      throw ScheduleQueryFailedException(Exception('schedule query failed'));
    }

    return ScheduleQueryResult(Schedule(), const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source;

  _FakeScheduleSourceProvider({
    required bool canQuery,
  }) : _source = _FakeScheduleSource(canQuery);

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleSource implements ScheduleSource {
  final bool _canQuery;

  _FakeScheduleSource(this._canQuery);

  @override
  bool canQuery() => _canQuery;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    return ScheduleQueryResult(Schedule(), const []);
  }
}

class _FakeWorkSchedulerService implements WorkSchedulerService {
  @override
  Future<void> cancelTask(String id) async {}

  @override
  Future<void> executeTask(String id) async {}

  @override
  bool isSchedulingAvailable() => true;

  @override
  void registerTask(task) {}

  @override
  Future<void> scheduleOneShotTaskAt(DateTime date, String id, String name) async {}

  @override
  Future<void> scheduleOneShotTaskIn(Duration delay, String id, String name) async {}

  @override
  Future<void> schedulePeriodic(Duration delay, String id, [bool needsNetwork = false]) async {}
}

class _FakeBackgroundWidgetRefresher implements BackgroundWidgetRefresher {
  int requestCallCount = 0;

  @override
  Future<bool> requestRefreshSafe() async {
    requestCallCount++;
    return true;
  }
}
