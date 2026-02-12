import 'dart:async';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  test('primeVisibleWeek loads only the requested week immediately', () async {
    final monday = DateTime(2026, 2, 9);
    final weekStart = toStartOfDay(toMonday(monday));
    final provider = _TrackingCanteenProvider();
    final model = CanteenViewModel(provider);
    addTearDown(model.dispose);

    model.primeVisibleWeek(monday);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(provider.cachedWeekRequests, <DateTime>[weekStart]);
    expect(provider.refreshWeekIfStaleRequests, <DateTime>[weekStart]);
  });

  test('prefetchAdjacentWeeksDebounced loads adjacent cache only', () async {
    final monday = DateTime(2026, 2, 9);
    final weekStart = toStartOfDay(toMonday(monday));
    final previous = toStartOfDay(weekStart.subtract(const Duration(days: 7)));
    final next = toStartOfDay(weekStart.add(const Duration(days: 7)));
    final provider = _TrackingCanteenProvider();
    final model = CanteenViewModel(provider);
    addTearDown(model.dispose);

    model.primeVisibleWeek(monday);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    provider.clearRequests();

    model.prefetchAdjacentWeeksDebounced(monday);
    await Future<void>.delayed(const Duration(milliseconds: 320));

    expect(provider.cachedWeekRequests.toSet(), <DateTime>{previous, next});
    expect(provider.refreshWeekIfStaleRequests, isEmpty);
  });
}

class _TrackingCanteenProvider extends CanteenProvider {
  final List<CanteenMenuUpdatedCallback> _callbacks = [];
  final List<DateTime> cachedWeekRequests = [];
  final List<DateTime> refreshWeekRequests = [];
  final List<DateTime> refreshWeekIfStaleRequests = [];

  _TrackingCanteenProvider()
      : super(CanteenMealRepository(_FakeDatabaseAccess()), CanteenScraper());

  void clearRequests() {
    cachedWeekRequests.clear();
    refreshWeekRequests.clear();
    refreshWeekIfStaleRequests.clear();
  }

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
    final weekStart = toStartOfDay(toMonday(date));
    cachedWeekRequests.add(weekStart);
    return _menusForWeek(weekStart);
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
    refreshWeekRequests.add(weekStart);
    final menus = _menusForWeek(weekStart);
    final weekEnd = weekStart.add(const Duration(days: 5));
    for (final callback in _callbacks) {
      await callback(menus, weekStart, weekEnd);
    }
    return menus;
  }

  @override
  Future<List<DailyMenu>> refreshWeekIfStale(
    DateTime date, {
    Duration staleAfter = const Duration(hours: 2),
    CancellationToken? cancellationToken,
    bool prefetchNextWeek = true,
  }) async {
    final weekStart = toStartOfDay(toMonday(date));
    refreshWeekIfStaleRequests.add(weekStart);
    return refreshWeek(date, cancellationToken);
  }

  List<DailyMenu> _menusForWeek(DateTime weekStart) {
    return List.generate(5, (index) {
      final day = toStartOfDay(weekStart.add(Duration(days: index)));
      final meals = index == 0
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
          : <Meal>[];

      return DailyMenu(date: day, meals: meals);
    });
  }
}

class _FakeDatabaseAccess extends DatabaseAccess {
  @override
  Future<List<Map<String, dynamic>>> queryRows(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
      String sql, List<dynamic> parameters) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<void> insertBatch(
      String table, List<Map<String, dynamic>> rows) async {}

  @override
  Future<int> deleteWhere(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    return 0;
  }
}
