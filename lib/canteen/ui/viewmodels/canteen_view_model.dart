import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/model/canteen_filter.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'dart:async';

import 'package:flutter/widgets.dart';

class CanteenViewModel extends BaseViewModel {
  static const Duration defaultStaleAfter = Duration(hours: 2);
  static const Duration _adjacentPrefetchDebounceDelay =
      Duration(milliseconds: 250);

  final CanteenProvider _provider;
  final CanteenLocationService _locationService;

  final DateTime todayWeekStart;
  CanteenFilter filter = CanteenFilter.all;

  final Map<DateTime, List<DailyMenu>> _weeklyMenus = {};
  final Map<DateTime, String?> _weekErrors = {};
  final Set<DateTime> _loadingWeeks = {};
  final Map<DateTime, DateTime> _weekLastUpdated = {};
  final Map<DateTime, DateTime> _weekLastRefreshRequestAt = {};
  bool _initialized = false;
  Timer? _adjacentPrefetchDebounceTimer;
  DateTime? _lastAdjacentPrefetchCenterWeekStart;
  List<DateTime> _visibleContentDaysCache = const <DateTime>[];
  bool _visibleContentDaysDirty = true;
  CanteenLocation _selectedLocation = CanteenLocations.defaultLocation;

  CanteenLocation get selectedLocation => _selectedLocation;

