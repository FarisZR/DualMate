import 'package:dualmate/canteen/ui/viewmodels/canteen_view_model.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/widgets/help_dialog.dart';
import 'package:flutter/material.dart';

class CanteenHelpDialog extends HelpDialog {
  final CanteenViewModel _viewModel;

  CanteenHelpDialog(this._viewModel);

  @override
  String content(BuildContext context) {
    final location = _viewModel.selectedLocation;
    if (location.subtitle == null) {
      return L.of(context).canteenHelpDialogContent;
    }

    return '${L.of(context).canteenHelpDialogContent}\n\n${location.name} - ${location.subtitle}';
  }

  @override
  String title(BuildContext context) {
    return L.of(context).canteenHelpDialogTitle;
  }
}
