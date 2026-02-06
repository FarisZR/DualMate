import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';

class BackgroundCanteenUpdate extends TaskCallback {
  final CanteenProvider _canteenProvider;
  final WorkSchedulerService _scheduler;

  BackgroundCanteenUpdate(this._canteenProvider, this._scheduler);

  Future<void> updateCanteen() async {
    var today = toStartOfDay(DateTime.now());
    var token = CancellationToken();

    try {
      await _canteenProvider.refreshWeek(today, token);
      await _canteenProvider.refreshWeek(
        today.add(const Duration(days: 7)),
        token,
      );
    } catch (exception, trace) {
      print("Background canteen update failed");
      print(exception);
      print(trace);
      print("Background canteen update status: failure");
      print("Background canteen update next: retry in 8h");
      return;
    }

    print("Finished updating canteen data");
    print("Background canteen update status: success");
  }

  @override
  Future<void> run() async {
    await updateCanteen();
  }

  @override
  Future<void> cancel() async {
    await _scheduler.cancelTask(getName());
  }

  @override
  Future<void> schedule() async {
    await _scheduler.schedulePeriodic(
      const Duration(hours: 8),
      getName(),
      true,
    );
  }

  @override
  String getName() {
    return "BackgroundCanteenUpdate";
  }
}
