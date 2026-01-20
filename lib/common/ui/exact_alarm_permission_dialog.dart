import 'package:dhbwstudentapp/common/i18n/localizations.dart';
import 'package:dhbwstudentapp/common/util/platform_util.dart';
import 'package:dhbwstudentapp/native/widget/widget_helper.dart';
import 'package:flutter/material.dart';

///
/// Dialog which requests permission to schedule exact alarms on Android 12+
///
class ExactAlarmPermissionDialog {
  final WidgetHelper _widgetHelper = WidgetHelper();

  Future<void> showIfNeeded(BuildContext context) async {
    if (!PlatformUtil.isAndroid()) return;

    var canSchedule = await _widgetHelper.canScheduleExactAlarms();
    if (canSchedule) return;

    await _showDialog(context);
  }

  Future<void> _showDialog(BuildContext context) async {
    return await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          buttonPadding: const EdgeInsets.all(0),
          actionsPadding: const EdgeInsets.all(0),
          contentPadding: const EdgeInsets.all(0),
          title: Text(L.of(context).exactAlarmPermissionTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(L.of(context).exactAlarmPermissionMessage),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: _buildButtonBar(context),
              )
            ],
          ),
        );
      },
    );
  }

  OverflowBar _buildButtonBar(BuildContext context) {
    return OverflowBar(
      spacing: 8,
      overflowSpacing: 8,
      children: <Widget>[
        TextButton(
          child: Text(L.of(context).exactAlarmPermissionLater.toUpperCase()),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text(L.of(context).exactAlarmPermissionAllow.toUpperCase()),
          onPressed: () async {
            await _widgetHelper.requestExactAlarmPermission();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
