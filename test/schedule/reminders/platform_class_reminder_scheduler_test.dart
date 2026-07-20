import 'dart:convert';
import 'dart:ui';

import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:dualmate/schedule/reminders/class_reminder_scheduler.dart';
import 'package:dualmate/schedule/reminders/platform_class_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('formats and schedules an English 30-minute reminder', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    final api = _RecordingNotificationApi();
    final scheduler = PlatformClassReminderScheduler(() => api);
    final classStart = DateTime(2026, 7, 24, 8, 30);
    final scheduledTime = classStart.subtract(const Duration(minutes: 30));

    await scheduler.schedule(
      ClassReminderNotificationRequest(
        notificationId: -123,
        className: 'Recht',
        classStart: classStart,
        scheduledTime: scheduledTime,
        offset: const Duration(minutes: 30),
        room: '',
        occurrenceIdentity: 'recht-occurrence',
      ),
    );

    expect(api.id, -123);
    expect(api.title, 'Recht starts in 30 minutes');
    expect(api.body, 'The class begins at 8:30.');
    expect(api.scheduledTime, scheduledTime);
    final payload = jsonDecode(api.payload!) as Map<String, dynamic>;
    expect(payload[widgetScheduleEntryTitle], 'Recht');
    expect(
      payload[widgetScheduleEntryStart],
      classStart.millisecondsSinceEpoch,
    );
    expect(payload[widgetScheduleDayStart], classStart.millisecondsSinceEpoch);
  });

  testWidgets('formats a German one-hour reminder with its room', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('de');
    final api = _RecordingNotificationApi();
    final scheduler = PlatformClassReminderScheduler(
      () => api,
      languageCode: () async => 'de-DE',
    );
    final classStart = DateTime(2026, 7, 24, 15);

    await scheduler.schedule(
      ClassReminderNotificationRequest(
        notificationId: -456,
        className: 'Recht',
        classStart: classStart,
        scheduledTime: classStart.subtract(const Duration(hours: 1)),
        offset: const Duration(hours: 1),
        room: 'H 301',
        occurrenceIdentity: 'recht-occurrence',
      ),
    );

    expect(api.title, 'Recht beginnt in 1 Stunde');
    expect(api.body, 'Die Veranstaltung beginnt um 15:00 in H 301.');
  });

  test('uses singular wording for a custom one-minute reminder', () async {
    final api = _RecordingNotificationApi();
    final scheduler = PlatformClassReminderScheduler(
      () => api,
      languageCode: () async => 'de',
    );
    final classStart = DateTime(2026, 7, 24, 15);

    await scheduler.schedule(
      ClassReminderNotificationRequest(
        notificationId: -457,
        className: 'Recht',
        classStart: classStart,
        scheduledTime: classStart.subtract(const Duration(minutes: 1)),
        offset: const Duration(minutes: 1),
        room: '',
        occurrenceIdentity: 'recht-occurrence',
      ),
    );

    expect(api.title, 'Recht beginnt in 1 Minute');
  });

  test('cancels only the supplied class-reminder identifier', () async {
    final api = _RecordingNotificationApi();
    final scheduler = PlatformClassReminderScheduler(() => api);

    await scheduler.cancel(-789);

    expect(api.cancelledIds, [-789]);
  });
}

class _RecordingNotificationApi extends VoidNotificationApi {
  int? id;
  String? title;
  String? body;
  DateTime? scheduledTime;
  String? payload;
  final List<int> cancelledIds = [];

  @override
  Future<void> scheduleExactNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {
    this.id = id;
    this.title = title;
    this.body = body;
    this.scheduledTime = scheduledTime;
    this.payload = payload;
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);
  }
}
