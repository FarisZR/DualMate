import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/widgets/help_dialog.dart';
import 'package:flutter/material.dart';

class DualisHelpDialog extends HelpDialog {
  @override
  String content(BuildContext context) {
    return L.of(context).dualisHelpDialogContent;
  }

  @override
  String title(BuildContext context) {
    return L.of(context).dualisHelpDialogTitle;
  }
}
