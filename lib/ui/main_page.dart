import 'dart:async';

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
  final bool showAppLaunchDialogs;

  const MainPage({
    Key? key,
    this.initialRoute,
    this.showAppLaunchDialogs = true,
  }) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static const Duration _drawerCloseNavigationDelay =
      Duration(milliseconds: 260);
  static const Duration _initialSectionLoadDelay = Duration(milliseconds: 220);

  bool _appLaunchDialogsShown = false;
  int? _pendingDrawerNavigationIndex;
  Timer? _initialSectionLoadTimer;
  Timer? _pendingNavigationTimer;
  final ValueNotifier<int> _currentEntryIndex = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isDrawerOpen = ValueNotifier<bool>(false);
  final Map<int, Widget> _sectionCache = {};
  final Set<int> _loadedSections = <int>{};

  NavigationEntry get currentEntry =>
      navigationEntries[_currentEntryIndex.value];

  @override
  void initState() {
    super.initState();
    final initialIndex = _targetIndexForRoute(widget.initialRoute);
    if (initialIndex != null) {
      _currentEntryIndex.value = initialIndex;
    }
    MainSectionController.instance.routeSignal
        .addListener(_handleExternalRouteRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initialSectionLoadTimer?.cancel();
      _initialSectionLoadTimer = Timer(_initialSectionLoadDelay, () {
        if (!mounted) return;
        _ensureCurrentSectionLoaded();
      });
      _handleExternalRouteRequest();
    });
  }

  @override
  void dispose() {
    MainSectionController.instance.routeSignal
        .removeListener(_handleExternalRouteRequest);
    _initialSectionLoadTimer?.cancel();
    _pendingNavigationTimer?.cancel();
    _isDrawerOpen.dispose();
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
          final drawerEntries = _buildDrawerEntries();
          Widget content;

          if (PlatformUtil.isTablet()) {
            content = buildTabletLayout(context, body, drawerEntries);
          } else {
            content = buildPhoneLayout(context, body, drawerEntries);
          }

          return content;
        },
      ),
    );
  }

  Widget _buildSectionStack(BuildContext context) {
    if (!_loadedSections.contains(_currentEntryIndex.value)) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey<String>('main_page_initial_placeholder'),
        ),
      );
    }

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

  Widget buildPhoneLayout(
    BuildContext context,
    Widget body,
    List<DrawerNavigationEntry> drawerEntries,
  ) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        onDrawerChanged: (isOpen) {
          if (_isDrawerOpen.value == isOpen) {
            return;
          }
          _isDrawerOpen.value = isOpen;
          if (!isOpen) {
            _applyPendingDrawerNavigation();
          }
        },
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          actionsIconTheme: Theme.of(context).iconTheme,
          elevation: 0,
          iconTheme: Theme.of(context).iconTheme,
          title: Text(currentEntry.title(context)),
          actions: _loadedSections.contains(_currentEntryIndex.value)
              ? currentEntry.appBarActions(context)
              : const <Widget>[],
          toolbarTextStyle: Theme.of(context).textTheme.bodyMedium,
          titleTextStyle: Theme.of(context).textTheme.titleLarge,
        ),
        body: ValueListenableBuilder<bool>(
          valueListenable: _isDrawerOpen,
          child: body,
          builder: (context, isDrawerOpen, child) {
            return RepaintBoundary(
              child: TickerMode(
                enabled: !isDrawerOpen,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        ),
        drawer: RepaintBoundary(
          child: MyNavigationDrawer(
            selectedIndex: _currentEntryIndex.value,
            onTap: _onNavigationTapped,
            entries: drawerEntries,
          ),
        ),
      ),
    );
  }

  Widget buildTabletLayout(
    BuildContext context,
    Widget body,
    List<DrawerNavigationEntry> drawerEntries,
  ) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actionsIconTheme: Theme.of(context).iconTheme,
        elevation: 0,
        iconTheme: Theme.of(context).iconTheme,
        title: Text(currentEntry.title(context)),
        actions: _loadedSections.contains(_currentEntryIndex.value)
            ? currentEntry.appBarActions(context)
            : const <Widget>[],
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
              entries: drawerEntries,
              isInDrawer: false,
            ),
          ),
          Container(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          Expanded(
            child: RepaintBoundary(child: body),
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
        entry.route,
      ));
    }

    return drawerEntries;
  }

  void _onNavigationTapped(int index) {
    PerformanceTelemetry.instance
        .markNavEvent(name: "drawer.tab.${navigationEntries[index].route}");

    if (!PlatformUtil.isTablet() && _isDrawerOpen.value) {
      _pendingDrawerNavigationIndex = index;
      return;
    }

    _setCurrentEntryIndex(index);
  }

  void _applyPendingDrawerNavigation() {
    final pendingIndex = _pendingDrawerNavigationIndex;
    _pendingDrawerNavigationIndex = null;
    _pendingNavigationTimer?.cancel();
    if (pendingIndex == null || pendingIndex == _currentEntryIndex.value) {
      return;
    }

    _pendingNavigationTimer = Timer(_drawerCloseNavigationDelay, () {
      if (!mounted) return;
      _setCurrentEntryIndex(pendingIndex);
    });
  }

  void _setCurrentEntryFromRoute(String? route) {
    final targetIndex = _targetIndexForRoute(route);
    if (targetIndex == null) return;
    _setCurrentEntryIndex(targetIndex);
  }

  int? _targetIndexForRoute(String? route) {
    if (route == null) return null;

    final targetIndex =
        navigationEntries.indexWhere((entry) => entry.route == route);
    if (targetIndex < 0) {
      return null;
    }

    return targetIndex;
  }

  void _setCurrentEntryIndex(int index) {
    if (index < 0 || index >= navigationEntries.length) return;
    if (_loadedSections.add(index) && mounted) {
      setState(() {});
    }
    _currentEntryIndex.value = index;
  }

  void _ensureCurrentSectionLoaded() {
    if (_loadedSections.contains(_currentEntryIndex.value)) {
      return;
    }

    setState(() {
      _loadedSections.add(_currentEntryIndex.value);
    });
  }

  void _handleExternalRouteRequest() {
    final route = MainSectionController.instance.consumePendingRoute();
    if (route == null) return;
    _setCurrentEntryFromRoute(route);
  }

  void _showAppLaunchDialogsIfNeeded(BuildContext context) {
    if (!widget.showAppLaunchDialogs) {
      return;
    }

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
