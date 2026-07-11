import 'package:dualmate/common/appstart/performance_fixture_mode.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'initialize does not notify isInitializingScheduleSource when already true',
    () {
      // In fixture mode initialization completes immediately (Issue 8 fix),
      // so a notification fires for the state change from true→false.
      if (isPerformanceFixtureMode) {
        return;
      }

      final viewModel = ScheduleViewModel(_FakeScheduleSourceProvider());
      var notifications = 0;
      viewModel.addListener((_) => notifications += 1, const [
        'isInitializingScheduleSource',
      ]);

      viewModel.initialize();

      expect(notifications, 0);
      viewModel.dispose();
    },
  );

  test(
    'fixture mode: initialization completes immediately when source is valid',
    () {
      // This test verifies the fixture-mode fix for Issue 8.
      // Run with --dart-define=PERF_TEST_OFFLINE_FIXTURES=true to exercise
      // the fixture code path.  When the const is true, _scheduleInitialSetup
      // must mark initialization complete without waiting for a Timer callback.
      if (!isPerformanceFixtureMode) {
        return;
      }

      final viewModel = ScheduleViewModel(_FakeScheduleSourceProvider());
      viewModel.initialize();

      expect(viewModel.isInitializingScheduleSource, isFalse,
          reason: 'Fixture mode must complete initialization immediately '
              'when the source is already valid.');
      expect(viewModel.didAttemptSetup, isTrue);
      viewModel.dispose();
    },
  );
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
