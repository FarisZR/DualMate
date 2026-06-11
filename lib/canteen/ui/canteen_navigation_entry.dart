import 'package:dualmate/canteen/ui/canteen_page.dart';
import 'package:dualmate/canteen/ui/viewmodels/canteen_view_model.dart';
import 'package:dualmate/canteen/ui/widgets/canteen_help_dialog.dart';
import 'package:dualmate/canteen/ui/widgets/select_canteen_location_dialog.dart';
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
      MenuAnchor(
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.restaurant_outlined),
            onPressed: () async {
              await SelectCanteenLocationDialog(
                _viewModel.locationService,
              ).show(context);
              await _viewModel.reloadSelectedLocation();
            },
            child: Text(L.of(context).settingsSetupCanteenLocation),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.help_outline),
            onPressed: () async {
              await CanteenHelpDialog(_viewModel).show(context);
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
