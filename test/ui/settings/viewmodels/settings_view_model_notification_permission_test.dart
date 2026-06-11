import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/ui/settings/viewmodels/settings_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enabling next-day notifications requests runtime permission', () async {
    final preferencesProvider = _FakePreferencesProvider();
    final task = _FakeTaskCallback();
    var permissionRequests = 0;
    final notificationApi = NotificationApi(
      runtimePermissionRequester: (_) async {
        permissionRequests++;
        return true;
      },
    );

    final viewModel = SettingsViewModel(
      preferencesProvider,
      CanteenLocationService(preferencesProvider),
      task,
      notificationApi,
    );

    await viewModel.setNotifyAboutNextDay(true);

    expect(permissionRequests, 1);
    expect(task.scheduleCalls, 1);
    expect(task.cancelCalls, 0);
    expect(viewModel.notifyAboutNextDay, isTrue);
  });

  test(
    'denied next-day notification permission keeps the toggle disabled',
    () async {
      final preferencesProvider = _FakePreferencesProvider();
      final task = _FakeTaskCallback();
      var permissionRequests = 0;
      final notificationApi = NotificationApi(
        runtimePermissionRequester: (_) async {
          permissionRequests++;
          return false;
        },
      );

      final viewModel = SettingsViewModel(
        preferencesProvider,
        CanteenLocationService(preferencesProvider),
        task,
        notificationApi,
      );

      await viewModel.setNotifyAboutNextDay(true);

      expect(permissionRequests, 1);
      expect(viewModel.notifyAboutNextDay, isFalse);
      expect(task.scheduleCalls, 0);
      expect(task.cancelCalls, 1);
    },
  );

  test(
    'schedule-change toggle only requests permission when enabling',
    () async {
      final preferencesProvider = _FakePreferencesProvider();
      final task = _FakeTaskCallback();
      var permissionRequests = 0;
      final notificationApi = NotificationApi(
        runtimePermissionRequester: (_) async {
          permissionRequests++;
          return true;
        },
      );

      final viewModel = SettingsViewModel(
        preferencesProvider,
        CanteenLocationService(preferencesProvider),
        task,
        notificationApi,
      );

      await viewModel.setNotifyAboutScheduleChanges(true);
      await viewModel.setNotifyAboutScheduleChanges(false);

      expect(permissionRequests, 1);
      expect(viewModel.notifyAboutScheduleChanges, isFalse);
    },
  );
}

class _FakeTaskCallback implements TaskCallback {
  int scheduleCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  String getName() {
    return 'fake-task';
  }

  @override
  Future<void> run() async {}

  @override
  Future<void> schedule() async {
    scheduleCalls++;
  }
}

class _FakePreferencesProvider extends PreferencesProvider {
  bool _notifyAboutNextDay = false;
  bool _notifyAboutScheduleChanges = false;
  bool _prettifySchedule = false;
  bool _useDhMineForDates = false;
  final Map<String, Object?> _values = <String, Object?>{};

  _FakePreferencesProvider()
    : super(_FakePreferencesAccess(), _FakeSecureStorageAccess());

  @override
  Future<T?> get<T>(String key) async {
    return _values[key] as T?;
  }

  @override
  Future<void> set<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<bool> getNotifyAboutNextDay() async {
    return _notifyAboutNextDay;
  }

  @override
  Future<void> setNotifyAboutNextDay(bool value) async {
    _notifyAboutNextDay = value;
  }

  @override
  Future<bool> getNotifyAboutScheduleChanges() async {
    return _notifyAboutScheduleChanges;
  }

  @override
  Future<void> setNotifyAboutScheduleChanges(bool value) async {
    _notifyAboutScheduleChanges = value;
  }

  @override
  Future<bool> getPrettifySchedule() async {
    return _prettifySchedule;
  }

  @override
  Future<void> setPrettifySchedule(bool value) async {
    _prettifySchedule = value;
  }

  @override
  Future<bool> getUseDhMineForDates() async {
    return _useDhMineForDates;
  }

  @override
  Future<void> setUseDhMineForDates(bool value) async {
    _useDhMineForDates = value;
  }

  @override
  Future<String?> getSelectedCanteenLocationId() async => null;
}

class _FakePreferencesAccess extends PreferencesAccess {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<T?> get<T>(String key) async {
    return _values[key] as T?;
  }

  @override
  Future<void> set<T>(String key, T value) async {
    _values[key] = value;
  }
}

class _FakeSecureStorageAccess extends SecureStorageAccess {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> get(String key) async {
    return _values[key];
  }

  @override
  Future<void> set(String key, String value) async {
    _values[key] = value;
  }
}
