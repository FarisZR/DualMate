import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/schedule/business/schedule_diff_calculator.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/notification/schedule_changed_notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device runtime suppresses far-future schedule notifications', (
    tester,
  ) async {
    final notificationApi = _RecordingNotificationApi();
    final notification = ScheduleChangedNotification(
      notificationApi,
      _FakePreferencesProvider(),
      now: () => DateTime(2026, 3, 8, 12),
    );

    final farFutureStart = DateTime(2026, 4, 3, 9);
    await notification.showNotification(
      ScheduleDiff(
        addedEntries: [
          ScheduleEntry(
            start: farFutureStart,
            end: farFutureStart.add(const Duration(hours: 1)),
            title: 'Distributed Systems',
            details: 'Lecture',
            professor: 'Prof',
            room: 'R1',
            type: ScheduleEntryType.Class,
          ),
        ],
      ),
    );

    expect(notificationApi.titles, isEmpty);
    expect(notificationApi.messages, isEmpty);
  });

  testWidgets('device runtime keeps day-14 schedule notifications',
      (tester) async {
    final notificationApi = _RecordingNotificationApi();
    final notification = ScheduleChangedNotification(
      notificationApi,
      _FakePreferencesProvider(),
      now: () => DateTime(2026, 3, 8, 12),
    );

    final nearTermStart = DateTime(2026, 3, 22, 9);
    await notification.showNotification(
      ScheduleDiff(
        addedEntries: [
          ScheduleEntry(
            start: nearTermStart,
            end: nearTermStart.add(const Duration(hours: 1)),
            title: 'Distributed Systems',
            details: 'Lecture',
            professor: 'Prof',
            room: 'R1',
            type: ScheduleEntryType.Class,
          ),
        ],
      ),
    );

    expect(notificationApi.titles, hasLength(1));
    expect(notificationApi.messages.single, contains('Distributed Systems'));
  });
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
