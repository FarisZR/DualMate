import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/common/logging/perf_overlay_controller.dart';
import 'package:dualmate/schedule/ui/notification/next_day_information_notification.dart';
import 'package:kiwi/kiwi.dart';

import '../../../common/util/cancellation_token.dart';
import '../../../schedule/business/schedule_provider.dart';

///
/// The view model for the settings page.
///
class SettingsViewModel extends BaseViewModel {
  static const int developerTapThreshold = 6;

  final PreferencesProvider _preferencesProvider;
  final NextDayInformationNotification _nextDayInformationNotification;

  bool _notifyAboutNextDay = false;

  bool get notifyAboutNextDay => _notifyAboutNextDay;

  bool _notifyAboutScheduleChanges = false;

  bool get notifyAboutScheduleChanges => _notifyAboutScheduleChanges;

  bool _prettifySchedule = false;

  bool get prettifySchedule => _prettifySchedule;

  bool _useDhMineForDates = false;

  bool get useDhMineForDates => _useDhMineForDates;

  bool _isCalendarSyncEnabled = false;

  bool get isCalendarSyncEnabled => _isCalendarSyncEnabled;

  bool get showPerformanceOverlay => PerformanceOverlayController.enabled.value;

  bool _isDeveloperOptionsEnabled = false;

  bool get isDeveloperOptionsEnabled => _isDeveloperOptionsEnabled;

  int _developerTapCount = 0;

  SettingsViewModel(
    this._preferencesProvider,
    this._nextDayInformationNotification,
  ) {
    _loadPreferences();
  }

  void incrementDeveloperTapCount() {
    if (_isDeveloperOptionsEnabled) return;
    _developerTapCount += 1;
    if (_developerTapCount >= developerTapThreshold) {
      _isDeveloperOptionsEnabled = true;
      notifyIfMounted("developerOptions");
    }
  }

  Future<void> setIsCalendarSyncEnabled(bool value) async {
    _isCalendarSyncEnabled = value;

    notifyListeners("isCalendarSyncEnabled");

    await _preferencesProvider.setIsCalendarSyncEnabled(value);

    var scheduleProvider = KiwiContainer().resolve<ScheduleProvider>();
    scheduleProvider.getUpdatedSchedule(
      DateTime.now(),
      DateTime.now().add(Duration(days: 30)),
      CancellationToken(),
    );
  }

  Future<void> setNotifyAboutScheduleChanges(bool value) async {
    _notifyAboutScheduleChanges = value;

    notifyIfMounted("notifyAboutScheduleChanges");

    await _preferencesProvider.setNotifyAboutScheduleChanges(value);
  }

  Future<void> setPrettifySchedule(bool value) async {
    _prettifySchedule = value;

    notifyIfMounted("prettifySchedule");

    await _preferencesProvider.setPrettifySchedule(value);
  }

  Future<void> setNotifyAboutNextDay(bool value) async {
    _notifyAboutNextDay = value;

    notifyIfMounted("notifyAboutNextDay");

    await _preferencesProvider.setNotifyAboutNextDay(value);

    if (value)
      await _nextDayInformationNotification.schedule();
    else
      await _nextDayInformationNotification.cancel();
  }

  Future<void> setUseDhMineForDates(bool value) async {
    _useDhMineForDates = value;

    notifyIfMounted("useDhMineForDates");

    await _preferencesProvider.setUseDhMineForDates(value);
  }

  Future<void> _loadPreferences() async {
    _notifyAboutNextDay = await _preferencesProvider.getNotifyAboutNextDay();
    _notifyAboutScheduleChanges =
        await _preferencesProvider.getNotifyAboutScheduleChanges();

    _prettifySchedule = await _preferencesProvider.getPrettifySchedule();
    _useDhMineForDates = await _preferencesProvider.getUseDhMineForDates();
    await PerformanceOverlayController.load(_preferencesProvider);
    notifyIfMounted("notifyAboutNextDay");
    notifyIfMounted("notifyAboutScheduleChanges");
    notifyIfMounted("prettifySchedule");
    notifyIfMounted("useDhMineForDates");
    notifyIfMounted("showPerformanceOverlay");
  }

  Future<void> setShowPerformanceOverlay(bool value) async {
    await PerformanceOverlayController.setEnabled(_preferencesProvider, value);
    notifyIfMounted("showPerformanceOverlay");
  }
}
