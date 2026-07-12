import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/model/canteen_filter.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/appstart/performance_fixture_mode.dart';
import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/canteen/ui/viewmodels/canteen_render_state.dart';
import 'dart:async';

import 'package:flutter/widgets.dart';

class CanteenViewModel extends BaseViewModel {
  static const String weekStateProperty = 'weekState';
  static const Duration defaultStaleAfter = Duration(hours: 2);
  static const Duration _adjacentPrefetchDebounceDelay = Duration(
    milliseconds: 250,
  );

  final CanteenProvider _provider;
  final CanteenLocationService _locationService;

  final DateTime todayWeekStart;
  CanteenFilter filter = CanteenFilter.all;

  final Map<DateTime, CanteenWeekRenderState> _weeklyRenderStates = {};
  final Map<DateTime, int> _loadingWeeks = {};
  final Map<DateTime, DateTime> _weekLastRefreshRequestAt = {};
  final Map<DateTime, Map<CanteenFilter, List<Meal>>> _filteredMealsCache = {};
  bool _initialized = false;
  Timer? _adjacentPrefetchDebounceTimer;
  DateTime? _lastAdjacentPrefetchCenterWeekStart;
  List<DateTime> _visibleContentDaysCache = const <DateTime>[];
  final Set<DateTime> _visibleContentDaySet = <DateTime>{};
  CanteenLocation _selectedLocation = CanteenLocations.defaultLocation;
  int _locationGeneration = 0;
  CanteenMenuUpdatedCallback? _menuUpdatedCallback;
  StreamSubscription<CanteenLocation>? _locationChangeSubscription;

  CanteenLocation get selectedLocation => _selectedLocation;
  CanteenLocationService get locationService => _locationService;

  CanteenViewModel(this._provider, this._locationService)
    : todayWeekStart = toStartOfDay(toMonday(DateTime.now()));

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _registerMenuUpdatedCallback();
    _locationChangeSubscription = _locationService.selectedLocationChanges
        .listen((_) {
          unawaited(
            reloadSelectedLocation(
              allowNetworkRefresh: !isPerformanceFixtureMode,
            ),
          );
        });
    if (isPerformanceFixtureMode) {
      unawaited(_loadPerformanceFixtureData());
      return;
    }

