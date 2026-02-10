import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/canteen/model/canteen_filter.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'dart:async';

import 'package:flutter/widgets.dart';

class CanteenViewModel extends BaseViewModel {
  final CanteenProvider _provider;

  final DateTime todayWeekStart;
  CanteenFilter filter = CanteenFilter.all;

  final Map<DateTime, List<DailyMenu>> _weeklyMenus = {};
  final Map<DateTime, String?> _weekErrors = {};
  final Set<DateTime> _loadingWeeks = {};
  final Map<DateTime, DateTime> _weekLastUpdated = {};
  bool _initialized = false;

  CanteenViewModel(this._provider)
      : todayWeekStart = toStartOfDay(toMonday(DateTime.now()));

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _provider.addMenuUpdatedCallback(_onMenusUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_weeklyMenus.containsKey(todayWeekStart)) return;
      loadWeek(todayWeekStart);
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
    final days = <DateTime>{};

    for (final weeklyMenus in _weeklyMenus.values) {
      for (final menu in weeklyMenus) {
        if (menu.meals.isEmpty) continue;
        days.add(toStartOfDay(menu.date));
      }
    }

    final sortedDays = days.toList();
    sortedDays.sort((a, b) => a.compareTo(b));
    return sortedDays;
  }

  DateTime? nearestVisibleContentDay(DateTime targetDate) {
    final visibleDays = visibleContentDays;
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

  Future<void> loadWeek(DateTime weekStart) async {
    if (_loadingWeeks.contains(weekStart)) return;

    _loadingWeeks.add(weekStart);
    notifyIfMounted("loadingWeeks");

    var cachedMenus = await _provider.getCachedWeek(weekStart);
    _weeklyMenus[weekStart] = cachedMenus;
    var lastUpdated = await _provider.lastUpdatedForWeek(weekStart);
    if (lastUpdated != null) {
      _weekLastUpdated[weekStart] = lastUpdated;
    }
    notifyIfMounted("weeklyMenus");

    try {
      var menus = await _provider.refreshWeek(weekStart);
      _weeklyMenus[weekStart] = menus;
      _weekErrors[weekStart] = null;
      _weekLastUpdated[weekStart] = DateTime.now();
    } catch (exception) {
      // keep cached data visible
      _weekErrors[weekStart] = exception.toString();
    }

    _loadingWeeks.remove(weekStart);
    notifyIfMounted("weeklyMenus");
    notifyIfMounted("weekErrors");
    notifyIfMounted("loadingWeeks");
  }

  void ensureWeekLoaded(DateTime weekStart) {
    if (_weeklyMenus.containsKey(weekStart) ||
        _loadingWeeks.contains(weekStart)) {
      return;
    }

    unawaited(loadWeek(weekStart));
  }

  void setFilter(CanteenFilter nextFilter) {
    if (filter == nextFilter) return;
    filter = nextFilter;
    notifyIfMounted("filter");
  }

  Future<void> _onMenusUpdated(
    List<DailyMenu> menus,
    DateTime start,
    DateTime end,
  ) async {
    var weekStart = toStartOfDay(toMonday(start));
    _weeklyMenus[weekStart] = menus;
    _weekLastUpdated[weekStart] = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyIfMounted("weeklyMenus");
    });
  }

  @override
  void dispose() {
    _provider.removeMenuUpdatedCallback(_onMenusUpdated);
    super.dispose();
  }
}
