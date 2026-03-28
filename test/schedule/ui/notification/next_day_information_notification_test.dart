import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/notification/next_day_information_notification.dart';
import 'package:test/test.dart';

void main() {
  test(
    'run loads localization from preferences without Kiwi registration',
    () async {
      final now = DateTime(2026, 3, 8, 20);
      final notificationApi = _RecordingNotificationApi();
      final notification = NextDayInformationNotification(
        notificationApi,
        _FakeScheduleEntryRepository([
          ScheduleEntry(
            start: DateTime(now.year, now.month, now.day + 1, 7),
            end: DateTime(now.year, now.month, now.day + 1, 8),
            title: 'Klausurwoche 2. Semester',
            details: '',
            professor: '',
            room: '',
            type: ScheduleEntryType.SpecialEvent,
          ),
          ScheduleEntry(
            start: DateTime(now.year, now.month, now.day + 1, 9),
            end: DateTime(now.year, now.month, now.day + 1, 10),
            title: 'Mathematics',
            details: '',
            professor: '',
            room: '',
            type: ScheduleEntryType.Class,
          ),
        ]),
        _FakeWorkSchedulerService(),
        _FakePreferencesProvider(),
        now: () => now,
      );

      await notification.run();

      expect(notificationApi.title, isNotEmpty);
      expect(notificationApi.message, contains('Mathematics'));
    },
  );

  test('run stays silent when only future marker events exist', () async {
    final now = DateTime(2026, 3, 8, 20);
    final notificationApi = _RecordingNotificationApi();
    final notification = NextDayInformationNotification(
      notificationApi,
      _FakeScheduleEntryRepository([
        ScheduleEntry(
          start: DateTime(now.year, now.month, now.day + 1, 7),
          end: DateTime(now.year, now.month, now.day + 1, 8),
          title: 'Beginn der 1. Theoriephase',
          details: '',
          professor: '',
          room: '',
          type: ScheduleEntryType.SpecialEvent,
        ),
      ]),
      _FakeWorkSchedulerService(),
      _FakePreferencesProvider(),
      now: () => now,
    );

    await notification.run();

    expect(notificationApi.title, isEmpty);
    expect(notificationApi.message, isEmpty);
  });

  test('run stays silent when only future public holidays exist', () async {
    final now = DateTime(2026, 4, 2, 20);
    final notificationApi = _RecordingNotificationApi();
    final notification = NextDayInformationNotification(
      notificationApi,
      _FakeScheduleEntryRepository([
        ScheduleEntry(
          start: DateTime(2026, 4, 3),
          end: DateTime(2026, 4, 4),
          title: 'Karfreitag',
          details: '',
          professor: '',
          room: '',
          type: ScheduleEntryType.PublicHoliday,
        ),
      ]),
      _FakeWorkSchedulerService(),
      _FakePreferencesProvider(),
      now: () => now,
    );

    await notification.run();

    expect(notificationApi.title, isEmpty);
    expect(notificationApi.message, isEmpty);
  });
}

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  Future<bool> getNotifyAboutNextDay() async => true;

  @override
  Future<String?> getLastUsedLanguageCode() async => 'en';

  @override
  // Test-only fallback for the many unused PreferencesProvider members.
  // Unexpected calls still fail through the default noSuchMethod behavior.
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
  final List<ScheduleEntry> entries;

  _FakeScheduleEntryRepository(this.entries);

  @override
  Future<Schedule> queryScheduleBetweenDates(
    DateTime start,
    DateTime end,
  ) async {
    final schedule = Schedule();
    schedule.entries.addAll(
      entries.where(
          (entry) => entry.end.isAfter(start) && entry.start.isBefore(end)),
    );
    return schedule;
  }

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
