import 'dart:ui';

import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/common/util/string_utils.dart';
import 'package:dualmate/schedule/business/schedule_diff_calculator.dart';
import 'package:intl/intl.dart';

class ScheduleChangedNotification {
  final NotificationApi notificationApi;
  final PreferencesProvider _preferencesProvider;

  ScheduleChangedNotification(this.notificationApi, this._preferencesProvider);

  Future<void> showNotification(ScheduleDiff scheduleDiff) async {
    final localization = await _loadLocalization();
    showEntriesAddedNotifications(scheduleDiff, localization);
    showEntriesRemovedNotifications(scheduleDiff, localization);
    showEntriesChangedNotifications(scheduleDiff, localization);
  }

  void showEntriesChangedNotifications(
    ScheduleDiff scheduleDiff,
    L localization,
  ) {
    if (scheduleDiff.updatedEntries.length > 4) {
      return;
    }

    for (var entry in scheduleDiff.updatedEntries) {
      var message = interpolate(
        localization.notificationScheduleChangedClass,
        [
          entry.entry.title,
          DateFormat.yMd().format(entry.entry.start),
        ],
      );

      notificationApi.showNotification(
        localization.notificationScheduleChangedClassTitle,
        message,
      );
    }
  }

  void showEntriesRemovedNotifications(
    ScheduleDiff scheduleDiff,
    L localization,
  ) {
    if (scheduleDiff.removedEntries.length > 4) {
      return;
    }

    for (var entry in scheduleDiff.removedEntries) {
      var message = interpolate(
        localization.notificationScheduleChangedRemovedClass,
        [
          entry.title,
          DateFormat.yMd().format(entry.start),
          DateFormat.Hm().format(entry.start)
        ],
      );

      notificationApi.showNotification(
        localization.notificationScheduleChangedRemovedClassTitle,
        message,
      );
    }
  }

  void showEntriesAddedNotifications(
    ScheduleDiff scheduleDiff,
    L localization,
  ) {
    if (scheduleDiff.addedEntries.length > 4) {
      return;
    }

    for (var entry in scheduleDiff.addedEntries) {
      var message = interpolate(
        localization.notificationScheduleChangedNewClass,
        [
          entry.title,
          DateFormat.yMd().format(entry.start),
          DateFormat.Hm().format(entry.start)
        ],
      );

      notificationApi.showNotification(
        localization.notificationScheduleChangedNewClassTitle,
        message,
      );
    }
  }

  Future<L> _loadLocalization() async {
    final languageCode = await _preferencesProvider.getLastUsedLanguageCode();
    return L(Locale(languageCode ?? 'en'));
  }
}
