import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';

class DailyScheduleViewModel extends BaseViewModel {
  static const Duration weekDuration = Duration(days: 7);

  final ScheduleProvider scheduleProvider;
  bool _initialized = false;

  DateTime currentDate = DateTime.now();

  Schedule daySchedule = Schedule();

  DailyScheduleViewModel(this.scheduleProvider) {
    scheduleProvider.addScheduleUpdatedCallback(_scheduleUpdatedCallback);
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    await loadScheduleForToday();
  }

  Future<void> setSchedule(Schedule schedule) async {
    daySchedule = schedule;
    if (isDisposed) return;
    notifyIfMounted("daySchedule");
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
    if (isDisposed) return;
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
    scheduleProvider.removeScheduleUpdatedCallback(
      _scheduleUpdatedCallback,
    );
    super.dispose();
  }
}
