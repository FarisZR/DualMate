import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/schedule/business/schedule_diff_calculator.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/notification/schedule_changed_notification.dart';
import 'package:test/test.dart';

void main() {
  final fixedNow = DateTime(2026, 3, 8, 12);

  test('notifies for an added class on day 14', () async {
    final notificationApi = _RecordingNotificationApi();
    final notification = _buildNotification(notificationApi, fixedNow);

    await notification.showNotification(
      ScheduleDiff(
        addedEntries: [
          _entryAt(DateTime(2026, 3, 22, 9), title: 'Algorithms'),
        ],
      ),
    );

    expect(notificationApi.titles, hasLength(1));
    expect(notificationApi.messages.single, contains('Algorithms'));
  });

  test('does not notify for an added class on day 15', () async {
    final notificationApi = _RecordingNotificationApi();
    final notification = _buildNotification(notificationApi, fixedNow);

    await notification.showNotification(
      ScheduleDiff(
        addedEntries: [
          _entryAt(DateTime(2026, 3, 23, 9), title: 'Algorithms'),
        ],
      ),
    );

    expect(notificationApi.titles, isEmpty);
  });

  test('does not notify for far-future removed classes', () async {
    final notificationApi = _RecordingNotificationApi();
    final notification = _buildNotification(notificationApi, fixedNow);

    await notification.showNotification(
      ScheduleDiff(
        removedEntries: [
          _entryAt(DateTime(2026, 4, 5, 11), title: 'Physics'),
        ],
      ),
    );

    expect(notificationApi.titles, isEmpty);
  });

  test('does not notify for far-future updated classes', () async {
    final notificationApi = _RecordingNotificationApi();
    final notification = _buildNotification(notificationApi, fixedNow);

    await notification.showNotification(
      ScheduleDiff(
        updatedEntries: [
          UpdatedEntry(
            _entryAt(DateTime(2026, 4, 2, 14), title: 'Databases'),
            ['start'],
          ),
        ],
      ),
    );

    expect(notificationApi.titles, isEmpty);
  });

  test('filters far-future entries before applying notification count limits',
      () async {
    final notificationApi = _RecordingNotificationApi();
    final notification = _buildNotification(notificationApi, fixedNow);

    await notification.showNotification(
      ScheduleDiff(
        addedEntries: [
          _entryAt(DateTime(2026, 3, 10, 9), title: 'Near term'),
          _entryAt(DateTime(2026, 4, 10, 9), title: 'Far 1'),
          _entryAt(DateTime(2026, 4, 11, 9), title: 'Far 2'),
          _entryAt(DateTime(2026, 4, 12, 9), title: 'Far 3'),
          _entryAt(DateTime(2026, 4, 13, 9), title: 'Far 4'),
        ],
      ),
    );

    expect(notificationApi.titles, hasLength(1));
    expect(notificationApi.messages.single, contains('Near term'));
  });
}

ScheduleChangedNotification _buildNotification(
  NotificationApi notificationApi,
  DateTime now,
) {
  return ScheduleChangedNotification(
    notificationApi,
    _FakePreferencesProvider(),
    now: () => now,
  );
}

ScheduleEntry _entryAt(DateTime start, {required String title}) {
  return ScheduleEntry(
    start: start,
    end: start.add(const Duration(hours: 1)),
    title: title,
    details: 'Lecture',
    professor: 'Prof',
    room: 'R1',
    type: ScheduleEntryType.Class,
  );
}

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  Future<String?> getLastUsedLanguageCode() async => 'en';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected PreferencesProvider call: $invocation');
  }
}

class _RecordingNotificationApi extends VoidNotificationApi {
  final List<String> titles = <String>[];
  final List<String> messages = <String>[];

  @override
  Future<void> showNotification(String title, String message, [int? id]) async {
    titles.add(title);
    messages.add(message);
  }
}
