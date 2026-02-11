import 'package:dualmate/common/ui/app_launch_dialogs.dart';
import 'package:dualmate/common/util/platform_util.dart';
import 'package:dualmate/ui/navigation/navigation_entry.dart';
import 'package:dualmate/ui/navigation/main_section_controller.dart';
import 'package:dualmate/ui/navigation/router.dart';
import 'package:dualmate/ui/navigation_drawer.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
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
  final ValueNotifier<int> _currentEntryIndex = ValueNotifier<int>(0);
  final Map<int, Widget> _sectionCache = {};
  final Set<int> _loadedSections = <int>{};

  NavigationEntry get currentEntry =>
      navigationEntries[_currentEntryIndex.value];

  @override
  void initState() {
    super.initState();
    _setCurrentEntryFromRoute(widget.initialRoute);
    _loadedSections.add(_currentEntryIndex.value);
    MainSectionController.instance.routeSignal
        .addListener(_handleExternalRouteRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleExternalRouteRequest();
    });
  }

  @override
  void dispose() {
    MainSectionController.instance.routeSignal
        .removeListener(_handleExternalRouteRequest);
    _currentEntryIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _showAppLaunchDialogsIfNeeded(context);

    return ChangeNotifierProvider.value(
      value: _currentEntryIndex,
      child: Consumer<ValueNotifier<int>>(
        builder: (BuildContext context, value, Widget? child) {
          final body = _buildSectionStack(context);
          Widget content;

          if (PlatformUtil.isTablet()) {
            content = buildTabletLayout(context, body);
          } else {
            content = buildPhoneLayout(context, body);
          }

          return content;
        },
      ),
    );
  }

  Widget _buildSectionStack(BuildContext context) {
    return IndexedStack(
      index: _currentEntryIndex.value,
      children: List.generate(
        navigationEntries.length,
        (index) => _buildSection(context, index),
      ),
    );
  }

  Widget _buildSection(BuildContext context, int index) {
    if (!_loadedSections.contains(index)) {
      return const SizedBox.shrink();
    }
    return _sectionCache.putIfAbsent(
      index,
      () => KeyedSubtree(
        key: ValueKey<String>("main_section_${navigationEntries[index].route}"),
        child: navigationEntries[index].buildRoute(context),
      ),
    );
  }

  Widget buildPhoneLayout(BuildContext context, Widget body) {
    return WillPopScope(
      onWillPop: () async {
        return true;
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
        body: body,
        drawer: MyNavigationDrawer(
          selectedIndex: _currentEntryIndex.value,
          onTap: _onNavigationTapped,
          entries: _buildDrawerEntries(),
        ),
      ),
    );
  }

  Widget buildTabletLayout(BuildContext context, Widget body) {
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
            child: body,
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
    PerformanceTelemetry.instance
        .markNavEvent(name: "drawer.tab.${navigationEntries[index].route}");
    _setCurrentEntryIndex(index);
  }

  void _setCurrentEntryFromRoute(String? route) {
    if (route == null) return;
    final targetIndex =
        navigationEntries.indexWhere((entry) => entry.route == route);
    if (targetIndex < 0) return;
    _setCurrentEntryIndex(targetIndex);
  }

  void _setCurrentEntryIndex(int index) {
    if (index < 0 || index >= navigationEntries.length) return;
    if (_loadedSections.add(index) && mounted) {
      setState(() {});
    }
    _currentEntryIndex.value = index;
  }

  void _handleExternalRouteRequest() {
    final route = MainSectionController.instance.consumePendingRoute();
    if (route == null) return;
    _setCurrentEntryFromRoute(route);
  }

  void _showAppLaunchDialogsIfNeeded(BuildContext context) {
    if (!_appLaunchDialogsShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          AppLaunchDialog(KiwiContainer().resolve())
              .showAppLaunchDialogs(context);
        });
      });

      _appLaunchDialogsShown = true;
    }
  }
}
