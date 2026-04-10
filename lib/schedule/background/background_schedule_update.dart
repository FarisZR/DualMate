import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/native/widget/widget_helper.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

class BackgroundScheduleUpdate extends TaskCallback {
  static const String name = 'BackgroundScheduleUpdate';
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
        origin: ScheduleRefreshOrigin.backgroundPeriodic,
      );
    } on ScheduleQueryFailedException catch (e, trace) {
      print("Background schedule update failed");
      print(e.innerException.toString());
      print(trace);
      await AppDiagnostics.instance.reportCaughtException(
        e,
        trace,
        message: 'Background schedule update failed',
        tags: {'feature': 'schedule'},
        contexts: {
          'schedule_update': {
            'origin': ScheduleRefreshOrigin.backgroundPeriodic.name,
            'kind': 'query_failed',
          },
        },
      );
      print("Background schedule update status: failure");
      print(
          "Background schedule update next: retry in ${_updateInterval.inHours}h");
      return;
    } catch (e, trace) {
      print("Background schedule update unexpected failure");
      print(e);
      print(trace);
      await AppDiagnostics.instance.reportCaughtException(
        e,
        trace,
        message: 'Background schedule update unexpected failure',
        tags: {'feature': 'schedule'},
        contexts: {
          'schedule_update': {
            'origin': ScheduleRefreshOrigin.backgroundPeriodic.name,
            'kind': 'unexpected',
          },
        },
      );
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
      await AppDiagnostics.instance.reportCaughtException(
        e,
        trace,
        message: 'Background schedule widget refresh failed',
        tags: {'feature': 'widgets'},
        contexts: {
          'widget_refresh': {'task': name},
        },
      );
    } catch (e, trace) {
      print("Background schedule widget refresh failed");
      print(e);
      print(trace);
      await AppDiagnostics.instance.reportCaughtException(
        e,
        trace,
        message: 'Background schedule widget refresh failed',
        tags: {'feature': 'widgets'},
        contexts: {
          'widget_refresh': {'task': name},
        },
      );
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
    return name;
  }
}