    unawaited(_loadSelectedLocation());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_weeklyRenderStates.containsKey(todayWeekStart)) return;
      primeVisibleWeek(todayWeekStart);
    });
  }

  Future<void> _loadPerformanceFixtureData() async {
    await _loadSelectedLocation();
    await _loadFixtureWeeks();
  }

  Future<void> _loadFixtureWeeks() async {
    await Future.wait(<Future<void>>[
      loadWeek(
        todayWeekStart.subtract(const Duration(days: 7)),
        allowNetworkRefresh: false,
        prefetchNextWeek: false,
      ),
      loadWeek(
        todayWeekStart,
        allowNetworkRefresh: false,
        prefetchNextWeek: false,
      ),
      loadWeek(
        todayWeekStart.add(const Duration(days: 7)),
        allowNetworkRefresh: false,
        prefetchNextWeek: false,
      ),
    ]);
  }

  List<DailyMenu> weeklyMenusFor(DateTime weekStart) {
    return _weeklyRenderStates[weekStart]?.menus ?? const <DailyMenu>[];
  }

  bool hasWeekData(DateTime weekStart) {
    return _weeklyRenderStates.containsKey(weekStart);
  }

  bool isLoadingWeek(DateTime weekStart) {
    return _weeklyRenderStates[weekStart]?.isLoading ?? false;
  }

  String? errorForWeek(DateTime weekStart) {
    return _weeklyRenderStates[weekStart]?.error;
  }

  DateTime? lastUpdatedForWeek(DateTime weekStart) {
    return _weeklyRenderStates[weekStart]?.lastUpdated;
  }

  DateTime weekStartFor(DateTime date) {
    return toStartOfDay(toMonday(date));
  }

  List<Meal> mealsForDay(DateTime weekStart, DateTime date) {
    final normalizedDate = toStartOfDay(date);
    final day = _weeklyRenderStates[weekStart]?.dayFor(normalizedDate);
    if (day == null) return const <Meal>[];

    final mealsByFilter = _filteredMealsCache.putIfAbsent(
      normalizedDate,
      () => <CanteenFilter, List<Meal>>{},
    );
    return mealsByFilter.putIfAbsent(
      filter,
      () => List<Meal>.unmodifiable(day.meals.where(filter.allowsMeal)),
    );
  }

  CanteenDayRenderState dayRenderStateFor(DateTime date) {
    final weekStart = weekStartFor(date);
    return _weeklyRenderStates[weekStart]?.dayFor(date) ??
        CanteenDayRenderState.empty(date);
  }

  CanteenDayContentState dayContentStateFor(DateTime date) {
    return CanteenDayContentState(
      day: dayRenderStateFor(date),
      filter: filter,
      meals: mealsForDay(weekStartFor(date), date),
    );
  }

  List<DateTime> contentDaysForWeek(DateTime weekStart) {
    return _weeklyRenderStates[weekStart]?.contentDays ?? const <DateTime>[];
  }

  List<Meal> mealsForDate(DateTime date) {
    return mealsForDay(weekStartFor(date), date);
  }

  List<DateTime> get visibleContentDays {
    return _visibleContentDaysCache;
  }

  DateTime? nearestVisibleContentDay(
    DateTime targetDate, {
    List<DateTime>? precomputedDays,
  }) {
    final visibleDays = precomputedDays ?? visibleContentDays;
    if (visibleDays.isEmpty) return null;

    final normalizedTarget = toStartOfDay(targetDate);
    var nearest = visibleDays.first;
    var minDistance = nearest.difference(normalizedTarget).inDays.abs();

    for (final day in visibleDays.skip(1)) {
      final distance = day.difference(normalizedTarget).inDays.abs();
      if (distance < minDistance) {
        nearest = day;
        minDistance = distance;
      }
    }

    return nearest;
  }

  Future<void> loadWeek(
    DateTime weekStart, {
    bool forceRefresh = false,
    bool allowNetworkRefresh = true,
    bool prefetchNextWeek = true,
    Duration staleAfter = defaultStaleAfter,
  }) async {
    if (_loadingWeeks.containsKey(weekStart)) return;

    await PerformanceTelemetry.instance.measureTask(
      'canteen.open',
      args: {'isForcedRefresh': forceRefresh, 'sourceType': 'unknown'},
      action: (_) async {
        final requestGeneration = _locationGeneration;
        final hadWeekDataBeforeLoad = _weeklyRenderStates.containsKey(
          weekStart,
        );
        final hadContentBeforeLoad = _hasWeekContent(weekStart);
        _loadingWeeks[weekStart] = requestGeneration;
        _setWeekLoading(weekStart, isLoading: true);
        if (!hadContentBeforeLoad) {
          notifyIfMounted(weekStateProperty);
        }

        try {
          final shouldReloadFromDatabase =
              forceRefresh || !hadWeekDataBeforeLoad;

          if (shouldReloadFromDatabase) {
            final cachedMenusFuture = PerformanceTelemetry.instance.measureTask(
              'canteen.cache.read',
              args: {'sourceType': 'unknown'},
              action: (task) async {
                final menus = await _provider.getCachedWeek(weekStart);
                task.setData('cachedEntryCount', menus.length);
                return menus;
              },
            );
            final lastUpdatedFuture = _provider.lastUpdatedForWeek(weekStart);

            var cachedMenus = await cachedMenusFuture;
            if (!_isCurrentLocationRequest(requestGeneration)) return;
            _applyMenusForWeek(weekStart, cachedMenus);
            var lastUpdated = await lastUpdatedFuture;
            if (!_isCurrentLocationRequest(requestGeneration)) return;
            if (lastUpdated != null) {
              _setWeekState(
                weekStart,
                _weeklyRenderStates[weekStart]!.copyWith(
                  lastUpdated: lastUpdated,
                ),
              );
            }
          }

          if (allowNetworkRefresh) {
            _weekLastRefreshRequestAt[weekStart] = DateTime.now();
            try {
              final menus = await PerformanceTelemetry.instance.measureTask(
                'canteen.remote.fetch',
                args: {
                  'isForcedRefresh': forceRefresh,
                  'sourceType': 'unknown',
                },
                successStatusForResult: (menus) =>
                    menus.isEmpty ? 'empty' : 'success',
                action: (task) async {
                  final loadedMenus = forceRefresh
                      ? await _provider.refreshWeek(weekStart)
                      : await _provider.refreshWeekIfStale(
                          weekStart,
                          staleAfter: staleAfter,
                          prefetchNextWeek: prefetchNextWeek,
                        );
                  task.setData('loadedEntryCount', loadedMenus.length);
                  return loadedMenus;
                },
              );
              if (!_isCurrentLocationRequest(requestGeneration)) return;
              _applyMenusForWeek(weekStart, menus);
              _setWeekState(
                weekStart,
                _weeklyRenderStates[weekStart]!.copyWith(
                  error: null,
                  lastUpdated: DateTime.now(),
                ),
              );
            } catch (exception) {
              if (!_isCurrentLocationRequest(requestGeneration)) return;
              // keep cached data visible
              final current =
                  _weeklyRenderStates[weekStart] ??
                  CanteenWeekRenderState.empty(weekStart);
              _setWeekState(
                weekStart,
                current.copyWith(error: exception.toString()),
              );
            }
          }
        } finally {
          if (_loadingWeeks[weekStart] == requestGeneration) {
            _loadingWeeks.remove(weekStart);
            _setWeekLoading(weekStart, isLoading: false);
            notifyIfMounted(weekStateProperty);
          }
        }
      },
    );
  }

  void ensureWeekLoaded(
    DateTime weekStart, {
    bool allowNetworkRefresh = true,
    bool prefetchNextWeek = true,
    Duration staleAfter = defaultStaleAfter,
  }) {
    if (_weeklyRenderStates.containsKey(weekStart) ||
        _loadingWeeks.containsKey(weekStart)) {
      return;
    }

    unawaited(
      loadWeek(
        weekStart,
        allowNetworkRefresh: allowNetworkRefresh,
        prefetchNextWeek: prefetchNextWeek,
        staleAfter: staleAfter,
      ),
    );
  }

  void primeVisibleWeek(DateTime day) {
    final weekStart = weekStartFor(day);
    if (hasWeekData(weekStart)) {
      refreshVisibleWeekIfStale(day);
      return;
    }
    ensureWeekLoaded(
      weekStart,
      allowNetworkRefresh: !isPerformanceFixtureMode,
      prefetchNextWeek: false,
    );
  }

  void refreshVisibleWeekIfStale(
    DateTime day, {
    Duration staleAfter = defaultStaleAfter,
  }) {
    final weekStart = weekStartFor(day);
    if (_loadingWeeks.containsKey(weekStart)) return;
    final lastRefreshRequestAt = _weekLastRefreshRequestAt[weekStart];
    if (lastRefreshRequestAt != null &&
        DateTime.now().difference(lastRefreshRequestAt) < staleAfter) {
      return;
    }
    unawaited(
      loadWeek(
        weekStart,
        allowNetworkRefresh: !isPerformanceFixtureMode,
        prefetchNextWeek: false,
        staleAfter: staleAfter,
      ),
    );
  }

  void prefetchAdjacentWeeksDebounced(DateTime centerDay) {
    final centerWeekStart = weekStartFor(centerDay);
    if (_lastAdjacentPrefetchCenterWeekStart == centerWeekStart) {
      return;
    }
    _lastAdjacentPrefetchCenterWeekStart = centerWeekStart;

    _adjacentPrefetchDebounceTimer?.cancel();
    _adjacentPrefetchDebounceTimer = Timer(_adjacentPrefetchDebounceDelay, () {
      if (isDisposed) return;
      _prefetchAdjacentWeeks(centerWeekStart);
    });
  }

  void prefetchAdjacentWeeks(DateTime centerDay) {
    final centerWeekStart = weekStartFor(centerDay);
    if (_lastAdjacentPrefetchCenterWeekStart == centerWeekStart) {
      return;
    }
    _lastAdjacentPrefetchCenterWeekStart = centerWeekStart;
    _prefetchAdjacentWeeks(centerWeekStart);
  }

  void _prefetchAdjacentWeeks(DateTime centerWeekStart) {
    final previousWeekStart = centerWeekStart.subtract(const Duration(days: 7));
    final nextWeekStart = centerWeekStart.add(const Duration(days: 7));
    ensureWeekLoaded(
      previousWeekStart,
      allowNetworkRefresh: false,
      prefetchNextWeek: false,
    );
    if (_loadingWeeks.containsKey(nextWeekStart)) {
      return;
    }
    unawaited(
      loadWeek(
        nextWeekStart,
        allowNetworkRefresh: !isPerformanceFixtureMode,
        prefetchNextWeek: false,
      ),
    );
  }

  void setFilter(CanteenFilter nextFilter) {
    if (filter == nextFilter) return;
    filter = nextFilter;
    notifyIfMounted("filter");
  }

  Future<void> reloadSelectedLocation({bool allowNetworkRefresh = true}) async {
    await _loadSelectedLocation(
      reloadWeek: true,
      allowNetworkRefresh: allowNetworkRefresh,
    );
  }

  Future<void> _onMenusUpdated(
    int requestGeneration,
    List<DailyMenu> menus,
    DateTime start,
    DateTime end,
  ) async {
    if (!_isCurrentLocationRequest(requestGeneration)) return;
    var weekStart = toStartOfDay(toMonday(start));
    _applyMenusForWeek(weekStart, menus);
    final current = _weeklyRenderStates[weekStart];
    if (current == null) return;
    _setWeekState(weekStart, current.copyWith(lastUpdated: DateTime.now()));
    if (!_loadingWeeks.containsKey(weekStart)) {
      notifyIfMounted(weekStateProperty);
    }
  }

  void _registerMenuUpdatedCallback() {
    final previousCallback = _menuUpdatedCallback;
    if (previousCallback != null) {
      _provider.removeMenuUpdatedCallback(previousCallback);
    }

    final callbackGeneration = _locationGeneration;
    _menuUpdatedCallback =
        (List<DailyMenu> menus, DateTime start, DateTime end) {
          return _onMenusUpdated(callbackGeneration, menus, start, end);
        };
    _provider.addMenuUpdatedCallback(_menuUpdatedCallback!);
  }

  void _applyMenusForWeek(DateTime weekStart, List<DailyMenu> menus) {
    PerformanceTelemetry.instance.measureSync(
      'canteen.state.apply',
      args: {'entryCount': menus.length, 'sourceType': 'unknown'},
      action: (_) {
        final previous = _weeklyRenderStates[weekStart];
        if (previous != null) {
          _visibleContentDaySet.removeAll(previous.contentDays);
          _invalidateFilteredMeals(previous);
        }
        final current = CanteenWeekRenderState.fromMenus(
          weekStart,
          menus,
          previous: previous,
          isLoading: previous?.isLoading ?? false,
          error: previous?.error,
          lastUpdated: previous?.lastUpdated,
        );
        _setWeekState(weekStart, current);
        _visibleContentDaySet.addAll(current.contentDays);
        _updateVisibleContentDaysCache();
      },
    );
  }

  void _setWeekLoading(DateTime weekStart, {required bool isLoading}) {
    final current =
        _weeklyRenderStates[weekStart] ??
        CanteenWeekRenderState.empty(weekStart, isLoading: isLoading);
    _setWeekState(weekStart, current.copyWith(isLoading: isLoading));
  }

  void _setWeekState(DateTime weekStart, CanteenWeekRenderState state) {
    _weeklyRenderStates[weekStart] = state;
  }

  bool _hasWeekContent(DateTime weekStart) {
    return _weeklyRenderStates[weekStart]?.contentDays.isNotEmpty ?? false;
  }

  void _invalidateFilteredMeals(CanteenWeekRenderState state) {
    for (final day in state.days) {
      _filteredMealsCache.remove(day.date);
    }
  }

  void _updateVisibleContentDaysCache() {
    final sortedDays = _visibleContentDaySet.toList()..sort();
    _visibleContentDaysCache = List<DateTime>.unmodifiable(sortedDays);
  }

  bool _isCurrentLocationRequest(int requestGeneration) {
    return requestGeneration == _locationGeneration && !isDisposed;
  }

  Future<void> _loadSelectedLocation({
    bool reloadWeek = false,
    bool allowNetworkRefresh = true,
  }) async {
    final nextLocation = await _locationService.getSelectedLocation();
    final didChange = _selectedLocation.id != nextLocation.id;
    _selectedLocation = nextLocation;
    notifyIfMounted('selectedLocation');

    if (!didChange || !reloadWeek) {
      return;
    }

    _weeklyRenderStates.clear();
    _loadingWeeks.clear();
    _weekLastRefreshRequestAt.clear();
    _locationGeneration++;
    _registerMenuUpdatedCallback();
    _filteredMealsCache.clear();
    _visibleContentDaySet.clear();
    _visibleContentDaysCache = const <DateTime>[];
    notifyIfMounted(weekStateProperty);
    unawaited(
      loadWeek(
        todayWeekStart,
        forceRefresh: true,
        allowNetworkRefresh: allowNetworkRefresh,
        prefetchNextWeek: false,
      ),
    );
  }

  @override
  void dispose() {
    _adjacentPrefetchDebounceTimer?.cancel();
    unawaited(_locationChangeSubscription?.cancel());
    final menuUpdatedCallback = _menuUpdatedCallback;
    if (menuUpdatedCallback != null) {
      _provider.removeMenuUpdatedCallback(menuUpdatedCallback);
    }
    super.dispose();
  }
}
