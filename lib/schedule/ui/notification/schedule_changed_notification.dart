import 'dart:developer' as developer;
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
    try {
      final languageCode = await _preferencesProvider.getLastUsedLanguageCode();
      if (languageCode == null || languageCode.trim().isEmpty) {
        return L(const Locale('en'));
      }

      final normalized = languageCode.replaceAll('_', '-').trim();
      final segments = normalized.split('-');
      final primaryLanguage = segments.first;
      if (primaryLanguage.isEmpty) {
        return L(const Locale('en'));
      }

      final scriptCode =
          segments.length > 1 && segments[1].length == 4 ? segments[1] : null;
      final countryCode = segments.length > 2
          ? segments[2]
          : (segments.length > 1 && segments[1].length != 4
              ? segments[1]
              : null);

      return L(Locale.fromSubtags(
        languageCode: primaryLanguage,
        scriptCode: scriptCode,
        countryCode: countryCode,
      ));
    } catch (error, trace) {
      developer.log(
        'Failed to load schedule notification localization',
        name: 'schedule_changed_notification',
        error: error,
        stackTrace: trace,
      );
      return L(const Locale('en'));
    }
  }
}
