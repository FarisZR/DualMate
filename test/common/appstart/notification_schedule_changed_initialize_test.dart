import 'package:dualmate/common/appstart/notification_schedule_changed_initialize.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/schedule/business/schedule_diff_calculator.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:kiwi/kiwi.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    KiwiContainer().clear();
  });

  tearDown(() {
    KiwiContainer().clear();
  });

  test('schedule change notification does not require localization in Kiwi',
      () async {
    final scheduleProvider = _FakeScheduleProvider();
    final preferencesProvider = _FakePreferencesProvider();
    final notificationApi = _RecordingNotificationApi();
    final container = KiwiContainer();

    container.registerInstance<ScheduleProvider>(scheduleProvider);
    container.registerInstance<PreferencesProvider>(preferencesProvider);
    container.registerInstance<NotificationApi>(notificationApi);

    NotificationScheduleChangedInitialize().setupNotification();

    await scheduleProvider.emitScheduleChanged(
      ScheduleDiff(
        addedEntries: [
          ScheduleEntry(
            start: DateTime(2026, 3, 9, 9),
            end: DateTime(2026, 3, 9, 10),
            title: 'Mathematics',
            details: 'Lecture',
            professor: 'Prof',
            room: 'R1',
            type: ScheduleEntryType.Class,
          ),
        ],
        removedEntries: const [],
        updatedEntries: const [],
      ),
    );

    expect(notificationApi.titles, isNotEmpty);
    expect(notificationApi.messages.single, contains('Mathematics'));
  });
}

class _FakeScheduleProvider implements ScheduleProvider {
  ScheduleEntryChangedCallback? _callback;

  @override
  void addScheduleEntryChangedCallback(ScheduleEntryChangedCallback callback) {
    _callback = callback;
  }

  Future<void> emitScheduleChanged(ScheduleDiff diff) async {
    await _callback?.call(diff);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  Future<bool> getNotifyAboutScheduleChanges() async => true;

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
