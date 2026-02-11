import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

///
/// Provides methods to display native notifications
///
class NotificationApi {
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  ///
  /// Initialize the notifications. You can't show any notifications before you
  /// call this method
  ///
  Future<void> initialize() async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      'outline_event_note_24',
    );

    const initializationSettingsIOS = DarwinInitializationSettings();

    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: selectNotification,
    );
    await _requestRuntimePermissions();
  }

  Future<void> _requestRuntimePermissions() async {
    final androidPlugin =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
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

  void selectNotification(NotificationResponse notificationResponse) {}
}

///
/// This class implements the methods of the NotificationApi with empty stubs
///
class VoidNotificationApi implements NotificationApi {
  final FlutterLocalNotificationsPlugin _voidLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  FlutterLocalNotificationsPlugin get _localNotificationsPlugin =>
      _voidLocalNotificationsPlugin;

  @override
  Future<void> initialize() {
    return Future.value();
  }

  @override
  void selectNotification(NotificationResponse notificationResponse) {}

  @override
  Future<void> showNotification(String title, String message, [int? id]) {
    return Future.value();
  }

  @override
  Future<void> _requestRuntimePermissions() {
    return Future.value();
  }
}
