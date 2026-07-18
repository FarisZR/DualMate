import 'dart:convert';
import 'dart:ui';

import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:dualmate/schedule/reminders/class_reminder_scheduler.dart';

class PlatformClassReminderScheduler implements ClassReminderScheduler {
  final NotificationApi Function() _notificationApi;

  PlatformClassReminderScheduler(this._notificationApi);

  @override
  Future<void> cancel(int notificationId) {
    return _notificationApi().cancelNotification(notificationId);
  }

  @override
  Future<void> schedule(ClassReminderNotificationRequest request) {
    final isGerman = PlatformDispatcher.instance.locale.languageCode == 'de';
    final offsetText = request.offset.inMinutes == 60
        ? (isGerman ? '1 Stunde' : '1 hour')
        : '${request.offset.inMinutes} ${isGerman ? 'Minuten' : 'minutes'}';
    final title = isGerman
        ? '${request.className} beginnt in $offsetText'
        : '${request.className} starts in $offsetText';
    final minute = request.classStart.minute.toString().padLeft(2, '0');
    final time = '${request.classStart.hour}:$minute';
    final room = request.room.trim();
    final body = isGerman
        ? 'Die Veranstaltung beginnt um $time${room.isEmpty ? '.' : ' in $room.'}'
        : 'The class begins at $time${room.isEmpty ? '.' : ' in $room.'}';
    return _notificationApi().scheduleExactNotification(
      id: request.notificationId,
      title: title,
      body: body,
      scheduledTime: request.scheduledTime,
      payload: jsonEncode({
        widgetScheduleEntryStart: request.classStart.millisecondsSinceEpoch,
        widgetScheduleEntryTitle: request.className,
        widgetScheduleDayStart: request.classStart.millisecondsSinceEpoch,
      }),
    );
  }
}
