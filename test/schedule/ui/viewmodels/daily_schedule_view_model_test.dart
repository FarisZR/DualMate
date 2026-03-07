import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/ui/viewmodels/daily_schedule_view_model.dart';
import 'package:test/test.dart';

void main() {
  test('daily schedule waits for explicit initialization before reading cache',
      () async {
    final provider = _TrackingScheduleProvider();
    final viewModel = DailyScheduleViewModel(provider);

    expect(provider.cachedRequests, 0);

    await viewModel.initialize();
    expect(provider.cachedRequests, 1);

    await viewModel.initialize();
    expect(provider.cachedRequests, 1);
  });
}

class _TrackingScheduleProvider implements ScheduleProvider {
  int cachedRequests = 0;

  @override
  void addScheduleUpdatedCallback(ScheduleUpdatedCallback callback) {}

  @override
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
    cachedRequests += 1;
    return Schedule();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}
