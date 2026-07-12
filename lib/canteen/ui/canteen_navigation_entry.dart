import 'package:dualmate/canteen/ui/canteen_page.dart';
import 'package:dualmate/canteen/ui/viewmodels/canteen_view_model.dart';
import 'package:dualmate/canteen/ui/widgets/canteen_help_dialog.dart';
import 'package:dualmate/canteen/ui/widgets/select_canteen_location_dialog.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/ui/navigation/navigation_entry.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';

class CanteenNavigationEntry extends NavigationEntry<CanteenViewModel> {
  @override
  Widget icon(BuildContext context) {
    return Icon(Icons.restaurant_menu);
  }

  @override
  CanteenViewModel initViewModel() {
    return CanteenViewModel(
      KiwiContainer().resolve(),
      KiwiContainer().resolve(),
    );
  }

  @override
  Future<void> prepareSection() async {
    await viewModel().prepareForNavigation();
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
    final model = viewModel();
    return [
      MenuAnchor(
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.restaurant_outlined),
            onPressed: () async {
              await SelectCanteenLocationDialog(
                model.locationService,
              ).show(context);
              await model.reloadSelectedLocation();
            },
            child: Text(L.of(context).settingsSetupCanteenLocation),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.help_outline),
            onPressed: () async {
              await CanteenHelpDialog(model).show(context);
            },
            child: Text(L.of(context).helpButtonTooltip),
          ),
        ],
        builder: (context, controller, child) {
          return IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
          );
        },
      ),
    ];
  }

  @override
  String get route => "canteen";
}
