import 'dart:async';

import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/service/canteen_scraper.dart';
import 'package:dualmate/canteen/service/dhbw_app_canteen_source.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';

typedef CanteenMenuUpdatedCallback =
    Future<void> Function(List<DailyMenu> menus, DateTime start, DateTime end);

class CanteenProvider {
  final CanteenMealRepository _repository;
  final CanteenLocationService _locationService;
  final CanteenScraper _scraper;
  final DhbwAppCanteenSource _dhbwAppSource;
  final List<CanteenMenuUpdatedCallback> _callbacks = [];
  final Map<String, Future<List<DailyMenu>>> _refreshInFlight = {};
  final Map<String, DateTime> _lastRefreshAtByWeek = {};
  String? _activeLocationId;

  CanteenProvider(
    this._repository,
    this._locationService,
    this._scraper,
    this._dhbwAppSource,
  );

  void addMenuUpdatedCallback(CanteenMenuUpdatedCallback callback) {
    _callbacks.add(callback);
  }

  void removeMenuUpdatedCallback(CanteenMenuUpdatedCallback callback) {
    _callbacks.remove(callback);
  }

  Future<List<DailyMenu>> getCachedWeek(DateTime date) async {
    await _ensureActiveLocationCache();
    var weekStart = toStartOfDay(toMonday(date));
    var weekEnd = weekStart.add(const Duration(days: 5));

    var meals = await _repository.queryMealsBetween(weekStart, weekEnd);
    return _groupMealsByDay(weekStart, meals);
  }

  Future<DateTime?> lastUpdatedForWeek(DateTime date) async {
    await _ensureActiveLocationCache();
    var weekStart = toStartOfDay(toMonday(date));
    var weekEnd = weekStart.add(const Duration(days: 5));
    return _repository.latestMealDateBetween(weekStart, weekEnd);
  }

  Future<List<DailyMenu>> refreshWeek(
    DateTime date, [
    CancellationToken? cancellationToken,
  ]) async {
    return _refreshWeekInternal(
      date,
      cancellationToken: cancellationToken,
      prefetchNextWeek: true,
    );
  }

  Future<List<DailyMenu>> refreshWeekIfStale(
    DateTime date, {
    Duration staleAfter = const Duration(hours: 2),
    CancellationToken? cancellationToken,
    bool prefetchNextWeek = true,
  }) async {
    final location = await _ensureActiveLocationCache();
    var weekStart = toStartOfDay(toMonday(date));
    final refreshKey = _refreshKey(weekStart, location.id);
    final inFlight = _refreshInFlight[refreshKey];
    if (inFlight != null) {
      return inFlight;
    }

    final lastRefreshAt = _lastRefreshAtByWeek[refreshKey];
    final isFresh =
        lastRefreshAt != null &&
        DateTime.now().difference(lastRefreshAt) < staleAfter;
    if (isFresh) {
      return getCachedWeek(weekStart);
    }

    return _refreshWeekInternal(
      date,
      cancellationToken: cancellationToken,
      prefetchNextWeek: prefetchNextWeek,
    );
  }

  Future<List<DailyMenu>> _refreshWeekInternal(
    DateTime date, {
    CancellationToken? cancellationToken,
    required bool prefetchNextWeek,
  }) async {
    final location = await _ensureActiveLocationCache();
    var weekStart = toStartOfDay(toMonday(date));
    final refreshKey = _refreshKey(weekStart, location.id);
    final inFlight = _refreshInFlight[refreshKey];
    if (inFlight != null) {
      return inFlight;
    }

    final refreshFuture = _doRefreshWeek(
      location,
      weekStart,
      cancellationToken: cancellationToken,
      prefetchNextWeek: prefetchNextWeek,
    );
    _refreshInFlight[refreshKey] = refreshFuture;

    try {
      return await refreshFuture;
    } finally {
      _refreshInFlight.remove(refreshKey);
    }
  }

  Future<List<DailyMenu>> _doRefreshWeek(
    CanteenLocation location,
    DateTime weekStart, {
    CancellationToken? cancellationToken,
    required bool prefetchNextWeek,
  }) async {
    final locationId = location.id;
    var weekEnd = weekStart.add(const Duration(days: 5));

    var menus = await _loadWeekForLocation(
      location,
      weekStart,
      cancellationToken,
    );
    _throwIfLocationChanged(locationId);
    var normalizedMenus = PerformanceTelemetry.instance.measureSync(
      'canteen.menu.parse',
      args: {'entryCount': menus.length, 'sourceType': 'unknown'},
      action: (task) {
        final normalized = _normalizeMenus(weekStart, menus);
        task.setData('loadedEntryCount', normalized.length);
        return normalized;
      },
    );

    await _repository.deleteMealsBetween(weekStart, weekEnd);
    _throwIfLocationChanged(locationId);
    await _repository.saveMeals(
      normalizedMenus.expand((menu) => menu.meals).toList(),
    );
    _throwIfLocationChanged(locationId);

    await _notifyCallbacks(normalizedMenus, weekStart, weekEnd);
    _lastRefreshAtByWeek[_refreshKey(weekStart, locationId)] = DateTime.now();

    if (prefetchNextWeek) {
      unawaited(_prefetchNextWeek(location, weekStart, cancellationToken));
    }

    return normalizedMenus;
  }

