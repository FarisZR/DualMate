import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/native/widget/widget_helper.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

class BackgroundScheduleUpdate extends TaskCallback {
  static const Duration _updateInterval = Duration(hours: 4);
  final ScheduleProvider scheduleProvider;
  final ScheduleSourceProvider scheduleSource;
  final WorkSchedulerService scheduler;
  final WidgetHelper widgetHelper;

  BackgroundScheduleUpdate(
    this.scheduleProvider,
    this.scheduleSource,
    this.scheduler,
    this.widgetHelper,
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

    try {
      await widgetHelper.requestWidgetRefresh();
    } on Exception catch (e, trace) {
      print("Background schedule widget refresh failed");
      print(e);
      print(trace);
    } catch (e, trace) {
      print("Background schedule widget refresh failed");
      print(e);
      print(trace);
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
