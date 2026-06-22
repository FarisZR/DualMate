import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/common/appstart/background_initialize.dart';
import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/native/widget/widget_helper.dart';
import 'package:dualmate/canteen/background/background_canteen_update.dart';
import 'package:dualmate/schedule/background/background_schedule_update.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/ui/notification/next_day_information_notification.dart';
import 'package:kiwi/kiwi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    KiwiContainer().clear();
  });

  tearDown(() {
    KiwiContainer().clear();
  });

  test(
    'setupBackgroundScheduling does not require localization in Kiwi',
    () async {
      final container = KiwiContainer();
      container.registerInstance<NotificationApi>(VoidNotificationApi());
      container.registerInstance<PreferencesProvider>(
        _FakePreferencesProvider(),
      );
      container.registerInstance<CanteenProvider>(_FakeCanteenProvider());
      container.registerInstance<ScheduleProvider>(_FakeScheduleProvider());
      container.registerInstance<ScheduleSourceProvider>(
        _FakeScheduleSourceProvider(),
      );
      container.registerInstance<ScheduleEntryRepository>(
        _FakeScheduleEntryRepository(),
      );
      container.registerInstance<WidgetHelper>(_FakeWidgetHelper());

      expect(
        container.isRegistered<TaskCallback>(
          name: NextDayInformationNotification.name,
        ),
        isFalse,
      );

      await BackgroundInitialize().setupBackgroundScheduling();

      expect(
        container.isRegistered<TaskCallback>(
          name: NextDayInformationNotification.name,
        ),
        isTrue,
      );
      expect(
        container.isRegistered<TaskCallback>(
          name: BackgroundCanteenUpdate.name,
        ),
        isTrue,
      );
      expect(
        container.isRegistered<TaskCallback>(
          name: BackgroundScheduleUpdate.name,
        ),
        isTrue,
      );
    },
  );

  test(
    'setupBackgroundScheduling registers all tasks before scheduling',
    () async {
      final container = KiwiContainer();
      container.registerInstance<NotificationApi>(VoidNotificationApi());
      container.registerInstance<PreferencesProvider>(
        _FakePreferencesProvider(),
      );
      container.registerInstance<CanteenProvider>(_FakeCanteenProvider());
      container.registerInstance<ScheduleProvider>(_FakeScheduleProvider());
      container.registerInstance<ScheduleSourceProvider>(
        _FakeScheduleSourceProvider(),
      );
      container.registerInstance<ScheduleEntryRepository>(
        _FakeScheduleEntryRepository(),
      );
      container.registerInstance<WidgetHelper>(_FakeWidgetHelper());

      await expectLater(
        BackgroundInitialize(
          schedulerFactory: () => _ThrowingScheduleWorkScheduler(),
        ).setupBackgroundScheduling(),
        throwsA(isA<StateError>()),
      );

      expect(
        container.isRegistered<TaskCallback>(
          name: NextDayInformationNotification.name,
        ),
        isTrue,
      );
      expect(
        container.isRegistered<TaskCallback>(
          name: BackgroundCanteenUpdate.name,
        ),
        isTrue,
      );
      expect(
        container.isRegistered<TaskCallback>(
          name: BackgroundScheduleUpdate.name,
        ),
        isTrue,
      );
    },
  );
}

class _ThrowingScheduleWorkScheduler implements WorkSchedulerService {
  @override
  Future<void> cancelTask(String id) async {}

  @override
  Future<void> executeTask(String id) async {}

  @override
  bool isSchedulingAvailable() => true;

  @override
  void registerTask(TaskCallback task) {}

  @override
  Future<void> scheduleOneShotTaskAt(
    DateTime date,
    String id,
    String name,
  ) async {
    throw StateError('scheduling failed');
  }

  @override
  Future<void> scheduleOneShotTaskIn(
    Duration delay,
    String id,
    String name,
  ) async {
    throw StateError('scheduling failed');
  }

  @override
  Future<void> schedulePeriodic(
    Duration delay,
    String id, [
    bool needsNetwork = false,
  ]) async {
    throw StateError('scheduling failed');
  }
}

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  Future<String?> getLastUsedLanguageCode() async => 'en';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCanteenProvider implements CanteenProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleProvider implements ScheduleProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleEntryRepository implements ScheduleEntryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWidgetHelper implements WidgetHelper {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
