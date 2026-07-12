import 'dart:async';

import 'package:dualmate/common/appstart/interaction_idle_coordinator.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/ui/app_launch_dialogs.dart';
import 'package:dualmate/common/util/platform_util.dart';
import 'package:dualmate/ui/navigation/main_section_controller.dart';
import 'package:dualmate/ui/navigation/navigation_entry.dart';
import 'package:dualmate/ui/navigation/router.dart';
import 'package:dualmate/ui/navigation_drawer.dart';
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
  final List<NavigationEntry>? entries;
  final InteractionIdleCoordinator? interactionCoordinator;

  const MainPage({
    Key? key,
    this.initialRoute,
    this.showAppLaunchDialogs = true,
    this.entries,
    this.interactionCoordinator,
  }) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static const Duration _drawerCloseNavigationDelay = Duration(
    milliseconds: 260,
  );
  static const Duration _initialSectionLoadDelay = Duration(milliseconds: 220);

  late final InteractionIdleCoordinator _interactionCoordinator;
  bool _appLaunchDialogsShown = false;
  int? _pendingDrawerNavigationIndex;
  Timer? _initialSectionLoadTimer;
  Timer? _pendingNavigationTimer;
  int _pendingNavigationGeneration = 0;
  int _activationGeneration = 0;
  final ValueNotifier<int> _currentEntryIndex = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isDrawerOpen = ValueNotifier<bool>(false);
  final Map<int, Widget> _sectionCache = <int, Widget>{};
  final Set<int> _loadedSections = <int>{};
  final Set<int> _preparedSections = <int>{};
  final Map<int, InteractionIdleTask> _preparationTasks =
      <int, InteractionIdleTask>{};
  final Map<int, InteractionLease> _pointerLeases = <int, InteractionLease>{};
  final Set<String> _activeScrollInteractions = <String>{};
  InteractionLease? _drawerAnimationLease;
  Timer? _drawerAnimationTimer;

  List<NavigationEntry> get _entries => widget.entries ?? navigationEntries;

  NavigationEntry get currentEntry => _entries[_currentEntryIndex.value];

  @override
  void initState() {
    super.initState();
    _interactionCoordinator =
        widget.interactionCoordinator ?? InteractionIdleCoordinator.instance;
    final initialIndex = _targetIndexForRoute(widget.initialRoute);
    if (initialIndex != null) {
      _currentEntryIndex.value = initialIndex;
    }
    MainSectionController.instance.routeSignal.addListener(
      _handleExternalRouteRequest,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initialSectionLoadTimer?.cancel();
      _initialSectionLoadTimer = Timer(_initialSectionLoadDelay, () {
        if (!mounted) return;
        _requestSectionActivation(_currentEntryIndex.value);
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
    _cancelPendingNavigation(clearPendingIndex: true);
    for (final task in _preparationTasks.values) {
      task.cancel();
    }
    for (final lease in _pointerLeases.values) {
      lease.release();
    }
    _pointerLeases.clear();
    for (final interactionId in _activeScrollInteractions) {
      _interactionCoordinator.endInteraction(interactionId);
    }
    _activeScrollInteractions.clear();
    _drawerAnimationTimer?.cancel();
    _drawerAnimationLease?.release();
    _drawerAnimationLease = null;
    _isDrawerOpen.dispose();
    _currentEntryIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _showAppLaunchDialogsIfNeeded();

    return ChangeNotifierProvider.value(
      value: _currentEntryIndex,
      child: Consumer<ValueNotifier<int>>(
        builder: (BuildContext context, value, Widget? child) {
          final body = _buildSectionStack(context);
          final drawerEntries = _buildDrawerEntries();
          if (PlatformUtil.isTablet()) {
            return buildTabletLayout(context, body, drawerEntries);
          }
          return buildPhoneLayout(context, body, drawerEntries);
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
        _entries.length,
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
        key: ValueKey<String>("main_section_${_entries[index].route}"),
        child: _entries[index].activate(context),
      ),
    );
  }

  Widget buildPhoneLayout(
    BuildContext context,
    Widget body,
    List<DrawerNavigationEntry> drawerEntries,
  ) {
    return Listener(
      onPointerDown: (event) {
        _pointerLeases[event.pointer] = _interactionCoordinator
            .beginInteraction('pointer.${event.pointer}');
      },
      onPointerUp: (event) => _pointerLeases.remove(event.pointer)?.release(),
      onPointerCancel: (event) =>
          _pointerLeases.remove(event.pointer)?.release(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: PopScope(
          canPop: true,
          child: Scaffold(
            onDrawerChanged: (isOpen) {
              if (_isDrawerOpen.value == isOpen) {
                return;
              }
              _isDrawerOpen.value = isOpen;
              _trackDrawerAnimation();
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
        ),
      ),
    );
  }

  Widget buildTabletLayout(
    BuildContext context,
    Widget body,
    List<DrawerNavigationEntry> drawerEntries,
  ) {
    return Listener(
      onPointerDown: (event) {
        _pointerLeases[event.pointer] = _interactionCoordinator
            .beginInteraction('pointer.${event.pointer}');
      },
      onPointerUp: (event) => _pointerLeases.remove(event.pointer)?.release(),
      onPointerCancel: (event) =>
          _pointerLeases.remove(event.pointer)?.release(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Scaffold(
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
        ),
      ),
    );
  }

  List<DrawerNavigationEntry> _buildDrawerEntries() {
    return <DrawerNavigationEntry>[
      for (final entry in _entries)
        DrawerNavigationEntry(
          entry.icon(context),
          entry.title(context),
          entry.route,
        ),
    ];
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final interactionId =
        'scroll.${identityHashCode(notification.context ?? notification.metrics)}';
    if (notification is ScrollStartNotification) {
      if (_activeScrollInteractions.add(interactionId)) {
        _interactionCoordinator.beginInteraction(interactionId);
      }
    } else if (notification is ScrollEndNotification) {
      if (_activeScrollInteractions.remove(interactionId)) {
        _interactionCoordinator.endInteraction(interactionId);
      }
    }
    return false;
  }

  void _trackDrawerAnimation() {
    _drawerAnimationTimer?.cancel();
    _drawerAnimationLease?.release();
    final lease = _interactionCoordinator.beginInteraction('drawer.animation');
    _drawerAnimationLease = lease;
    _drawerAnimationTimer = Timer(_drawerCloseNavigationDelay, () {
      lease.release();
      if (identical(_drawerAnimationLease, lease)) {
        _drawerAnimationLease = null;
      }
    });
  }

  void _onNavigationTapped(int index, bool fromDrawer) {
    if (index < 0 || index >= _entries.length) return;
    PerformanceTelemetry.instance.markNavEvent(
      name: "drawer.tab.${_entries[index].route}",
    );

    if (fromDrawer) {
      _cancelPendingNavigation();
      _pendingDrawerNavigationIndex = index;
      return;
    }

    _requestSectionActivation(index);
  }

  void _applyPendingDrawerNavigation() {
    final pendingIndex = _pendingDrawerNavigationIndex;
    _pendingDrawerNavigationIndex = null;
    if (pendingIndex == null || pendingIndex == _currentEntryIndex.value) {
      return;
    }

    _cancelPendingNavigation();
    final generation = _pendingNavigationGeneration;
    final preparation = _prepareSection(pendingIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _pendingNavigationGeneration) {
        return;
      }

      _pendingNavigationTimer = Timer(_drawerCloseNavigationDelay, () {
        if (!mounted || generation != _pendingNavigationGeneration) {
          return;
        }
        unawaited(
          _activateAfterPreparation(
            pendingIndex,
            preparation,
            ++_activationGeneration,
          ),
        );
      });
    });
  }

  void _setCurrentEntryFromRoute(String? route) {
    final targetIndex = _targetIndexForRoute(route);
    if (targetIndex == null) return;
    _requestSectionActivation(targetIndex);
  }

  int? _targetIndexForRoute(String? route) {
    if (route == null) return null;
    final targetIndex = _entries.indexWhere((entry) => entry.route == route);
    return targetIndex < 0 ? null : targetIndex;
  }

  void _requestSectionActivation(int index) {
    if (index < 0 || index >= _entries.length) return;
    _initialSectionLoadTimer?.cancel();
    _cancelPendingNavigation(clearPendingIndex: true);
    final generation = ++_activationGeneration;
    final preparation = _prepareSection(index);
    unawaited(_activateAfterPreparation(index, preparation, generation));
  }

  Future<void> _activateAfterPreparation(
    int index,
    Future<void> preparation,
    int generation,
  ) async {
    // Preparation is opportunistic. It may complete before activation, or it
    // may continue on the section-owned view model after the page is mounted.
    // Navigation must never wait on a network-backed preparation future.
    unawaited(preparation.catchError((_) {}));

    if (!mounted || generation != _activationGeneration) return;
    await _interactionCoordinator.waitForIdle();
    if (!mounted || generation != _activationGeneration) return;

    if (_loadedSections.add(index)) {
      setState(() {});
    }
    _currentEntryIndex.value = index;
  }

  Future<void> _prepareSection(int index) {
    if (_preparedSections.contains(index)) return Future<void>.value();
    final existing = _preparationTasks[index];
    if (existing != null) return existing.future;

    final entry = _entries[index];
    final task = _interactionCoordinator.schedule(
      'navigation.prepare.${identityHashCode(this)}.${entry.route}',
      () async {
        await entry.prepare();
        _preparedSections.add(index);
      },
    );
    _preparationTasks[index] = task;
    unawaited(
      task.future.then<void>(
        (_) {
          if (identical(_preparationTasks[index], task)) {
            _preparationTasks.remove(index);
          }
        },
        onError: (Object _, StackTrace __) {
          if (identical(_preparationTasks[index], task)) {
            _preparationTasks.remove(index);
          }
        },
      ),
    );
    return task.future;
  }

  void _cancelPendingNavigation({bool clearPendingIndex = false}) {
    _pendingNavigationGeneration += 1;
    _pendingNavigationTimer?.cancel();
    _pendingNavigationTimer = null;
    if (clearPendingIndex) {
      _pendingDrawerNavigationIndex = null;
    }
  }

  void _handleExternalRouteRequest() {
    final route = MainSectionController.instance.consumePendingRoute();
    if (route == null) return;
    _setCurrentEntryFromRoute(route);
  }

  void _showAppLaunchDialogsIfNeeded() {
    if (!widget.showAppLaunchDialogs || _appLaunchDialogsShown) return;
    _appLaunchDialogsShown = true;
    _interactionCoordinator.schedule('startup.appLaunchDialogs', () async {
      if (!mounted) return;
      await AppLaunchDialog(
        KiwiContainer().resolve(),
      ).showAppLaunchDialogs(context);
    }, delay: const Duration(milliseconds: 1200));
  }
}
