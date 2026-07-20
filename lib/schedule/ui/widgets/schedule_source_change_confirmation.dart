import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';

abstract final class ScheduleSourceChangeConfirmation {
  static Future<bool> confirmIfNeeded({
    required BuildContext context,
    required ScheduleSourceProvider sourceProvider,
    required ScheduleSourceType nextType,
    required String nextIdentityValue,
  }) async {
    final container = KiwiContainer();
    if (!sourceProvider.wouldChangeTo(nextType, nextIdentityValue) ||
        !container.isRegistered<ClassReminderController>()) {
      return true;
    }
    final reminders = container.resolve<ClassReminderController>();
    await reminders.initialize();
    if (!reminders.hasReminders) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L.of(dialogContext).classReminderSourceChangeTitle),
        content: Text(L.of(dialogContext).classReminderSourceChangeMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(L.of(dialogContext).classReminderSourceChangeCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(L.of(dialogContext).classReminderSourceChangeConfirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  static Future<void> finishCommittedChange({
    required ScheduleSourceProvider sourceProvider,
    required String previousSourceIdentity,
  }) async {
    if (previousSourceIdentity == sourceProvider.currentSourceIdentity) return;
    final container = KiwiContainer();
    if (!container.isRegistered<ClassReminderController>()) return;
    final reminders = container.resolve<ClassReminderController>();
    if (sourceProvider.currentSourceIdentity == 'none') {
      await reminders.clearForSourceChange(
        sourceIdentity: previousSourceIdentity,
      );
    } else {
      await reminders.waitForSourceChange();
    }
  }
}
