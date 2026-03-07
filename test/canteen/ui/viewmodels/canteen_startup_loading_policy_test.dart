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

  test('prefetchAdjacentWeeksDebounced refreshes next week for forward swipes',
      () async {
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
    model.prefetchAdjacentWeeksDebounced(monday);
    await Future<void>.delayed(const Duration(milliseconds: 320));

    expect(provider.cachedWeekRequests.toSet(), <DateTime>{previous, next});
    expect(provider.refreshWeekIfStaleRequests, <DateTime>[next]);
    expect(model.visibleContentDays, <DateTime>[weekStart, next]);
  });

  test('refreshVisibleWeekIfStale throttles repeated same-week requests',
      () async {
    final monday = DateTime(2026, 2, 9);
    final weekStart = toStartOfDay(toMonday(monday));
    final provider = _TrackingCanteenProvider();
    final model = CanteenViewModel(provider);
    addTearDown(model.dispose);

    model.primeVisibleWeek(monday);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    provider.clearRequests();

    model.refreshVisibleWeekIfStale(
      monday,
      staleAfter: Duration.zero,
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    model.refreshVisibleWeekIfStale(monday);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(provider.refreshWeekIfStaleRequests, <DateTime>[weekStart]);
  });
}

class _TrackingCanteenProvider extends CanteenProvider {
  final List<CanteenMenuUpdatedCallback> _callbacks = [];
  final List<DateTime> cachedWeekRequests = [];
  final List<DateTime> refreshWeekRequests = [];
  final List<DateTime> refreshWeekIfStaleRequests = [];
  final Set<DateTime> _cachedWeeks = <DateTime>{};

  _TrackingCanteenProvider()
      : super(CanteenMealRepository(_FakeDatabaseAccess()), CanteenScraper());

  @override
  void addMenuUpdatedCallback(CanteenMenuUpdatedCallback callback) {
    _callbacks.add(callback);
  }

  @override
  void removeMenuUpdatedCallback(CanteenMenuUpdatedCallback callback) {
    _callbacks.remove(callback);
  }

  DateTime get _baseWeekStart => toStartOfDay(toMonday(DateTime(2026, 2, 9)));

  @override
  Future<List<DailyMenu>> getCachedWeek(DateTime date) async {
    final weekStart = toStartOfDay(toMonday(date));
    cachedWeekRequests.add(weekStart);

    // Simulate cold startup: only the current week exists in local cache.
    if (_cachedWeeks.isEmpty) {
      _cachedWeeks.add(_baseWeekStart);
    }
    if (!_cachedWeeks.contains(weekStart)) {
      return _emptyWeek(weekStart);
    }
    return _menusForWeek(weekStart);
  }

  @override
  Future<List<DailyMenu>> refreshWeek(
    DateTime date, [
    CancellationToken? cancellationToken,
  ]) async {
    final weekStart = toStartOfDay(toMonday(date));
    refreshWeekRequests.add(weekStart);
    _cachedWeeks.add(weekStart);
    final menus = _menusForWeek(weekStart);
    final weekEnd = weekStart.add(const Duration(days: 5));
    for (final callback in _callbacks) {
      await callback(menus, weekStart, weekEnd);
    }
    return menus;
  }

  void clearRequests() {
    cachedWeekRequests.clear();
    refreshWeekRequests.clear();
    refreshWeekIfStaleRequests.clear();
  }

  @override
  Future<DateTime?> lastUpdatedForWeek(DateTime date) async {
    return null;
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

  List<DailyMenu> _emptyWeek(DateTime weekStart) {
    return List.generate(5, (index) {
      final day = toStartOfDay(weekStart.add(Duration(days: index)));
      return DailyMenu(date: day, meals: const <Meal>[]);
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
