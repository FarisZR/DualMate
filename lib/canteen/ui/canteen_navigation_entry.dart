import 'package:dualmate/canteen/ui/canteen_page.dart';
import 'package:dualmate/canteen/ui/viewmodels/canteen_view_model.dart';
import 'package:dualmate/canteen/ui/widgets/canteen_help_dialog.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/ui/navigation/navigation_entry.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';

class CanteenNavigationEntry extends NavigationEntry<CanteenViewModel> {
  late CanteenViewModel _viewModel;

  @override
  Widget icon(BuildContext context) {
    return Icon(Icons.restaurant_menu);
  }

  @override
  CanteenViewModel initViewModel() {
    _viewModel = CanteenViewModel(
      KiwiContainer().resolve(),
    );
    return _viewModel;
  }

  @override
  String title(BuildContext context) {
    return L.of(context).screenCanteenTitle;
  }

  @override
  Widget build(BuildContext context) {
    return CanteenPage();
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.help_outline),
        onPressed: () async {
          await CanteenHelpDialog().show(context);
        },
        tooltip: L.of(context).helpButtonTooltip,
      ),
    ];
  }

  @override
  String get route => "canteen";
}
