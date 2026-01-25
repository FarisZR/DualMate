import 'dart:io';

import 'package:dualmate/canteen/background/background_canteen_update.dart';
import 'package:dualmate/common/background/background_work_scheduler.dart';
import 'package:dualmate/common/background/void_background_work_scheduler.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/schedule/background/background_schedule_update.dart';
import 'package:dualmate/schedule/ui/notification/next_day_information_notification.dart';
import 'package:kiwi/kiwi.dart';

///
/// Initializes the background scheduler and schedules all tasks.
/// Note: More or less reliable background scheduling only works on android
///
class BackgroundInitialize {
  Future<void> setupBackgroundScheduling() async {
    WorkSchedulerService scheduler;
    if (Platform.isAndroid) {
      scheduler = BackgroundWorkScheduler();
    } else {
      scheduler = VoidBackgroundWorkScheduler();
    }

    KiwiContainer().registerInstance<WorkSchedulerService>(scheduler);

    var tasks = [
      BackgroundCanteenUpdate(
        KiwiContainer().resolve(),
        KiwiContainer().resolve(),
      ),
      BackgroundScheduleUpdate(
        KiwiContainer().resolve(),
        KiwiContainer().resolve(),
        KiwiContainer().resolve(),
      ),
      NextDayInformationNotification(
        KiwiContainer().resolve(),
        KiwiContainer().resolve(),
        KiwiContainer().resolve(),
        KiwiContainer().resolve(),
        KiwiContainer().resolve(),
      ),
    ];

    for (var task in tasks) {
      scheduler.registerTask(task);

      KiwiContainer().registerInstance(
        task,
        name: task.getName(),
      );

      await task.schedule();
    }
  }
}
