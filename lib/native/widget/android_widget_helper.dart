import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/native/widget/widget_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

///
/// WidgetHelper which calls native code to control the widget on android
///
class AndroidWidgetHelper implements WidgetHelper {
  static const platform = const MethodChannel('com.fariszr.dualmate/widget');

  @override
  Future<void> disableWidget() async {
    try {
      await platform.invokeMethod('disableWidget');
    } on PlatformException catch (_) {}
  }

  @override
  Future<void> enableWidget() async {
    try {
      await platform.invokeMethod('enableWidget');
    } on PlatformException catch (_) {}
  }

  @override
  Future<void> requestWidgetRefresh() async {
    try {
      await platform.invokeMethod('requestWidgetRefresh');
      await platform.invokeMethod('requestWidgetLaunchIntent');
    } on Exception catch (exception, trace) {
      if (kDebugMode) {
        debugPrint(
          'AndroidWidgetHelper.requestWidgetRefresh failed: $exception\n$trace',
        );
      }
      await reportException(exception, trace);
    }
  }

  @override
  Future<bool> areWidgetsSupported() async {
    try {
      return await platform.invokeMethod('areWidgetsSupported');
    } on Exception catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    try {
      return await platform.invokeMethod('canScheduleExactAlarms');
    } on Exception catch (_) {
      return false;
    }
  }

  @override
  Future<void> requestExactAlarmPermission() async {
    try {
      await platform.invokeMethod('requestExactAlarmPermission');
    } on PlatformException catch (_) {}
  }
}
