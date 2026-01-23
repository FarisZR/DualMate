import 'package:dhbwstudentapp/common/ui/app_launch_dialogs.dart';
import 'package:dhbwstudentapp/common/util/platform_util.dart';
import 'package:dhbwstudentapp/ui/navigation/navigation_entry.dart';
import 'package:dhbwstudentapp/ui/navigation/navigator_key.dart';
import 'package:dhbwstudentapp/ui/navigation/router.dart';
import 'package:dhbwstudentapp/ui/navigation_drawer.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';
import 'package:provider/provider.dart';

///
/// This is the main page widget. It defines the structure of the scaffold,
/// navigation drawer and provides a nested navigator for the content.
/// To navigate to a new route inside this widget use the [NavigatorKey.mainKey]
///
class MainPage extends StatefulWidget {
  final String? initialRoute;

  const MainPage({Key? key, this.initialRoute}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool _appLaunchDialogsShown = false;

  String? _initialRoute;
  bool _didApplyInitialRoute = false;

  final ValueNotifier<int> _currentEntryIndex = ValueNotifier<int>(0);

  NavigationEntry get currentEntry =>
      navigationEntries[_currentEntryIndex.value];

  @override
  void initState() {
    super.initState();

    _initialRoute = widget.initialRoute;

    _syncCurrentEntryIndex();
  }

  @override
  Widget build(BuildContext context) {
    _showAppLaunchDialogsIfNeeded(context);

    _syncCurrentEntryIndex();

    var navigator = Navigator(
      key: NavigatorKey.mainKey,
      onGenerateRoute: generateDrawerRoute,
      initialRoute: "schedule",
    );

    return ChangeNotifierProvider.value(
      value: _currentEntryIndex,
      child: Consumer<ValueNotifier<int>>(
        builder: (BuildContext context, value, Widget? child) {
          Widget content;

          if (PlatformUtil.isTablet()) {
            content = buildTabletLayout(context, navigator);
          } else {
            content = buildPhoneLayout(context, navigator);
          }

          return content;
        },
      ),
    );
  }

  Widget buildPhoneLayout(BuildContext context, Navigator navigator) {
    return WillPopScope(
      onWillPop: () async {
        var canPop = NavigatorKey.mainKey.currentState?.canPop() ?? false;

        if (!canPop) return true;

        NavigatorKey.mainKey.currentState?.pop();

        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          actionsIconTheme: Theme.of(context).iconTheme,
          elevation: 0,
          iconTheme: Theme.of(context).iconTheme,
          title: Text(currentEntry.title(context)),
          actions: currentEntry.appBarActions(context),
          toolbarTextStyle: Theme.of(context).textTheme.bodyMedium,
          titleTextStyle: Theme.of(context).textTheme.titleLarge,
        ),
        body: navigator,
        drawer: MyNavigationDrawer(
          selectedIndex: _currentEntryIndex.value,
          onTap: _onNavigationTapped,
          entries: _buildDrawerEntries(),
        ),
      ),
    );
  }

  Widget buildTabletLayout(BuildContext context, Navigator navigator) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actionsIconTheme: Theme.of(context).iconTheme,
        elevation: 0,
        iconTheme: Theme.of(context).iconTheme,
        title: Text(currentEntry.title(context)),
        actions: currentEntry.appBarActions(context),
        toolbarTextStyle: Theme.of(context).textTheme.bodyMedium,
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
      ),
      body: Row(
        children: [
          SizedBox(
            height: double.infinity,
            width: 250,
            child: MyNavigationDrawer(
              selectedIndex: _currentEntryIndex.value,
              onTap: _onNavigationTapped,
              entries: _buildDrawerEntries(),
              isInDrawer: false,
            ),
          ),
          Container(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          Expanded(
            child: navigator,
            flex: 3,
          ),
        ],
      ),
    );
  }

  List<DrawerNavigationEntry> _buildDrawerEntries() {
    var drawerEntries = <DrawerNavigationEntry>[];

    for (var entry in navigationEntries) {
      drawerEntries.add(DrawerNavigationEntry(
        entry.icon(context),
        entry.title(context),
      ));
    }

    return drawerEntries;
  }

  void _onNavigationTapped(int index) {
    _currentEntryIndex.value = index;

    NavigatorKey.mainKey.currentState
        ?.pushNamedAndRemoveUntil(currentEntry.route, (route) {
      return route.settings.name == navigationEntries[0].route;
    });
  }

  void _syncCurrentEntryIndex() {
    if (_initialRoute == null || _didApplyInitialRoute) return;

    var index = navigationEntries.indexWhere(
      (entry) => entry.route == _initialRoute,
    );
    if (index >= 0 && _currentEntryIndex.value != index) {
      _currentEntryIndex.value = index;
    }

    _didApplyInitialRoute = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialRoute == null) return;
      NavigatorKey.mainKey.currentState?.pushNamedAndRemoveUntil(_initialRoute!,
          (route) {
        return route.settings.name == navigationEntries[0].route;
      });
    });
  }

  void _showAppLaunchDialogsIfNeeded(BuildContext context) {
    if (!_appLaunchDialogsShown) {
      AppLaunchDialog(KiwiContainer().resolve()).showAppLaunchDialogs(context);

      _appLaunchDialogsShown = true;
    }
  }
}
