import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/exact_alarm_permission_dialog.dart';
import 'package:dualmate/common/ui/rate_in_store_dialog.dart';
import 'package:dualmate/common/ui/widget_help_dialog.dart';
import 'package:flutter/material.dart';

bool shouldShowExactAlarmDialogForLaunchCount(int appLaunchCounter) {
  return false;
}

///
/// Helper class which manages the dialogs which are shown when the app is
/// launched
///
class AppLaunchDialog {
  final PreferencesProvider _preferencesProvider;

  AppLaunchDialog(this._preferencesProvider);

  Future<void> showAppLaunchDialogs(BuildContext context) async {
    final appLaunchCounter = await _preferencesProvider.getAppLaunchCounter();

    await _preferencesProvider.setAppLaunchCounter(appLaunchCounter + 1);

    await RateInStoreDialog(_preferencesProvider, appLaunchCounter)
        .showIfNeeded(context);

    await WidgetHelpDialog(_preferencesProvider, appLaunchCounter)
        .showIfNeeded(context);

    if (shouldShowExactAlarmDialogForLaunchCount(appLaunchCounter)) {
      await ExactAlarmPermissionDialog().showIfNeeded(context);
    }
  }
}
