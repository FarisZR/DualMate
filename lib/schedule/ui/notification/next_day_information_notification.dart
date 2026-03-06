import 'dart:ui';

import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/common/util/string_utils.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:intl/intl.dart';

class NextDayInformationNotification extends TaskCallback {
  final PreferencesProvider _preferencesProvider;
  final NotificationApi _notificationApi;
  final ScheduleEntryRepository _scheduleEntryRepository;
  final WorkSchedulerService _scheduler;

  NextDayInformationNotification(
    this._notificationApi,
    this._scheduleEntryRepository,
    this._scheduler,
    this._preferencesProvider,
  );

  @override
  Future<void> run() async {
    await schedule();

    if (!await _preferencesProvider.getNotifyAboutNextDay()) {
      return;
    }

    var now = DateTime.now();

    var nextScheduleEntry =
        await _scheduleEntryRepository.queryNextScheduleEntry(now);
    if (nextScheduleEntry == null) {
      return;
    }

    var format = DateFormat.Hm();
    var daysToNextEntry = toStartOfDay(nextScheduleEntry.start)
        .difference(toStartOfDay(now))
        .inDays;

    if (daysToNextEntry > 1) return;

    final localization = await _loadLocalization();

    var message = _getNotificationMessage(
      daysToNextEntry,
      nextScheduleEntry,
      format,
      localization,
    );

    await _notificationApi.showNotification(
      localization.notificationNextClassTitle,
      message,
    );
  }

  String _getNotificationMessage(
    int daysToNextEntry,
    ScheduleEntry nextScheduleEntry,
    DateFormat format,
    L localization,
  ) {
    String message = "";
    if (daysToNextEntry == 0) {
      message = interpolate(
        localization.notificationNextClassNextClassAtMessage,
        [
          nextScheduleEntry.title,
          format.format(nextScheduleEntry.start),
        ],
      );
    } else if (daysToNextEntry == 1) {
      message = interpolate(
        localization.notificationNextClassTomorrow,
        [
          nextScheduleEntry.title,
          format.format(nextScheduleEntry.start),
        ],
      );
    }
    return message;
  }

  Future<L> _loadLocalization() async {
    final languageCode = await _preferencesProvider.getLastUsedLanguageCode();
    return L(Locale(languageCode ?? 'en'));
  }

  @override
  Future<void> schedule() async {
    var nextSchedule = toTimeOfDayInFuture(DateTime.now(), 20, 00);
    await _scheduler.scheduleOneShotTaskAt(
      nextSchedule,
      "NextDayInformationNotification" + DateFormat.yMd().format(nextSchedule),
      "NextDayInformationNotification",
    );
  }

  @override
  Future<void> cancel() async {
    var nextSchedule = toTimeOfDayInFuture(DateTime.now(), 20, 00);
    await _scheduler.cancelTask(
      "NextDayInformationNotification" + DateFormat.yMd().format(nextSchedule),
    );
  }

  @override
  String getName() {
    return name;
  }

  static String get name => "NextDayInformationNotification";
}
