import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/native/widget/widget_helper.dart';
import 'package:dualmate/schedule/background/background_schedule_update.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:test/test.dart';

void main() {
  test('successful background update requests widget refresh', () async {
    final scheduleProvider = _FakeScheduleProvider();
    final scheduleSource =
        _FakeScheduleSourceProvider(_QueryableScheduleSource());
    final scheduler = _FakeWorkSchedulerService();
    final widgetHelper = _FakeWidgetHelper();

    final update = BackgroundScheduleUpdate(
      scheduleProvider,
      scheduleSource,
      scheduler,
      widgetHelper,
    );

    await update.updateSchedule();

    expect(scheduleProvider.updatedCalls, 1);
    expect(widgetHelper.refreshCalls, 1);
  });

  test('widget refresh failure is non-fatal', () async {
    final scheduleProvider = _FakeScheduleProvider();
    final scheduleSource =
        _FakeScheduleSourceProvider(_QueryableScheduleSource());
    final scheduler = _FakeWorkSchedulerService();
    final widgetHelper = _FakeWidgetHelper(throwOnRefresh: true);

    final update = BackgroundScheduleUpdate(
      scheduleProvider,
      scheduleSource,
      scheduler,
      widgetHelper,
    );

    await update.updateSchedule();

    expect(scheduleProvider.updatedCalls, 1);
    expect(widgetHelper.refreshCalls, 1);
  });

  test('invalid source skips update and widget refresh', () async {
    final scheduleProvider = _FakeScheduleProvider();
    final scheduleSource =
        _FakeScheduleSourceProvider(_InvalidScheduleSource());
    final scheduler = _FakeWorkSchedulerService();
    final widgetHelper = _FakeWidgetHelper();

    final update = BackgroundScheduleUpdate(
      scheduleProvider,
      scheduleSource,
      scheduler,
      widgetHelper,
    );

    await update.updateSchedule();

    expect(scheduleProvider.updatedCalls, 0);
    expect(widgetHelper.refreshCalls, 0);
  });
}

class _FakeScheduleProvider implements ScheduleProvider {
  int updatedCalls = 0;

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken,
  ) async {
    updatedCalls++;
    return ScheduleQueryResult(Schedule(), const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source;

  _FakeScheduleSourceProvider(this._source);

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleSourceProvider call: $invocation',
    );
  }
}

class _QueryableScheduleSource implements ScheduleSource {
  @override
  bool canQuery() => true;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) {
    throw UnimplementedError();
  }
}

class _InvalidScheduleSource implements ScheduleSource {
  @override
  bool canQuery() => false;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) {
    throw UnimplementedError();
  }
}

class _FakeWidgetHelper implements WidgetHelper {
  int refreshCalls = 0;
  final bool throwOnRefresh;

  _FakeWidgetHelper({this.throwOnRefresh = false});

  @override
  Future<void> requestWidgetRefresh() async {
    refreshCalls++;
    if (throwOnRefresh) {
      throw Exception('Widget refresh failed');
    }
  }

  @override
  Future<bool> areWidgetsSupported() async => true;

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> disableWidget() async {}

  @override
  Future<void> enableWidget() async {}

  @override
  Future<void> requestExactAlarmPermission() async {}
}

class _FakeWorkSchedulerService implements WorkSchedulerService {
  @override
  Future<void> cancelTask(String id) async {}

  @override
  Future<void> scheduleOneShotTaskAt(
      DateTime date, String id, String name) async {}

  @override
  Future<void> scheduleOneShotTaskIn(
      Duration delay, String id, String name) async {}

  @override
  Future<void> schedulePeriodic(Duration delay, String id,
      [bool needsNetwork = false]) async {}

  @override
  void registerTask(TaskCallback task) {}

  @override
  Future<void> executeTask(String id) async {}

  @override
  bool isSchedulingAvailable() => true;
}
