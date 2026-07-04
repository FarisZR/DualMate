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
  static const Duration _initialSectionLoadDelay = Duration(milliseconds: 220);
  static const Duration _drawerPanelAnimationDuration = Duration(
    milliseconds: 120,
  );
  static const Curve _drawerPanelAnimationCurve = Curves.easeOutCubic;

  bool _appLaunchDialogsShown = false;
  Timer? _initialSectionLoadTimer;
  final ValueNotifier<int> _currentEntryIndex = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isDrawerOpen = ValueNotifier<bool>(false);
  late final PageController _sectionPageController;
  final Map<int, Widget> _sectionCache = {};
  final Set<int> _loadedSections = <int>{};
  bool _drawerPanelMounted = false;
  bool _drawerPanelOpen = false;

  NavigationEntry get currentEntry =>
      navigationEntries[_currentEntryIndex.value];

  @override
  void initState() {
    super.initState();
    final initialIndex = _targetIndexForRoute(widget.initialRoute);
    if (initialIndex != null) {
      _currentEntryIndex.value = initialIndex;
    }
    _sectionPageController = PageController(
      initialPage: _currentEntryIndex.value,
    );
    MainSectionController.instance.routeSignal.addListener(
      _handleExternalRouteRequest,
    );
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
    MainSectionController.instance.routeSignal.removeListener(
      _handleExternalRouteRequest,
    );
    _initialSectionLoadTimer?.cancel();
    _isDrawerOpen.dispose();
    _currentEntryIndex.dispose();
    _sectionPageController.dispose();
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
        child: SizedBox(
          key: ValueKey<String>('main_page_initial_placeholder'),
          width: 24,
          height: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x33000000),
            ),
          ),
        ),
      );
    }

    return PageView.builder(
      controller: _sectionPageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: navigationEntries.length,
      itemBuilder: (context, index) =>
          _KeepAliveSection(child: _buildSection(context, index)),
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
      canPop: !_drawerPanelOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _drawerPanelOpen) {
          _closeDrawerPanel();
        }
      },
      child: Stack(
        children: <Widget>[
          Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              actionsIconTheme: Theme.of(context).iconTheme,
              elevation: 0,
              iconTheme: Theme.of(context).iconTheme,
              leading: IconButton(
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                icon: const Icon(Icons.menu),
                onPressed: _openDrawerPanel,
              ),
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
          ),
          if (_drawerPanelMounted)
            _PhoneDrawerOverlay(
              selectedIndex: _currentEntryIndex.value,
              entries: drawerEntries,
              isOpen: _drawerPanelOpen,
              onClose: _closeDrawerPanel,
              onTap: _onNavigationTapped,
            ),
        ],
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
          Container(color: Theme.of(context).dividerColor, width: 1),
          Expanded(child: RepaintBoundary(child: body), flex: 3),
        ],
      ),
    );
  }

  List<DrawerNavigationEntry> _buildDrawerEntries() {
    var drawerEntries = <DrawerNavigationEntry>[];

    for (var entry in navigationEntries) {
      drawerEntries.add(
        DrawerNavigationEntry(
          entry.icon(context),
          entry.title(context),
          entry.route,
        ),
      );
    }

    return drawerEntries;
  }

  void _onNavigationTapped(int index, bool fromDrawer) {
    PerformanceTelemetry.instance.markNavEvent(
      name: "drawer.tab.${navigationEntries[index].route}",
    );

    if (fromDrawer) {
      _setCurrentEntryIndex(index);
      _closeDrawerPanel();
      return;
    }

    _setCurrentEntryIndex(index);
  }

  void _setCurrentEntryFromRoute(String? route) {
    final targetIndex = _targetIndexForRoute(route);
    if (targetIndex == null) return;
    _setCurrentEntryIndex(targetIndex);
  }

  int? _targetIndexForRoute(String? route) {
    if (route == null) return null;

    final targetIndex = navigationEntries.indexWhere(
      (entry) => entry.route == route,
    );
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
    _jumpToSection(index);
  }

  void _jumpToSection(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sectionPageController.hasClients) return;
      if ((_sectionPageController.page ?? index.toDouble()).round() == index) {
        return;
      }
      _sectionPageController.jumpToPage(index);
    });
  }

  void _openDrawerPanel() {
    if (_drawerPanelOpen) return;
    setState(() {
      _drawerPanelMounted = true;
      _drawerPanelOpen = true;
    });
    if (!_isDrawerOpen.value) {
      _isDrawerOpen.value = true;
    }
  }

  void _closeDrawerPanel() {
    if (!_drawerPanelMounted || !_drawerPanelOpen) return;
    setState(() {
      _drawerPanelOpen = false;
    });
    if (_isDrawerOpen.value) {
      _isDrawerOpen.value = false;
    }
  }

  void _unmountClosedDrawerPanel() {
    if (_drawerPanelOpen || !_drawerPanelMounted || !mounted) return;
    setState(() {
      _drawerPanelMounted = false;
    });
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
          AppLaunchDialog(
            KiwiContainer().resolve(),
          ).showAppLaunchDialogs(context);
        });
      });

      _appLaunchDialogsShown = true;
    }
  }
}

class _PhoneDrawerOverlay extends StatelessWidget {
  final int selectedIndex;
  final List<DrawerNavigationEntry> entries;
  final bool isOpen;
  final VoidCallback onClose;
  final NavigationItemOnTap onTap;

  const _PhoneDrawerOverlay({
    required this.selectedIndex,
    required this.entries,
    required this.isOpen,
    required this.onClose,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !isOpen,
        child: AnimatedOpacity(
          opacity: isOpen ? 1 : 0,
          duration: _MainPageState._drawerPanelAnimationDuration,
          curve: _MainPageState._drawerPanelAnimationCurve,
          onEnd: () {
            if (!isOpen) {
              final state = context.findAncestorStateOfType<_MainPageState>();
              state?._unmountClosedDrawerPanel();
            }
          },
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
              AnimatedSlide(
                offset: isOpen ? Offset.zero : const Offset(-1, 0),
                duration: _MainPageState._drawerPanelAnimationDuration,
                curve: _MainPageState._drawerPanelAnimationCurve,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RepaintBoundary(
                    child: MyNavigationDrawer(
                      selectedIndex: selectedIndex,
                      onTap: onTap,
                      entries: entries,
                      closeDrawer: onClose,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeepAliveSection extends StatefulWidget {
  final Widget child;

  const _KeepAliveSection({required this.child});

  @override
  State<_KeepAliveSection> createState() => _KeepAliveSectionState();
}

class _KeepAliveSectionState extends State<_KeepAliveSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