  CanteenViewModel(this._provider, this._locationService)
      : todayWeekStart = toStartOfDay(toMonday(DateTime.now()));

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _provider.addMenuUpdatedCallback(_onMenusUpdated);
    unawaited(_loadSelectedLocation());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_weeklyMenus.containsKey(todayWeekStart)) return;
      primeVisibleWeek(todayWeekStart);
    });
  }

  List<DailyMenu> weeklyMenusFor(DateTime weekStart) {
    return _weeklyMenus[weekStart] ?? [];
  }

  bool hasWeekData(DateTime weekStart) {
    return _weeklyMenus.containsKey(weekStart);
  }

  bool isLoadingWeek(DateTime weekStart) {
    return _loadingWeeks.contains(weekStart);
  }

  String? errorForWeek(DateTime weekStart) {
    return _weekErrors[weekStart];
  }

  DateTime? lastUpdatedForWeek(DateTime weekStart) {
    return _weekLastUpdated[weekStart];
  }

  DateTime weekStartFor(DateTime date) {
    return toStartOfDay(toMonday(date));
  }

  List<Meal> mealsForDay(DateTime weekStart, DateTime date) {
    var menu = weeklyMenusFor(weekStart).firstWhere(
      (entry) => isAtSameDay(entry.date, date),
      orElse: () => DailyMenu(date: date, meals: []),
    );

    return menu.meals.where(filter.allowsMeal).toList();
  }

  List<Meal> mealsForDate(DateTime date) {
    return mealsForDay(weekStartFor(date), date);
  }

  List<DateTime> get visibleContentDays {
    if (!_visibleContentDaysDirty) {
      return List.unmodifiable(_visibleContentDaysCache);
    }

    final days = <DateTime>{};

    for (final weeklyMenus in _weeklyMenus.values) {
      for (final menu in weeklyMenus) {
        if (menu.meals.isEmpty) continue;
        days.add(toStartOfDay(menu.date));
      }
    }

    final sortedDays = days.toList();
    sortedDays.sort((a, b) => a.compareTo(b));
    _visibleContentDaysCache = List.unmodifiable(sortedDays);
    _visibleContentDaysDirty = false;
    return List.unmodifiable(_visibleContentDaysCache);
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
    if (_loadingWeeks.contains(weekStart)) return;

    _loadingWeeks.add(weekStart);
    notifyIfMounted("loadingWeeks");

    final shouldReloadFromDatabase =
        forceRefresh || !_weeklyMenus.containsKey(weekStart);

    if (shouldReloadFromDatabase) {
      final cachedMenusFuture = _provider.getCachedWeek(weekStart);
      final lastUpdatedFuture = _provider.lastUpdatedForWeek(weekStart);

      var cachedMenus = await cachedMenusFuture;
      _weeklyMenus[weekStart] = cachedMenus;
      _markVisibleContentDaysDirty();
      var lastUpdated = await lastUpdatedFuture;
      if (lastUpdated != null) {
        _weekLastUpdated[weekStart] = lastUpdated;
      }
      notifyIfMounted("weeklyMenus");
    }

    if (allowNetworkRefresh) {
      _weekLastRefreshRequestAt[weekStart] = DateTime.now();
      try {
        final menus = forceRefresh
            ? await _provider.refreshWeek(weekStart)
            : await _provider.refreshWeekIfStale(
                weekStart,
                staleAfter: staleAfter,
                prefetchNextWeek: prefetchNextWeek,
              );
        _weeklyMenus[weekStart] = menus;
        _markVisibleContentDaysDirty();
        _weekErrors[weekStart] = null;
        _weekLastUpdated[weekStart] = DateTime.now();
      } catch (exception) {
        // keep cached data visible
        _weekErrors[weekStart] = exception.toString();
      }
    }

    _loadingWeeks.remove(weekStart);
    notifyIfMounted("weeklyMenus");
    notifyIfMounted("weekErrors");
    notifyIfMounted("loadingWeeks");
  }

  void ensureWeekLoaded(
    DateTime weekStart, {
    bool allowNetworkRefresh = true,
    bool prefetchNextWeek = true,
    Duration staleAfter = defaultStaleAfter,
  }) {
    if (_weeklyMenus.containsKey(weekStart) ||
        _loadingWeeks.contains(weekStart)) {
      return;
    }

    unawaited(loadWeek(
      weekStart,
      allowNetworkRefresh: allowNetworkRefresh,
      prefetchNextWeek: prefetchNextWeek,
      staleAfter: staleAfter,
    ));
  }

  void primeVisibleWeek(DateTime day) {
    final weekStart = weekStartFor(day);
    if (hasWeekData(weekStart)) {
      refreshVisibleWeekIfStale(day);
      return;
    }
    ensureWeekLoaded(
      weekStart,
      allowNetworkRefresh: true,
      prefetchNextWeek: false,
    );
  }

  void refreshVisibleWeekIfStale(
    DateTime day, {
    Duration staleAfter = defaultStaleAfter,
  }) {
    final weekStart = weekStartFor(day);
    if (_loadingWeeks.contains(weekStart)) return;
    final lastRefreshRequestAt = _weekLastRefreshRequestAt[weekStart];
    if (lastRefreshRequestAt != null &&
        DateTime.now().difference(lastRefreshRequestAt) < staleAfter) {
      return;
    }
    unawaited(loadWeek(
      weekStart,
      allowNetworkRefresh: true,
      prefetchNextWeek: false,
      staleAfter: staleAfter,
    ));
  }

  void prefetchAdjacentWeeksDebounced(DateTime centerDay) {
    final centerWeekStart = weekStartFor(centerDay);
    if (_lastAdjacentPrefetchCenterWeekStart == centerWeekStart) {
      return;
    }
    _lastAdjacentPrefetchCenterWeekStart = centerWeekStart;

    _adjacentPrefetchDebounceTimer?.cancel();
    _adjacentPrefetchDebounceTimer = Timer(
      _adjacentPrefetchDebounceDelay,
      () {
        if (isDisposed) return;
        _prefetchAdjacentWeeks(centerWeekStart);
      },
    );
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
    final previousWeekStart = centerWeekStart.subtract(
      const Duration(days: 7),
    );
    final nextWeekStart = centerWeekStart.add(
      const Duration(days: 7),
    );
    ensureWeekLoaded(
      previousWeekStart,
      allowNetworkRefresh: false,
      prefetchNextWeek: false,
    );
    if (_loadingWeeks.contains(nextWeekStart)) {
      return;
    }
    unawaited(loadWeek(
      nextWeekStart,
      allowNetworkRefresh: true,
      prefetchNextWeek: false,
    ));
  }

  void setFilter(CanteenFilter nextFilter) {
    if (filter == nextFilter) return;
    filter = nextFilter;
    notifyIfMounted("filter");
  }

  Future<void> reloadSelectedLocation() async {
    await _loadSelectedLocation(reloadWeek: true);
  }

  Future<void> _onMenusUpdated(
    List<DailyMenu> menus,
    DateTime start,
    DateTime end,
  ) async {
    var weekStart = toStartOfDay(toMonday(start));
    _weeklyMenus[weekStart] = menus;
    _markVisibleContentDaysDirty();
    _weekLastUpdated[weekStart] = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyIfMounted("weeklyMenus");
    });
  }

  void _markVisibleContentDaysDirty() {
    _visibleContentDaysDirty = true;
  }

  Future<void> _loadSelectedLocation({bool reloadWeek = false}) async {
    final nextLocation = await _locationService.getSelectedLocation();
    final didChange = _selectedLocation.id != nextLocation.id;
    _selectedLocation = nextLocation;
    notifyIfMounted('selectedLocation');

    if (!didChange || !reloadWeek) {
      return;
    }

    _weeklyMenus.clear();
    _weekErrors.clear();
    _weekLastUpdated.clear();
    _weekLastRefreshRequestAt.clear();
    _markVisibleContentDaysDirty();
    notifyIfMounted('weeklyMenus');
    unawaited(loadWeek(todayWeekStart, forceRefresh: true, prefetchNextWeek: false));
  }

  @override
  void dispose() {
    _adjacentPrefetchDebounceTimer?.cancel();
    _provider.removeMenuUpdatedCallback(_onMenusUpdated);
    super.dispose();
  }
}
