import 'dart:io';

import 'package:dualmate/canteen/background/background_canteen_update.dart';
import 'package:dualmate/common/appstart/performance_fixture_mode.dart';
import 'package:dualmate/common/background/background_work_scheduler.dart';
import 'package:dualmate/common/background/void_background_work_scheduler.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/schedule/background/background_schedule_update.dart';
import 'package:dualmate/schedule/ui/notification/next_day_information_notification.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:kiwi/kiwi.dart';

///
/// Initializes the background scheduler and schedules all tasks.
/// Note: More or less reliable background scheduling only works on android
///
class BackgroundInitialize {
  final WorkSchedulerService Function()? _schedulerFactory;

  BackgroundInitialize({WorkSchedulerService Function()? schedulerFactory})
    : _schedulerFactory = schedulerFactory;

  Future<void> setupBackgroundScheduling() async {
    WorkSchedulerService scheduler;
    if (_schedulerFactory != null) {
      scheduler = _schedulerFactory();
    } else if (Platform.isAndroid && !isPerformanceFixtureMode) {
      scheduler = BackgroundWorkScheduler();
    } else {
      scheduler = VoidBackgroundWorkScheduler();
    }

    final container = KiwiContainer();
    container.registerInstance<WorkSchedulerService>(scheduler);
    final reminderController = container.isRegistered<ClassReminderController>()
        ? container.resolve<ClassReminderController>()
        : null;

    var tasks = [
      BackgroundCanteenUpdate(container.resolve(), container.resolve()),
      BackgroundScheduleUpdate(
        container.resolve(),
        container.resolve(),
        container.resolve(),
        container.resolve(),
        reminderController: reminderController,
      ),
      NextDayInformationNotification(
        container.resolve(),
        container.resolve(),
        container.resolve(),
        container.resolve(),
      ),
    ];

    for (var task in tasks) {
      scheduler.registerTask(task);
      container.registerInstance(task, name: task.getName());
    }

    for (var task in tasks) {
      await task.schedule();
    }
  }
}
