import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/viewmodels/root_view_model.dart';
import 'package:flutter/material.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

///
/// Shows a dialog to select dark/light or system theme as app theme
///
class SelectThemeDialog {
  final RootViewModel _rootViewModel;

  SelectThemeDialog(this._rootViewModel);

  Future show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: dialogBuilder,
    );
  }

  Widget dialogBuilder(BuildContext context) {
    return AlertDialog(
      title: Text(L.of(context).selectThemeDialogTitle),
      content: PropertyChangeProvider<RootViewModel, String>(
        value: _rootViewModel,
        child: PropertyChangeConsumer<RootViewModel, String>(
          properties: const [
            "appTheme",
          ],
          builder: (
            BuildContext context,
            RootViewModel? model,
            Set<String>? properties,
          ) {
            if (model == null) return Container();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<AppTheme>(
                  title: Text(L.of(context).selectThemeLight),
                  value: AppTheme.Light,
                  groupValue: _rootViewModel.appTheme,
                  onChanged: (v) {
                    if (v == null) return;
                    _rootViewModel.setAppTheme(v);
                  },
                ),
                RadioListTile<AppTheme>(
                  title: Text(L.of(context).selectThemeDark),
                  value: AppTheme.Dark,
                  groupValue: _rootViewModel.appTheme,
                  onChanged: (v) {
                    if (v == null) return;
                    _rootViewModel.setAppTheme(v);
                  },
                ),
                RadioListTile<AppTheme>(
                  title: Text(L.of(context).selectThemeSystem),
                  value: AppTheme.System,
                  groupValue: _rootViewModel.appTheme,
                  onChanged: (v) {
                    if (v == null) return;
                    _rootViewModel.setAppTheme(v);
                  },
                ),
              ],
            );
          },
        ),
      ),
      actions: [
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
