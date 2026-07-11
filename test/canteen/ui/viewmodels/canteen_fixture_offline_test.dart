import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/service/canteen_scraper.dart';
import 'package:dualmate/canteen/service/dhbw_app_canteen_source.dart';
import 'package:dualmate/canteen/ui/viewmodels/canteen_view_model.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_canteen_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reloadSelectedLocation with allowNetworkRefresh=false does not trigger '
    'a network refresh',
    () async {
      final provider = _NetworkTrackingCanteenProvider();
      final model = CanteenViewModel(provider, TestCanteenLocationService());
      addTearDown(model.dispose);

      model.primeVisibleWeek(DateTime(2026, 2, 9));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      provider.clearRequests();

      await model.reloadSelectedLocation(allowNetworkRefresh: false);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(provider.refreshWeekRequests, isEmpty);
      expect(provider.refreshWeekIfStaleRequests, isEmpty);
    },
  );
}

class _NetworkTrackingCanteenProvider extends CanteenProvider {
  final List<DateTime> refreshWeekRequests = [];
  final List<DateTime> refreshWeekIfStaleRequests = [];
  final Set<DateTime> _cachedWeeks = {};

  _NetworkTrackingCanteenProvider()
    : super(
        CanteenMealRepository(_EmptyDatabaseAccess()),
        TestCanteenLocationService(),
        CanteenScraper(),
        DhbwAppCanteenSource(),
      );

  @override
  Future<List<DailyMenu>> getCachedWeek(DateTime date) async {
    final weekStart = toStartOfDay(toMonday(date));
    if (_cachedWeeks.isEmpty) {
      _cachedWeeks.add(weekStart);
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
    refreshWeekRequests.add(toStartOfDay(toMonday(date)));
    return _menusForWeek(toStartOfDay(toMonday(date)));
  }

  @override
  Future<List<DailyMenu>> refreshWeekIfStale(
    DateTime date, {
    Duration staleAfter = const Duration(hours: 2),
    CancellationToken? cancellationToken,
    bool prefetchNextWeek = true,
  }) async {
    refreshWeekIfStaleRequests.add(toStartOfDay(toMonday(date)));
    return refreshWeek(date, cancellationToken);
  }

  @override
  Future<DateTime?> lastUpdatedForWeek(DateTime date) async => null;

  void clearRequests() {
    refreshWeekRequests.clear();
    refreshWeekIfStaleRequests.clear();
  }

  List<DailyMenu> _menusForWeek(DateTime weekStart) {
    return List.generate(5, (index) {
      final day = toStartOfDay(weekStart.add(Duration(days: index)));
      return DailyMenu(
        date: day,
        meals: index == 0
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
            : const <Meal>[],
      );
    });
  }

  List<DailyMenu> _emptyWeek(DateTime weekStart) {
    return List.generate(5, (index) {
      final day = toStartOfDay(weekStart.add(Duration(days: index)));
      return DailyMenu(date: day, meals: const <Meal>[]);
    });
  }
}

class _EmptyDatabaseAccess extends DatabaseAccess {
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
  }) async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql,
    List<dynamic> parameters,
  ) async => <Map<String, dynamic>>[];

  @override
  Future<void> insertBatch(String table, List<Map<String, dynamic>> rows) async {}

  @override
  Future<int> deleteWhere(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async => 0;
}
