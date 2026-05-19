import 'package:dualmate/common/i18n/localizations.dart';
import 'package:flutter/material.dart';

typedef NavigationItemOnTap = void Function(int index, bool fromDrawer);

///
/// This widget builds the content of the navigation drawer. It takes a list of
/// [DrawerNavigationEntry] and provides a onTap callback.
///
/// If the [isInDrawer] variable is true, it shows a header
///
class MyNavigationDrawer extends StatelessWidget {
  final int selectedIndex;
  final NavigationItemOnTap onTap;
  final List<DrawerNavigationEntry> entries;
  final bool isInDrawer;

  const MyNavigationDrawer({
    Key? key,
    required this.selectedIndex,
    required this.onTap,
    required this.entries,
    this.isInDrawer = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var widgets = <Widget>[];

    if (isInDrawer) {
      widgets.add(_createHeader(context));
    }

    int i = 0;
    for (var entry in entries) {
      widgets.add(_createDrawerItem(context,
          icon: entry.icon,
          text: entry.title,
          drawerKeyName: entry.keyName,
          index: i,
          isSelected: i == selectedIndex));

      i++;
    }

    widgets.add(_createSettingsItem(context));

    var widget = Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );

    if (isInDrawer) {
      return Drawer(
        child: widget,
      );
    }

    return widget;
  }

  Widget _createHeader(BuildContext context) {
    return DrawerHeader(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              L.of(context).applicationName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _createDrawerItem(
    BuildContext context, {
    required Widget icon,
    required String text,
    required String drawerKeyName,
    required bool isSelected,
    required int index,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Material(
        color: isSelected ? Theme.of(context).focusColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey<String>("drawer_item_$drawerKeyName"),
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            onTap(index, isInDrawer);

            if (isInDrawer) {
              Navigator.of(context).pop();
            }
          },
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  icon,
                  const SizedBox(width: 16),
                  Text(text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _createSettingsItem(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey<String>("drawer_settings"),
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (isInDrawer) {
                    Navigator.of(context).pop();
                  }

                  Navigator.pushNamed(context, "settings");
                },
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 15, 0, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.settings,
                          color: Theme.of(context).disabledColor,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                          child: Text(
                            L.of(context).settingsPageTitle,
                            style: TextStyle(
                              color: Theme.of(context).disabledColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DrawerNavigationEntry {
  final Widget icon;
  final String title;
  final String keyName;

  DrawerNavigationEntry(this.icon, this.title, this.keyName);
}
