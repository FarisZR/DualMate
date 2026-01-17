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
    var initializationSettingsAndroid = const AndroidInitializationSettings(
      'outline_event_note_24',
    );

    var initializationSettingsIOS = DarwinInitializationSettings(
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: selectNotification,
    );
  }

  ///
  /// Show a notification with the given title and message
  ///
  Future showNotification(String title, String message, [int id]) async {
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

  void onDidReceiveLocalNotification(
      int id, String title, String body, String payload) {}

  void selectNotification(NotificationResponse notificationResponse) {}
}

///
/// This class implements the methods of the NotificationApi with empty stubs
///
class VoidNotificationApi implements NotificationApi {
  @override
  FlutterLocalNotificationsPlugin get _localNotificationsPlugin =>
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() {
    return Future.value();
  }

  @override
  void onDidReceiveLocalNotification(
      int id, String title, String body, String payload) {}

  @override
  void selectNotification(NotificationResponse notificationResponse) {}

  @override
  Future showNotification(String title, String message, [int id]) {
    return Future.value();
  }
}