  Future<void> _prefetchNextWeek(
    CanteenLocation location,
    DateTime weekStart,
    CancellationToken? cancellationToken,
  ) async {
    final locationId = location.id;
    var nextWeekStart = toStartOfDay(weekStart.add(const Duration(days: 7)));
    var nextWeekEnd = nextWeekStart.add(const Duration(days: 5));

    try {
      _throwIfLocationChanged(locationId);
      var nextMenus = await _loadWeekForLocation(
        location,
        nextWeekStart,
        cancellationToken,
      );
      _throwIfLocationChanged(locationId);
      var normalizedNextMenus = PerformanceTelemetry.instance.measureSync(
        'canteen.menu.parse',
        args: {'entryCount': nextMenus.length, 'sourceType': 'unknown'},
        action: (task) {
          final normalized = _normalizeMenus(nextWeekStart, nextMenus);
          task.setData('loadedEntryCount', normalized.length);
          return normalized;
        },
      );

      await _repository.deleteMealsBetween(nextWeekStart, nextWeekEnd);
      _throwIfLocationChanged(locationId);
      await _repository.saveMeals(
        normalizedNextMenus.expand((menu) => menu.meals).toList(),
      );
      _throwIfLocationChanged(locationId);

      await _notifyCallbacks(normalizedNextMenus, nextWeekStart, nextWeekEnd);
      _lastRefreshAtByWeek[_refreshKey(nextWeekStart, locationId)] =
          DateTime.now();
    } catch (_) {
      // Prefetch failures should not affect the current week.
    }
  }

  Future<void> _notifyCallbacks(
    List<DailyMenu> menus,
    DateTime start,
    DateTime end,
  ) async {
    for (var callback in List<CanteenMenuUpdatedCallback>.from(_callbacks)) {
      await callback(menus, start, end);
    }
  }

  Future<CanteenLocation> _ensureActiveLocationCache() async {
    final selected = await _locationService.getSelectedLocation();
    if (_activeLocationId == selected.id) {
      return selected;
    }

    final cachedLocationId = await _locationService.getCachedLocationId();
    _activeLocationId = selected.id;
    _refreshInFlight.clear();
    _lastRefreshAtByWeek.clear();
    if (cachedLocationId != null && cachedLocationId != selected.id) {
      await _repository.clearMeals();
    }
    if (cachedLocationId != selected.id) {
      await _locationService.setCachedLocation(selected);
    }
    return selected;
  }

  String _refreshKey(DateTime weekStart, String locationId) {
    return '$locationId:${weekStart.millisecondsSinceEpoch}';
  }

  void _throwIfLocationChanged(String locationId) {
    if (_activeLocationId != locationId) {
      throw OperationCancelledException();
    }
  }

  Future<List<DailyMenu>> _loadWeekForLocation(
    CanteenLocation location,
    DateTime weekStart,
    CancellationToken? cancellationToken,
  ) {
    if (location.isKarlsruheLegacy) {
      return _scraper.loadWeek(weekStart, cancellationToken);
    }

    if (location.source == CanteenLocationSource.dhbwApp) {
      final site = location.dhbwAppSite;
      final mensaId = location.dhbwAppMensaId;
      if (site == null || mensaId == null) {
        throw Exception('Missing DHBW.app id for selected canteen');
      }
      return _dhbwAppSource.loadWeek(
        site,
        mensaId,
        weekStart,
        cancellationToken,
      );
    }

    throw Exception('Unsupported canteen source');
  }

  List<DailyMenu> _groupMealsByDay(DateTime weekStart, List<Meal> meals) {
    var mealsByDay = <DateTime, List<Meal>>{};

    for (var meal in meals) {
      var dateKey = toStartOfDay(meal.date);
      mealsByDay.putIfAbsent(dateKey, () => []);
      mealsByDay[dateKey]!.add(meal);
    }

    return _buildDailyMenus(weekStart, mealsByDay);
  }

  List<DailyMenu> _normalizeMenus(DateTime weekStart, List<DailyMenu> menus) {
    var mealsByDay = <DateTime, List<Meal>>{};

    for (var menu in menus) {
      var dateKey = toStartOfDay(menu.date);
      for (var meal in menu.meals) {
        mealsByDay.putIfAbsent(dateKey, () => []);
        meal.id = null;
        mealsByDay[dateKey]!.add(meal);
      }
    }

    return _buildDailyMenus(weekStart, mealsByDay);
  }

  List<DailyMenu> _buildDailyMenus(
    DateTime weekStart,
    Map<DateTime, List<Meal>> mealsByDay,
  ) {
    var dailyMenus = <DailyMenu>[];

    for (var i = 0; i < 5; i++) {
      var day = toStartOfDay(weekStart.add(Duration(days: i)));
      var mealsForDay = mealsByDay[day] ?? [];

      for (var meal in mealsForDay) {
        meal.id = null;
      }

      dailyMenus.add(DailyMenu(date: day, meals: mealsForDay));
    }

    return dailyMenus;
  }
}
