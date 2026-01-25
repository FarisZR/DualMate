import 'package:dualmate/common/application_constants.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/util/platform_util.dart';
import 'package:flutter/material.dart';

///
/// Dialog which informs the user, that there is a widget for the home screen
///
class WidgetHelpDialog {
  final PreferencesProvider _preferencesProvider;
  final int _appLaunchCounter;

  WidgetHelpDialog(this._preferencesProvider, this._appLaunchCounter);

  Future<void> showIfNeeded(BuildContext context) async {
    if (!PlatformUtil.isAndroid()) return;
    if (await _preferencesProvider.getDidShowWidgetHelpDialog()) return;

    if (_appLaunchCounter >= WidgetHelpLaunchAfter) {
      await _preferencesProvider.setDidShowWidgetHelpDialog(true);
      await _showDialog(context);
    }
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
          title: Text(L.of(context).widgetHelpDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(L.of(context).widgetHelpDialogMessage)),
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
          child: Text(L.of(context).dialogOk.toUpperCase()),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
