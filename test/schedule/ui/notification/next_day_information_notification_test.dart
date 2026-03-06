import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/notification/next_day_information_notification.dart';
import 'package:test/test.dart';

void main() {
  test('run loads localization from preferences without Kiwi registration',
      () async {
    final notificationApi = _RecordingNotificationApi();
    final notification = NextDayInformationNotification(
      notificationApi,
      _FakeScheduleEntryRepository(
        ScheduleEntry(
          start: DateTime.now().add(const Duration(days: 1, hours: 9)),
          end: DateTime.now().add(const Duration(days: 1, hours: 10)),
          title: 'Mathematics',
          details: '',
          professor: '',
          room: '',
          type: ScheduleEntryType.Class,
        ),
      ),
      _FakeWorkSchedulerService(),
      _FakePreferencesProvider(),
    );

    await notification.run();

    expect(notificationApi.title, isNotEmpty);
    expect(notificationApi.message, contains('Mathematics'));
  });
}

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  Future<bool> getNotifyAboutNextDay() async => true;

  @override
  Future<String?> getLastUsedLanguageCode() async => 'en';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingNotificationApi extends VoidNotificationApi {
  String title = '';
  String message = '';

  @override
  Future<void> showNotification(String title, String message, [int? id]) async {
    this.title = title;
    this.message = message;
  }
}

class _FakeScheduleEntryRepository implements ScheduleEntryRepository {
  final ScheduleEntry? nextEntry;

  _FakeScheduleEntryRepository(this.nextEntry);

  @override
  Future<ScheduleEntry?> queryNextScheduleEntry(DateTime now) async =>
      nextEntry;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWorkSchedulerService implements WorkSchedulerService {
  @override
  Future<void> cancelTask(String id) async {}

  @override
  Future<void> executeTask(String id) async {}

  @override
  bool isSchedulingAvailable() => false;

  @override
  void registerTask(task) {}

  @override
  Future<void> scheduleOneShotTaskAt(
    DateTime date,
    String id,
    String name,
  ) async {}

  @override
  Future<void> scheduleOneShotTaskIn(
    Duration delay,
    String id,
    String name,
  ) async {}

  @override
  Future<void> schedulePeriodic(
    Duration delay,
    String id, [
    bool needsNetwork = false,
  ]) async {}
}
