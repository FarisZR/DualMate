import 'package:dualmate/common/appstart/service_injector.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/schedule/reminders/class_reminder_scheduler.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('injected class reminders use DualMate saved language', () async {
    SharedPreferences.setMockInitialValues({
      PreferencesProvider.LastUsedLanguageCode: 'de-DE',
    });
    final api = _RecordingNotificationApi();
    KiwiContainer().registerInstance<NotificationApi>(api);
    addTearDown(KiwiContainer().clear);

    injectServices(false);
    injectServices(false);
    await KiwiContainer()
        .resolve<ClassReminderController>()
        .refreshPermissionState();
    final scheduler = KiwiContainer().resolve<ClassReminderScheduler>();
    final classStart = DateTime(2026, 7, 24, 8, 30);
    await scheduler.schedule(
      ClassReminderNotificationRequest(
        notificationId: -1,
        className: 'Recht',
        classStart: classStart,
        scheduledTime: classStart.subtract(const Duration(minutes: 30)),
        offset: const Duration(minutes: 30),
        room: '',
        occurrenceIdentity: 'recht',
      ),
    );

    expect(api.title, 'Recht beginnt in 30 Minuten');
  });
}

class _RecordingNotificationApi extends VoidNotificationApi {
  String? title;

  @override
  Future<void> scheduleExactNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {
    this.title = title;
  }
}
