import 'package:dualmate/common/application_constants.dart';
import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/viewmodels/root_view_model.dart';
import 'package:dualmate/common/ui/widgets/title_list_tile.dart';
import 'package:dualmate/date_management/data/calendar_access.dart';
import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/ui/calendar_export_page.dart';
import 'package:dualmate/schedule/background/calendar_synchronizer.dart';
import 'package:dualmate/schedule/ui/notification/next_day_information_notification.dart';
import 'package:dualmate/schedule/ui/widgets/select_source_dialog.dart';
import 'package:dualmate/ui/navigation/navigator_key.dart';
import 'package:dualmate/ui/settings/select_theme_dialog.dart';
import 'package:dualmate/ui/settings/viewmodels/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:kiwi/kiwi.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:url_launcher/url_launcher.dart';

///
/// Widget for the application settings route. Provides access to many settings
/// of the app
///
class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsViewModel settingsViewModel = SettingsViewModel(
      KiwiContainer().resolve(),
      KiwiContainer().resolve<TaskCallback>(NextDayInformationNotification.name)
          as NextDayInformationNotification);

  @override
  Widget build(BuildContext context) {
    var widgets = <Widget>[];

    widgets.addAll(buildScheduleSourceSettings(context));
    widgets.addAll(buildDesignSettings(context));
    widgets.addAll(buildDeveloperSettings(context));
    widgets.addAll(buildNotificationSettings(context));
    widgets.addAll(buildAboutSettings(context));
    widgets.add(buildDisclaimer(context));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actionsIconTheme: Theme.of(context).iconTheme,
        elevation: 0,
        iconTheme: Theme.of(context).iconTheme,
        title: Text(L.of(context).settingsPageTitle),
        toolbarTextStyle: Theme.of(context).textTheme.bodyMedium,
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
      ),
      body: PropertyChangeProvider<SettingsViewModel, String>(
        value: settingsViewModel,
        child: ListView(
          children: widgets,
        ),
      ),
    );
  }

  Widget buildDisclaimer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        L.of(context).disclaimer,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  List<Widget> buildAboutSettings(BuildContext context) {
    return [
      TitleListTile(title: L.of(context).settingsAboutTitle),
      ListTile(
        title: Text(L.of(context).settingsAbout),
        onTap: () {
          showAboutDialog(
            context: context,
            applicationIcon: Image.asset(
              "assets/app_icon.png",
              width: 75,
            ),
            applicationLegalese: L.of(context).applicationLegalese,
            applicationName: L.of(context).applicationName,
            applicationVersion: ApplicationVersion,
          );
        },
      ),
      ListTile(
        title: Text(L.of(context).settingsViewSourceCode),
        onTap: () {
          launchUrl(Uri.parse(ApplicationSourceCodeUrl));
        },
      ),
      const Divider(),
    ];
  }

  List<Widget> buildScheduleSourceSettings(BuildContext context) {
    return [
      TitleListTile(title: L.of(context).settingsScheduleSourceTitle),
      ListTile(
        title: Text(L.of(context).settingsSetupScheduleSource),
        onTap: () async {
          await SelectSourceDialog(
            KiwiContainer().resolve(),
            KiwiContainer().resolve(),
          ).show(context);
        },
      ),
      PropertyChangeConsumer<SettingsViewModel, String>(
        properties: const [
          "useDhMineForDates",
        ],
        builder: (
          BuildContext context,
          SettingsViewModel? model,
          Set<String>? properties,
        ) {
          if (model == null) return Container();
          return SwitchListTile(
            title: Text(L.of(context).settingsUseDhMineDates),
            onChanged: model.setUseDhMineForDates,
            value: model.useDhMineForDates,
          );
        },
      ),
      PropertyChangeConsumer<SettingsViewModel, String>(
        properties: const [
          "prettifySchedule",
        ],
        builder: (
          BuildContext context,
          SettingsViewModel? model,
          Set<String>? properties,
        ) {
          if (model == null) return Container();
          return SwitchListTile(
            title: Text(L.of(context).settingsPrettifySchedule),
            onChanged: model.setPrettifySchedule,
            value: model.prettifySchedule,
          );
        },
      ),
      ListTile(
        title: Text(L.of(context).settingsCalendarSync),
        onTap: () async {
          if (await CalendarAccess().requestCalendarPermission() ==
              CalendarPermission.PermissionDenied) {
            await showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                      title: Text(
                          L.of(context).dialogTitleCalendarAccessNotGranted),
                      content:
                          Text(L.of(context).dialogCalendarAccessNotGranted),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(L.of(context).dialogOk),
                        )
                      ],
                    ));
            return;
          }
          var isCalendarSyncEnabled = await KiwiContainer()
              .resolve<PreferencesProvider>()
              .isCalendarSyncEnabled();
          List<DateEntry> entriesToExport =
              KiwiContainer().resolve<ListDateEntries30d>().listDateEntries;
          await NavigatorKey.rootKey.currentState?.push(MaterialPageRoute(
              builder: (BuildContext context) => CalendarExportPage(
                    entriesToExport: entriesToExport,
                    isCalendarSyncWidget: true,
                    isCalendarSyncEnabled: isCalendarSyncEnabled,
                  ),
              settings: RouteSettings(name: "settings")));
        },
      ),
      const Divider(),
    ];
  }

  List<Widget> buildNotificationSettings(BuildContext context) {
    WorkSchedulerService service = KiwiContainer().resolve();
    if (service.isSchedulingAvailable()) {
      return [
        TitleListTile(title: L.of(context).settingsNotificationsTitle),
        PropertyChangeConsumer<SettingsViewModel, String>(
          properties: const [
            "notifyAboutNextDay",
          ],
          builder: (
            BuildContext context,
            SettingsViewModel? model,
            Set<String>? properties,
          ) {
            if (model == null) return Container();
            return SwitchListTile(
              title: Text(L.of(context).settingsNotificationsNextDay),
              onChanged: model.setNotifyAboutNextDay,
              value: model.notifyAboutNextDay,
            );
          },
        ),
        PropertyChangeConsumer<SettingsViewModel, String>(
          properties: const [
            "notifyAboutScheduleChanges",
          ],
          builder: (
            BuildContext context,
            SettingsViewModel? model,
            Set<String>? properties,
          ) {
            if (model == null) return Container();
            return SwitchListTile(
              title: Text(L.of(context).settingsNotificationsScheduleChange),
              onChanged: model.setNotifyAboutScheduleChanges,
              value: model.notifyAboutScheduleChanges,
            );
          },
        ),
        const Divider(),
      ];
    } else {
      return [];
    }
  }

  List<Widget> buildDesignSettings(BuildContext context) {
    return [
      TitleListTile(title: L.of(context).settingsDesign),
      PropertyChangeConsumer<RootViewModel, String>(
        properties: const [
          "appTheme",
        ],
        builder: (
          BuildContext context,
          RootViewModel? model,
          Set<String>? properties,
        ) {
          if (model == null) return Container();
          return ListTile(
            title: Text(L.of(context).settingsDarkMode),
            onTap: () async {
              await SelectThemeDialog(model).show(context);
            },
            subtitle: Text({
                  AppTheme.Dark: L.of(context).selectThemeDark,
                  AppTheme.Light: L.of(context).selectThemeLight,
                  AppTheme.System: L.of(context).selectThemeSystem,
                }[model.appTheme] ??
                ""),
          );
        },
      ),
      const Divider(),
    ];
  }

  List<Widget> buildDeveloperSettings(BuildContext context) {
    if (!kDebugMode) return [];

    return [
      PropertyChangeConsumer<SettingsViewModel, String>(
        properties: const [
          "developerOptions",
          "showPerformanceOverlay",
        ],
        builder: (
          BuildContext context,
          SettingsViewModel? model,
          Set<String>? properties,
        ) {
          if (model == null || !model.isDeveloperOptionsEnabled) {
            return ListTile(
              title: Text(L.of(context).settingsDeveloperTitle),
              subtitle: Text(L.of(context).settingsDeveloperSubtitle),
              onTap: model?.incrementDeveloperTapCount,
            );
          }

          return Column(
            children: [
              TitleListTile(title: L.of(context).settingsDeveloperTitle),
              SwitchListTile(
                title: Text(L.of(context).settingsPerformanceOverlay),
                onChanged: model.setShowPerformanceOverlay,
                value: model.showPerformanceOverlay,
              ),
            ],
          );
        },
      ),
      const Divider(),
    ];
  }

  @override
  void dispose() {
    settingsViewModel.dispose();
    super.dispose();
  }
}
