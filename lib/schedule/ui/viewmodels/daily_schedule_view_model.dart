import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';

class DailyScheduleViewModel extends BaseViewModel {
  static const Duration weekDuration = Duration(days: 7);

  final ScheduleProvider scheduleProvider;

  DateTime currentDate = DateTime.now();

  Schedule daySchedule = Schedule();

  bool _isDisposed = false;

  DailyScheduleViewModel(this.scheduleProvider) {
    scheduleProvider.addScheduleUpdatedCallback(_scheduleUpdatedCallback);

    loadScheduleForToday();
  }

  Future<void> setSchedule(Schedule schedule) async {
    daySchedule = schedule;
    if (_isDisposed) return;
    notifyListeners("daySchedule");
  }

  Future loadScheduleForToday() async {
    var now = DateTime.now();
    currentDate = toStartOfDay(now);

    await updateSchedule();
  }

  Future updateSchedule() async {
    await _updateScheduleFromCache();
  }

  Future _updateScheduleFromCache() async {
    setSchedule(
      await scheduleProvider.getCachedSchedule(
        currentDate,
        tomorrow(currentDate),
      ),
    );
  }

  Future<void> _scheduleUpdatedCallback(
    Schedule schedule,
    DateTime start,
    DateTime end,
  ) async {
    if (_isDisposed) return;
    start = toStartOfDay(start);
    end = toStartOfDay(tomorrow(end));

    if (!(start.isAfter(currentDate) || end.isBefore(currentDate))) {
      setSchedule(
        schedule.trim(
          toStartOfDay(currentDate),
          toStartOfDay(tomorrow(currentDate)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    scheduleProvider.removeScheduleUpdatedCallback(
      _scheduleUpdatedCallback,
    );
    super.dispose();
  }
}
