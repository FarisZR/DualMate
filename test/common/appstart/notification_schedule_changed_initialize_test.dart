import 'dart:async';

import 'package:dualmate/common/appstart/app_visibility_tracker.dart';
import 'package:dualmate/common/appstart/notification_schedule_changed_initialize.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/schedule/business/schedule_diff_calculator.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/widgets.dart';
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
    final appVisibilityTracker = AppVisibilityTracker(
      initialState: AppLifecycleState.paused,
    );
    final container = KiwiContainer();

    container.registerInstance<ScheduleProvider>(scheduleProvider);
    container.registerInstance<PreferencesProvider>(preferencesProvider);
    container.registerInstance<NotificationApi>(notificationApi);
    container.registerInstance<AppVisibilityTracker>(appVisibilityTracker);

    NotificationScheduleChangedInitialize().setupNotification();

    final start = DateTime.now().add(const Duration(days: 1));
    await scheduleProvider.emitScheduleChanged(
      ScheduleDiff(
        addedEntries: [
          ScheduleEntry(
            start: start,
            end: start.add(const Duration(hours: 1)),
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

  test('schedule change notification waits for notification dispatch',
      () async {
    final scheduleProvider = _FakeScheduleProvider();
    final preferencesProvider = _FakePreferencesProvider();
    final notificationApi = _BlockingNotificationApi();
    final appVisibilityTracker = AppVisibilityTracker(
      initialState: AppLifecycleState.paused,
    );
    final container = KiwiContainer();

    container.registerInstance<ScheduleProvider>(scheduleProvider);
    container.registerInstance<PreferencesProvider>(preferencesProvider);
    container.registerInstance<NotificationApi>(notificationApi);
    container.registerInstance<AppVisibilityTracker>(appVisibilityTracker);

    NotificationScheduleChangedInitialize().setupNotification();

    var callbackCompleted = false;
    final start = DateTime.now().add(const Duration(days: 1));
    final callbackFuture = scheduleProvider
        .emitScheduleChanged(
          ScheduleDiff(
            addedEntries: [
              ScheduleEntry(
                start: start,
                end: start.add(const Duration(hours: 1)),
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
        )
        .then((_) => callbackCompleted = true);

    await Future<void>.delayed(Duration.zero);

    expect(notificationApi.callCount, 1);
    expect(callbackCompleted, isFalse);

    notificationApi.completePendingNotification();
    await callbackFuture;

    expect(callbackCompleted, isTrue);
  });

  test('schedule change notification suppresses far-future entries', () async {
    final scheduleProvider = _FakeScheduleProvider();
    final preferencesProvider = _FakePreferencesProvider();
    final notificationApi = _RecordingNotificationApi();
    final appVisibilityTracker = AppVisibilityTracker(
      initialState: AppLifecycleState.paused,
    );
    final container = KiwiContainer();

    container.registerInstance<ScheduleProvider>(scheduleProvider);
    container.registerInstance<PreferencesProvider>(preferencesProvider);
    container.registerInstance<NotificationApi>(notificationApi);
    container.registerInstance<AppVisibilityTracker>(appVisibilityTracker);

    NotificationScheduleChangedInitialize().setupNotification();

    final start = DateTime.now().add(const Duration(days: 30));
    await scheduleProvider.emitScheduleChanged(
      ScheduleDiff(
        addedEntries: [
          ScheduleEntry(
            start: start,
            end: start.add(const Duration(hours: 1)),
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

    expect(notificationApi.titles, isEmpty);
    expect(notificationApi.messages, isEmpty);
  });

  test('schedule change notification stays silent while app is attended',
      () async {
    final scheduleProvider = _FakeScheduleProvider();
    final preferencesProvider = _FakePreferencesProvider();
    final notificationApi = _RecordingNotificationApi();
    final appVisibilityTracker = AppVisibilityTracker(
      initialState: AppLifecycleState.resumed,
    );
    final container = KiwiContainer();

    container.registerInstance<ScheduleProvider>(scheduleProvider);
    container.registerInstance<PreferencesProvider>(preferencesProvider);
    container.registerInstance<NotificationApi>(notificationApi);
    container.registerInstance<AppVisibilityTracker>(appVisibilityTracker);

    NotificationScheduleChangedInitialize().setupNotification();

    final start = DateTime.now().add(const Duration(days: 1));
    await scheduleProvider.emitScheduleChanged(
      ScheduleDiff(
        addedEntries: [
          ScheduleEntry(
            start: start,
            end: start.add(const Duration(hours: 1)),
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

    expect(notificationApi.titles, isEmpty);
    expect(notificationApi.messages, isEmpty);
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

class _BlockingNotificationApi extends VoidNotificationApi {
  final Completer<void> _notificationCompleter = Completer<void>();
  int callCount = 0;

  @override
  Future<void> showNotification(String title, String message, [int? id]) {
    callCount++;
    return _notificationCompleter.future;
  }

  void completePendingNotification() {
    if (!_notificationCompleter.isCompleted) {
      _notificationCompleter.complete();
    }
  }
}
