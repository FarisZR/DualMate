import 'dart:io';

import 'package:dhbwstudentapp/native/widget/android_widget_helper.dart';
import 'package:dhbwstudentapp/native/widget/ios_widget_helper.dart';

///
/// Flutter part of the native widgets. This class calls the native platform
/// methods to enable/disable or update the widget
///
class WidgetHelper {
  static WidgetHelper? _instance;

  factory WidgetHelper() {
    _instance ??= _createInstance();
    return _instance!;
  }

  static WidgetHelper _createInstance() {
    if (Platform.isAndroid) {
      return AndroidWidgetHelper();
    } else if (Platform.isIOS) {
      return IOSWidgetHelper();
    }
    return VoidWidgetHelper();
  }

  ///
  /// Updates the widgets. This may not be immediateley but an update is
  /// scheduled and will happen soon.
  ///
  Future<void> requestWidgetRefresh() {
    _instance ??= _createInstance();
    return _instance!.requestWidgetRefresh();
  }

  ///
  /// Checks if widgets are supported by the device
  ///
  Future<bool> areWidgetsSupported() {
    _instance ??= _createInstance();
    return _instance!.areWidgetsSupported();
  }

  ///
  /// Enables the widget. When the widget is in "enabled" state it will provide
  /// its full functionality.
  ///
  Future<void> enableWidget() {
    _instance ??= _createInstance();
    return _instance!.enableWidget();
  }

  ///
  /// Disables the widget. When the widget is in "disabled" state it will
  /// only provide placeholder content or limited functionality.
  ///
  Future<void> disableWidget() {
    _instance ??= _createInstance();
    return _instance!.disableWidget();
  }

  ///
  /// Checks if exact alarms can be scheduled on the device.
  ///
  Future<bool> canScheduleExactAlarms() {
    _instance ??= _createInstance();
    return _instance!.canScheduleExactAlarms();
  }

  ///
  /// Requests the exact alarm permission on Android 12+.
  ///
  Future<void> requestExactAlarmPermission() {
    _instance ??= _createInstance();
    return _instance!.requestExactAlarmPermission();
  }
}

///
/// Implementation of the WidgetHelper which does nothing
///
class VoidWidgetHelper implements WidgetHelper {
  @override
  Future<void> disableWidget() {
    return Future.value();
  }

  @override
  Future<void> enableWidget() {
    return Future.value();
  }

  @override
  Future<void> requestWidgetRefresh() {
    return Future.value();
  }

  @override
  Future<bool> areWidgetsSupported() {
    return Future.value(false);
  }

  @override
  Future<bool> canScheduleExactAlarms() {
    return Future.value(true);
  }

  @override
  Future<void> requestExactAlarmPermission() {
    return Future.value();
  }
}
