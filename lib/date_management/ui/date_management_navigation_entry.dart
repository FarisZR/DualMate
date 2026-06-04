import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/features/local_calendar_feature.dart';
import 'package:dualmate/date_management/ui/calendar_export_page.dart';
import 'package:dualmate/date_management/ui/date_management_page.dart';
import 'package:dualmate/date_management/ui/viewmodels/date_management_view_model.dart';
import 'package:dualmate/date_management/ui/widgets/date_management_help_dialog.dart';
import 'package:dualmate/ui/navigation/navigation_entry.dart';
import 'package:dualmate/ui/navigation/navigator_key.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

class DateManagementNavigationEntry
    extends NavigationEntry<DateManagementViewModel> {
  DateManagementViewModel? _viewModel;

  @override
  Widget icon(BuildContext context) {
    return Icon(Icons.date_range);
  }

  @override
  String title(BuildContext context) {
    return L.of(context).pageDateManagementTitle;
  }

  @override
  DateManagementViewModel initViewModel() {
    _viewModel ??= DateManagementViewModel(
      KiwiContainer().resolve(),
      KiwiContainer().resolve(),
      KiwiContainer().resolve(),
    );
    return _viewModel!;
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    if (!isLocalCalendarFeatureEnabled) {
      return [
        IconButton(
          icon: Icon(Icons.help_outline),
          onPressed: () async {
            await DateManagementHelpDialog().show(context);
          },
          tooltip: L.of(context).helpButtonTooltip,
        ),
      ];
    }

    final model = viewModel();
    return [
      IconButton(
        icon: Icon(Icons.help_outline),
        onPressed: () async {
          await DateManagementHelpDialog().show(context);
        },
        tooltip: L.of(context).helpButtonTooltip,
      ),
      PropertyChangeProvider<DateManagementViewModel, String>(
        value: model,
        child: PropertyChangeConsumer<DateManagementViewModel, String>(
          builder:
              (
                BuildContext context,
                DateManagementViewModel? viewModel,
                Set<String>? properties,
              ) => viewModel == null
              ? Container()
              : PopupMenuButton<String>(
                  onSelected: (i) async {
                    await NavigatorKey.rootKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (BuildContext context) => CalendarExportPage(
                          entriesToExport: viewModel.exportEntries,
                        ),
                        settings: RouteSettings(name: "settings"),
                      ),
                    );
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem<String>(
                        value: "",
                        child: Text(
                          L.of(context).dateManagementExportToCalendar,
                        ),
                      ),
                    ];
                  },
                ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: DateManagementPage());
  }

  @override
  String get route => "date_management";
}
