import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/service/canteen_scraper.dart';
import 'package:dualmate/canteen/ui/viewmodels/canteen_view_model.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns only days with actual meal content as visible days', () async {
    final monday = DateTime(2026, 2, 9);
    final weekStart = toStartOfDay(toMonday(monday));
    final tuesday = weekStart.add(const Duration(days: 1));
    final thursday = weekStart.add(const Duration(days: 3));

    final provider = _FakeCanteenProvider({
      weekStart: _buildMenus(weekStart, <DateTime>{tuesday, thursday}),
    });
    final model = CanteenViewModel(provider);
    addTearDown(model.dispose);

    await model.loadWeek(weekStart);

    expect(model.visibleContentDays, <DateTime>[tuesday, thursday]);
  });

  test('clamps target date to nearest visible content day', () async {
    final monday = DateTime(2026, 2, 9);
    final weekStart = toStartOfDay(toMonday(monday));
    final tuesday = weekStart.add(const Duration(days: 1));
    final thursday = weekStart.add(const Duration(days: 3));

    final provider = _FakeCanteenProvider({
      weekStart: _buildMenus(weekStart, <DateTime>{tuesday, thursday}),
    });
    final model = CanteenViewModel(provider);
    addTearDown(model.dispose);

    await model.loadWeek(weekStart);

    expect(model.nearestVisibleContentDay(weekStart), tuesday);
    expect(
        model.nearestVisibleContentDay(weekStart.add(const Duration(days: 4))),
        thursday);
  });
}

List<DailyMenu> _buildMenus(DateTime weekStart, Set<DateTime> mealDays) {
  return List.generate(5, (index) {
    final day = toStartOfDay(weekStart.add(Duration(days: index)));
    final hasMeals = mealDays.contains(day);

    return DailyMenu(
      date: day,
      meals: hasMeals
          ? <Meal>[
              Meal(
                date: day,
                name: 'Meal_${day.day}',
                category: 'Wahlessen 1',
                price: 3.5,
                notes: const <String>[],
                mealTypes: const [],
              ),
            ]
          : <Meal>[],
    );
  });
}

class _FakeCanteenProvider extends CanteenProvider {
  final Map<DateTime, List<DailyMenu>> _menusByWeek;
  final List<CanteenMenuUpdatedCallback> _callbacks = [];

  _FakeCanteenProvider(this._menusByWeek)
      : super(CanteenMealRepository(_FakeDatabaseAccess()), CanteenScraper());

  @override
  void addMenuUpdatedCallback(CanteenMenuUpdatedCallback callback) {
    _callbacks.add(callback);
  }

  @override
  void removeMenuUpdatedCallback(CanteenMenuUpdatedCallback callback) {
    _callbacks.remove(callback);
  }

  @override
  Future<List<DailyMenu>> getCachedWeek(DateTime date) async {
    return _menusForWeek(date);
  }

  @override
  Future<DateTime?> lastUpdatedForWeek(DateTime date) async {
    return null;
  }

  @override
  Future<List<DailyMenu>> refreshWeek(
    DateTime date, [
    CancellationToken? cancellationToken,
  ]) async {
    final weekStart = toStartOfDay(toMonday(date));
    final weekEnd = weekStart.add(const Duration(days: 5));
    final menus = _menusForWeek(date);

    for (final callback in _callbacks) {
      await callback(menus, weekStart, weekEnd);
    }

    return menus;
  }

  List<DailyMenu> _menusForWeek(DateTime date) {
    final weekStart = toStartOfDay(toMonday(date));
    return _menusByWeek[weekStart] ?? _emptyWeek(weekStart);
  }

  List<DailyMenu> _emptyWeek(DateTime weekStart) {
    return List.generate(5, (index) {
      final date = toStartOfDay(weekStart.add(Duration(days: index)));
      return DailyMenu(date: date, meals: <Meal>[]);
    });
  }
}

class _FakeDatabaseAccess extends DatabaseAccess {
  @override
  Future<List<Map<String, dynamic>>> queryRows(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<dynamic>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset}) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
      String sql, List<dynamic> parameters) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<void> insertBatch(
      String table, List<Map<String, dynamic>> rows) async {
    return;
  }

  @override
  Future<int> deleteWhere(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    return 0;
  }
}
