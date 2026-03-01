import 'dart:math';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

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
  Future<void> initialize({bool requestRuntimePermission = true}) async {
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
    if (requestRuntimePermission) {
      await _requestRuntimePermissions();
    }
  }

  Future<void> _requestRuntimePermissions() async {
    final androidPlugin =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    try {
      final granted = await androidPlugin?.requestNotificationsPermission();
      developer.log(
        'Notification runtime permission requested: $granted',
        name: 'notification_api',
      );
    } on PlatformException catch (error, trace) {
      developer.log(
        'Notification runtime permission request failed',
        name: 'notification_api',
        error: error,
        stackTrace: trace,
      );
      rethrow;
    } on Exception catch (error, trace) {
      developer.log(
        'Notification runtime permission request failed',
        name: 'notification_api',
        error: error,
        stackTrace: trace,
      );
      rethrow;
    }
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
class VoidNotificationApi extends NotificationApi {
  @override
  Future<void> initialize({bool requestRuntimePermission = true}) =>
      Future.value();

  @override
  void selectNotification(NotificationResponse notificationResponse) {}

  @override
  Future<void> showNotification(String title, String message, [int? id]) =>
      Future.value();
}
