import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:dualmate/ui/navigation/main_section_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

///
/// Provides methods to display native notifications
///
typedef NotificationPluginInitializer =
    Future<bool?> Function(
      FlutterLocalNotificationsPlugin plugin,
      InitializationSettings settings,
      DidReceiveNotificationResponseCallback onDidReceiveNotificationResponse,
    );

typedef NotificationRuntimePermissionRequester =
    Future<bool?> Function(FlutterLocalNotificationsPlugin plugin);

typedef NotificationChannelEnabledChecker =
    Future<bool> Function(FlutterLocalNotificationsPlugin plugin);

typedef NotificationChannelSettingsOpener = Future<bool> Function();

class NotificationApi {
  static const String classReminderChannelId = 'class_reminders';
  static const MethodChannel _settingsChannel = MethodChannel(
    'com.fariszr.dualmate/notification_settings',
  );

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin;
  final NotificationPluginInitializer _pluginInitializer;
  final NotificationRuntimePermissionRequester _runtimePermissionRequester;
  final NotificationChannelEnabledChecker _classReminderChannelChecker;
  final NotificationChannelSettingsOpener _classReminderSettingsOpener;

  NotificationApi({
    FlutterLocalNotificationsPlugin? localNotificationsPlugin,
    NotificationPluginInitializer? pluginInitializer,
    NotificationRuntimePermissionRequester? runtimePermissionRequester,
    NotificationChannelEnabledChecker? classReminderChannelChecker,
    NotificationChannelSettingsOpener? classReminderSettingsOpener,
  }) : _localNotificationsPlugin =
           localNotificationsPlugin ?? FlutterLocalNotificationsPlugin(),
       _pluginInitializer = pluginInitializer ?? _defaultPluginInitializer,
       _runtimePermissionRequester =
           runtimePermissionRequester ?? _defaultRuntimePermissionRequester,
       _classReminderChannelChecker =
           classReminderChannelChecker ?? _defaultClassReminderChannelChecker,
       _classReminderSettingsOpener =
           classReminderSettingsOpener ?? _defaultClassReminderSettingsOpener;

  ///
  /// Initialize the notifications. You can't show any notifications before you
  /// call this method
  ///
  Future<void> initialize({bool requestRuntimePermission = true}) async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      'outline_event_note_24',
    );

    const initializationSettingsIOS = DarwinInitializationSettings();

    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _pluginInitializer(
      _localNotificationsPlugin,
      initializationSettings,
      selectNotification,
    );
    try {
      final launchDetails = await _localNotificationsPlugin
          .getNotificationAppLaunchDetails();
      final launchResponse = launchDetails?.notificationResponse;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchResponse != null) {
        selectNotification(launchResponse);
      }
    } catch (_) {
      // Some test and unsupported platform implementations omit launch details.
    }
    if (requestRuntimePermission) {
      unawaited(this.requestRuntimePermission());
    }
  }

  Future<bool?> requestRuntimePermission() async {
    return _requestRuntimePermissionsBestEffort();
  }

  Future<bool?> _requestRuntimePermissionsBestEffort() async {
    try {
      final granted = await _runtimePermissionRequester(
        _localNotificationsPlugin,
      );
      developer.log(
        'Notification runtime permission requested: $granted',
        name: 'notification_api',
      );
      return granted;
    } catch (error, trace) {
      developer.log(
        'Notification runtime permission request failed',
        name: 'notification_api',
        error: error,
        stackTrace: trace,
      );
      await reportException(error, trace);
      return null;
    }
  }

  static Future<bool?> _defaultPluginInitializer(
    FlutterLocalNotificationsPlugin plugin,
    InitializationSettings settings,
    DidReceiveNotificationResponseCallback onDidReceiveNotificationResponse,
  ) {
    return plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
  }

  static Future<bool?> _defaultRuntimePermissionRequester(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return androidPlugin?.requestNotificationsPermission();
  }

  static Future<bool> _defaultClassReminderChannelChecker(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final channels = await androidPlugin?.getNotificationChannels();
    if (channels == null) return false;
    final matching = channels.where(
      (channel) => channel.id == classReminderChannelId,
    );
    if (matching.isEmpty) return true;
    return matching.first.importance != Importance.none;
  }

  static Future<bool> _defaultClassReminderSettingsOpener() async {
    return await _settingsChannel.invokeMethod<bool>(
          'openClassReminderNotificationSettings',
          {'channelId': classReminderChannelId},
        ) ??
        false;
  }

  ///
  /// Show a notification with the given title and message
  ///
  Future<void> showNotification(String title, String message, [int? id]) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'Notifications',
      'Notifications',
      channelDescription: 'This is the main notification channel',
      icon: 'outline_event_note_24',
      channelAction: AndroidNotificationChannelAction.createIfNotExists,
      autoCancel: true,
      channelShowBadge: false,
      color: Colors.red,
      enableLights: true,
      enableVibration: true,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();

    var platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotificationsPlugin.show(
      // TODO: This is a quick and dirty fix. Find a better solution in the future
      id ?? Random().nextInt(1 << 30),
      title,
      message,
      platformChannelSpecifics,
      payload: "",
    );
  }

  Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await androidPlugin?.areNotificationsEnabled() ?? false;
  }

  Future<bool> areClassRemindersEnabled() {
    return _classReminderChannelChecker(_localNotificationsPlugin);
  }

  Future<bool> openClassReminderSettings() async {
    try {
      return await _classReminderSettingsOpener();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> canScheduleExactNotifications() async {
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  Future<bool> requestExactAlarmPermission() async {
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await androidPlugin?.requestExactAlarmsPermission() ?? false;
  }

  Future<void> scheduleExactNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      classReminderChannelId,
      'Class reminders',
      channelDescription: 'Reliable reminders before scheduled classes',
      icon: 'outline_event_note_24',
      channelAction: AndroidNotificationChannelAction.createIfNotExists,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.getLocation('Europe/Berlin')),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) {
    return _localNotificationsPlugin.cancel(id);
  }

  void selectNotification(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;
      final schedulePayload = WidgetScheduleEntryPayload.fromMap(decoded);
      if (schedulePayload.isEmpty) return;
      WidgetNavigationPayloadStore.instance.setSchedulePayload(schedulePayload);
      MainSectionController.instance.openRoute('schedule');
    } on FormatException {
      return;
    }
  }
}

///
/// This class implements the methods of the NotificationApi with empty stubs
///
class VoidNotificationApi extends NotificationApi {
  @override
  Future<void> initialize({bool requestRuntimePermission = true}) =>
      Future.value();

  @override
  Future<bool?> requestRuntimePermission() => Future.value(null);

  @override
  Future<bool> areNotificationsEnabled() => Future.value(false);

  @override
  Future<bool> areClassRemindersEnabled() => Future.value(false);

  @override
  Future<bool> openClassReminderSettings() => Future.value(false);

  @override
  Future<bool> canScheduleExactNotifications() => Future.value(false);

  @override
  Future<bool> requestExactAlarmPermission() => Future.value(false);

  @override
  Future<void> scheduleExactNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) => Future.value();

  @override
  Future<void> cancelNotification(int id) => Future.value();

  @override
  void selectNotification(NotificationResponse notificationResponse) {}

  @override
  Future<void> showNotification(String title, String message, [int? id]) =>
      Future.value();
}
