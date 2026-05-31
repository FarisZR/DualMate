import 'dart:async';

import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/service/canteen_scraper.dart';
import 'package:dualmate/canteen/service/open_mensa_canteen_source.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';

typedef CanteenMenuUpdatedCallback = Future<void> Function(
  List<DailyMenu> menus,
  DateTime start,
  DateTime end,
);

class CanteenProvider {
  final CanteenMealRepository _repository;
  final CanteenLocationService _locationService;
  final CanteenScraper _scraper;
  final OpenMensaCanteenSource _openMensaSource;
  final List<CanteenMenuUpdatedCallback> _callbacks = [];
  final Map<DateTime, Future<List<DailyMenu>>> _refreshInFlight = {};
  final Map<DateTime, DateTime> _lastRefreshAtByWeek = {};
  String? _activeLocationId;

  CanteenProvider(
    this._repository,
    this._locationService,
    this._scraper,
    this._openMensaSource,
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
    var weekStart = toStartOfDay(toMonday(date));
    final inFlight = _refreshInFlight[weekStart];
    if (inFlight != null) {
      return inFlight;
    }

    final lastRefreshAt = _lastRefreshAtByWeek[weekStart];
    final isFresh = lastRefreshAt != null &&
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
    var weekStart = toStartOfDay(toMonday(date));
    final inFlight = _refreshInFlight[weekStart];
    if (inFlight != null) {
      return inFlight;
    }

    final refreshFuture = _doRefreshWeek(
      weekStart,
      cancellationToken: cancellationToken,
      prefetchNextWeek: prefetchNextWeek,
    );
    _refreshInFlight[weekStart] = refreshFuture;

    try {
      return await refreshFuture;
    } finally {
      _refreshInFlight.remove(weekStart);
    }
  }

  Future<List<DailyMenu>> _doRefreshWeek(
    DateTime weekStart, {
    CancellationToken? cancellationToken,
    required bool prefetchNextWeek,
  }) async {
    final location = await _ensureActiveLocationCache();
    var weekEnd = weekStart.add(const Duration(days: 5));

    var menus = await _loadWeekForLocation(
      location,
      weekStart,
      cancellationToken,
    );
    var normalizedMenus = _normalizeMenus(weekStart, menus);

    await _repository.deleteMealsBetween(weekStart, weekEnd);
    await _repository.saveMeals(
      normalizedMenus.expand((menu) => menu.meals).toList(),
    );

    await _notifyCallbacks(normalizedMenus, weekStart, weekEnd);
    _lastRefreshAtByWeek[weekStart] = DateTime.now();

    if (prefetchNextWeek) {
      unawaited(_prefetchNextWeek(weekStart, cancellationToken));
    }

    return normalizedMenus;
  }

  Future<void> _prefetchNextWeek(
    DateTime weekStart,
    CancellationToken? cancellationToken,
  ) async {
    final location = await _ensureActiveLocationCache();
    var nextWeekStart = toStartOfDay(weekStart.add(const Duration(days: 7)));
    var nextWeekEnd = nextWeekStart.add(const Duration(days: 5));

    try {
      var nextMenus = await _loadWeekForLocation(
        location,
        nextWeekStart,
        cancellationToken,
      );
      var normalizedNextMenus = _normalizeMenus(nextWeekStart, nextMenus);

      await _repository.deleteMealsBetween(nextWeekStart, nextWeekEnd);
      await _repository.saveMeals(
        normalizedNextMenus.expand((menu) => menu.meals).toList(),
      );

      await _notifyCallbacks(normalizedNextMenus, nextWeekStart, nextWeekEnd);
      _lastRefreshAtByWeek[nextWeekStart] = DateTime.now();
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

    _activeLocationId = selected.id;
    _refreshInFlight.clear();
    _lastRefreshAtByWeek.clear();
    await _repository.clearMeals();
    return selected;
  }

  Future<List<DailyMenu>> _loadWeekForLocation(
    CanteenLocation location,
    DateTime weekStart,
    CancellationToken? cancellationToken,
  ) {
    if (location.isKarlsruheLegacy) {
      return _scraper.loadWeek(weekStart, cancellationToken);
    }

    final openMensaId = location.openMensaId;
    if (openMensaId == null) {
      throw Exception('Missing OpenMensa id for selected canteen');
    }

    return _openMensaSource.loadWeek(openMensaId, weekStart, cancellationToken);
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
