import 'package:dhbwstudentapp/canteen/business/canteen_provider.dart';
import 'package:dhbwstudentapp/canteen/model/daily_menu.dart';
import 'package:dhbwstudentapp/native/widget/widget_helper.dart';
import 'package:dhbwstudentapp/schedule/business/schedule_provider.dart';
import 'package:dhbwstudentapp/schedule/model/schedule.dart';

///
/// This class registers a callback to update the widgets when the schedule
/// was updated
///
class WidgetUpdateCallback {
  final WidgetHelper _widgetHelper;

  WidgetUpdateCallback(this._widgetHelper);

  void registerScheduleCallback(ScheduleProvider provider) {
    provider.addScheduleUpdatedCallback(_scheduleCallback);
  }

  void registerCanteenCallback(CanteenProvider provider) {
    provider.addMenuUpdatedCallback(_canteenCallback);
  }

  Future<void> _scheduleCallback(
    Schedule schedule,
    DateTime start,
    DateTime end,
  ) async {
    await _widgetHelper.requestWidgetRefresh();
  }

  Future<void> _canteenCallback(
    List<DailyMenu> menus,
    DateTime start,
    DateTime end,
  ) async {
    await _widgetHelper.requestWidgetRefresh();
  }
}
