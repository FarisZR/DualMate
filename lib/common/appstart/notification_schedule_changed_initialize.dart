import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/schedule/business/schedule_diff_calculator.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/ui/notification/schedule_changed_notification.dart';
import 'package:kiwi/kiwi.dart';

///
/// Initializes the notification for when the schedule changed
///
class NotificationScheduleChangedInitialize {
  void setupNotification() {
    var provider = KiwiContainer().resolve<ScheduleProvider>();

    provider.addScheduleEntryChangedCallback(_scheduleChangedCallback);
  }

  Future<void> _scheduleChangedCallback(
      ScheduleDiff scheduleDiff, ScheduleRefreshOrigin origin) async {
    // Only notify for background periodic refreshes
    if (!origin.mayNotify) return;

    final preferences = KiwiContainer().resolve<PreferencesProvider>();
    var doNotify = await preferences.getNotifyAboutScheduleChanges();

    if (!doNotify) return;

    if (await preferences.getIsAppAttended()) return;

    var notification = ScheduleChangedNotification(
      KiwiContainer().resolve<NotificationApi>(),
      preferences,
    );
    await notification.showNotification(scheduleDiff);

    return Future.value();
  }
}