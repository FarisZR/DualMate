import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/native/widget/background_widget_refresher.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

class BackgroundScheduleUpdate extends TaskCallback {
  static const Duration _updateInterval = Duration(hours: 4);
  final ScheduleProvider scheduleProvider;
  final ScheduleSourceProvider scheduleSource;
  final WorkSchedulerService scheduler;
  final BackgroundWidgetRefresher _backgroundWidgetRefresher;

  BackgroundScheduleUpdate(
    this.scheduleProvider,
    this.scheduleSource,
    this.scheduler,
    this._backgroundWidgetRefresher,
  );

  Future updateSchedule() async {
    if (!scheduleSource.currentScheduleSource.canQuery()) {
      print("Cancelled update due to an invalid schedule source configuration");
      return;
    }

    var today = toDayOfWeek(toStartOfDay(DateTime.now()), DateTime.monday);
    var end = addDays(today, 14);

    var cancellationToken = CancellationToken();

    try {
      await scheduleProvider.getUpdatedSchedule(
        today,
        end,
        cancellationToken,
      );

      await _backgroundWidgetRefresher.requestRefreshSafe();
    } on ScheduleQueryFailedException catch (e, trace) {
      print("Background schedule update failed");
      print(e.innerException.toString());
      print(trace);
      print("Background schedule update status: failure");
      print(
          "Background schedule update next: retry in ${_updateInterval.inHours}h");
      return;
    } catch (e, trace) {
      print("Background schedule update unexpected failure");
      print(e);
      print(trace);
      print("Background schedule update status: failure");
      print(
          "Background schedule update next: retry in ${_updateInterval.inHours}h");
      return;
    }

    print("Finished updating schedule");
    print("Background schedule update status: success");
  }

  @override
  Future<void> run() async {
    await updateSchedule();
  }

  @override
  Future<void> cancel() async {
    await scheduler.cancelTask(getName());
  }

  @override
  Future<void> schedule() async {
    await scheduler.schedulePeriodic(
      _updateInterval,
      getName(),
      true,
    );
  }

  @override
  String getName() {
    return "BackgroundScheduleUpdate";
  }
}
