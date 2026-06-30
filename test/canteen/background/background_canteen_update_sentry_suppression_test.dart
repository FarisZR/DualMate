import 'package:dualmate/canteen/background/background_canteen_update.dart';
import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'expected network failure does not crash and completes the update',
    () async {
      final update = BackgroundCanteenUpdate(
        _ThrowingCanteenProvider(ServiceRequestFailed('Http request failed!')),
        _FakeWorkSchedulerService(),
      );

      await expectLater(update.updateCanteen(), completes);
    },
  );

  test('unexpected error does not crash and completes the update', () async {
    final update = BackgroundCanteenUpdate(
      _ThrowingCanteenProvider(StateError('unexpected canteen failure')),
      _FakeWorkSchedulerService(),
    );

    await expectLater(update.updateCanteen(), completes);
  });
}

class _ThrowingCanteenProvider implements CanteenProvider {
  final Object _error;

  _ThrowingCanteenProvider(this._error);

  @override
  Future<List<DailyMenu>> refreshWeek(
    DateTime date, [
    CancellationToken? cancellationToken,
  ]) async {
    throw _error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected CanteenProvider call: $invocation');
  }
}

class _FakeWorkSchedulerService implements WorkSchedulerService {
  @override
  Future<void> cancelTask(String id) async {}

  @override
  Future<void> scheduleOneShotTaskAt(
    DateTime date,
    String id,
    String name,
  ) async {}

  @override
  Future<void> scheduleOneShotTaskIn(
    Duration delay,
    String id,
    String name,
  ) async {}

  @override
  Future<void> schedulePeriodic(
    Duration delay,
    String id, [
    bool needsNetwork = false,
  ]) async {}

  @override
  void registerTask(TaskCallback task) {}

  @override
  Future<void> executeTask(String id) async {}

  @override
  bool isSchedulingAvailable() => true;
}
