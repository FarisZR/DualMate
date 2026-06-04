import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/ui/settings/viewmodels/settings_view_model.dart';
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
    'calendar sync toggle refresh uses a silent foreground maintenance origin',
    () async {
      final scheduleProvider = _TrackingScheduleProvider();
      KiwiContainer().registerInstance<ScheduleProvider>(scheduleProvider);
      final preferencesProvider = _FakePreferencesProvider();

      final viewModel = SettingsViewModel(
        preferencesProvider,
        CanteenLocationService(preferencesProvider),
        _FakeTaskCallback(),
        VoidNotificationApi(),
      );

      await Future<void>.delayed(Duration.zero);
      await viewModel.setIsCalendarSyncEnabled(true);

      expect(scheduleProvider.origins, [
        ScheduleRefreshOrigin.foregroundMaintenance,
      ]);
    },
  );
}

class _TrackingScheduleProvider implements ScheduleProvider {
  final List<ScheduleRefreshOrigin> origins = <ScheduleRefreshOrigin>[];

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    origins.add(origin);
    return ScheduleQueryResult(Schedule(), const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _FakeTaskCallback implements TaskCallback {
  @override
  Future<void> cancel() async {}

  @override
  String getName() => 'fake-task';

  @override
  Future<void> run() async {}

  @override
  Future<void> schedule() async {}
}

class _FakePreferencesProvider implements PreferencesProvider {
  bool _isCalendarSyncEnabled = false;
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<T?> get<T>(String key) async => _values[key] as T?;

  @override
  Future<bool> getNotifyAboutNextDay() async => false;

  @override
  Future<bool> getNotifyAboutScheduleChanges() async => false;

  @override
  Future<bool> getPrettifySchedule() async => false;

  @override
  Future<bool> getUseDhMineForDates() async => false;

  @override
  Future<String?> getSelectedCanteenLocationId() async => null;

  @override
  Future<void> setIsCalendarSyncEnabled(bool value) async {
    _isCalendarSyncEnabled = value;
  }

  @override
  Future<bool> isCalendarSyncEnabled() async => _isCalendarSyncEnabled;

  @override
  Future<void> set<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected PreferencesProvider call: $invocation');
  }
}
