import 'dart:developer' as developer;
import 'dart:ui';

import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/common/util/string_utils.dart';
import 'package:dualmate/schedule/business/schedule_diff_calculator.dart';
import 'package:intl/intl.dart';

class ScheduleChangedNotification {
  static const int _notificationHorizonDays = 14;

  final NotificationApi notificationApi;
  final PreferencesProvider _preferencesProvider;
  final DateTime Function() _now;

  ScheduleChangedNotification(
    this.notificationApi,
    this._preferencesProvider, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  Future<void> showNotification(ScheduleDiff scheduleDiff) async {
    final filteredDiff = _filterToNotificationWindow(scheduleDiff);
    if (!filteredDiff.didSomethingChange()) {
      return;
    }

    final localization = await _loadLocalization();
    await showEntriesAddedNotifications(filteredDiff, localization);
    await showEntriesRemovedNotifications(filteredDiff, localization);
    await showEntriesChangedNotifications(filteredDiff, localization);
  }

  ScheduleDiff _filterToNotificationWindow(ScheduleDiff scheduleDiff) {
    return ScheduleDiff(
      addedEntries: scheduleDiff.addedEntries
          .where((entry) => _isWithinNotificationWindow(entry.start))
          .toList(),
      removedEntries: scheduleDiff.removedEntries
          .where((entry) => _isWithinNotificationWindow(entry.start))
          .toList(),
      updatedEntries: scheduleDiff.updatedEntries
          .where((entry) => _isWithinNotificationWindow(entry.entry.start))
          .toList(),
    );
  }

  bool _isWithinNotificationWindow(DateTime start) {
    final today = toStartOfDay(_now());
    final cutoffExclusive = addDays(today, _notificationHorizonDays + 1);

    return !start.isBefore(today) && start.isBefore(cutoffExclusive);
  }

  Future<void> showEntriesChangedNotifications(
    ScheduleDiff scheduleDiff,
    L localization,
  ) async {
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

      await notificationApi.showNotification(
        localization.notificationScheduleChangedClassTitle,
        message,
      );
    }
  }

  Future<void> showEntriesRemovedNotifications(
    ScheduleDiff scheduleDiff,
    L localization,
  ) async {
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

      await notificationApi.showNotification(
        localization.notificationScheduleChangedRemovedClassTitle,
        message,
      );
    }
  }

  Future<void> showEntriesAddedNotifications(
    ScheduleDiff scheduleDiff,
    L localization,
  ) async {
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

      await notificationApi.showNotification(
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
