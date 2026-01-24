import 'package:dhbwstudentapp/canteen/business/canteen_provider.dart';
import 'package:dhbwstudentapp/common/background/task_callback.dart';
import 'package:dhbwstudentapp/common/background/work_scheduler_service.dart';
import 'package:dhbwstudentapp/common/util/cancellation_token.dart';
import 'package:dhbwstudentapp/common/util/date_utils.dart';

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
      return;
    }

    print("Finished updating canteen data");
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
