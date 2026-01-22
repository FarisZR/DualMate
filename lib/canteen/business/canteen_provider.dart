import 'package:dhbwstudentapp/canteen/data/canteen_meal_repository.dart';
import 'package:dhbwstudentapp/canteen/model/daily_menu.dart';
import 'package:dhbwstudentapp/canteen/model/meal.dart';
import 'package:dhbwstudentapp/canteen/service/canteen_scraper.dart';
import 'package:dhbwstudentapp/common/util/cancellation_token.dart';
import 'package:dhbwstudentapp/common/util/date_utils.dart';

typedef CanteenMenuUpdatedCallback = Future<void> Function(
  List<DailyMenu> menus,
  DateTime start,
  DateTime end,
);

class CanteenProvider {
  final CanteenMealRepository _repository;
  final CanteenScraper _scraper;
  final List<CanteenMenuUpdatedCallback> _callbacks = [];

  CanteenProvider(this._repository, this._scraper);

  void addMenuUpdatedCallback(CanteenMenuUpdatedCallback callback) {
    _callbacks.add(callback);
  }

  void removeMenuUpdatedCallback(CanteenMenuUpdatedCallback callback) {
    _callbacks.remove(callback);
  }

  Future<List<DailyMenu>> getCachedWeek(DateTime date) async {
    var weekStart = toStartOfDay(toMonday(date));
    var weekEnd = weekStart.add(const Duration(days: 5));

    var meals = await _repository.queryMealsBetween(weekStart, weekEnd);
    return _groupMealsByDay(weekStart, meals);
  }

  Future<List<DailyMenu>> refreshWeek(
    DateTime date, [
    CancellationToken? cancellationToken,
  ]) async {
    var weekStart = toStartOfDay(toMonday(date));
    var weekEnd = weekStart.add(const Duration(days: 5));

    var menus = await _scraper.loadWeek(date, cancellationToken);
    var normalizedMenus = _normalizeMenus(weekStart, menus);

    await _repository.deleteMealsBetween(weekStart, weekEnd);
    await _repository.saveMeals(
      normalizedMenus.expand((menu) => menu.meals).toList(),
    );

    await _notifyCallbacks(normalizedMenus, weekStart, weekEnd);

    return normalizedMenus;
  }

  Future<void> _notifyCallbacks(
    List<DailyMenu> menus,
    DateTime start,
    DateTime end,
  ) async {
    for (var callback in _callbacks) {
      await callback(menus, start, end);
    }
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
