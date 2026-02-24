import 'package:dualmate/native/widget/widget_helper.dart';

class BackgroundWidgetRefresher {
  final WidgetHelper _widgetHelper;

  BackgroundWidgetRefresher(this._widgetHelper);

  Future<bool> requestRefreshSafe() async {
    try {
      await _widgetHelper.requestWidgetRefresh();
      return true;
    } catch (e, trace) {
      print("Background widget refresh failed");
      print(e);
      print(trace);
      return false;
    }
  }
}