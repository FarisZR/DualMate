import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/canteen/model/canteen_filter.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/model/meal_type.dart';
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
    'caches filtered meals per day and invalidates replaced week data',
    () async {
      final weekStart = DateTime(2026, 7, 13);
      final provider = _RenderStateProvider(_menusForWeek(weekStart));
      final model = CanteenViewModel(provider, TestCanteenLocationService());
      addTearDown(model.dispose);
      var weekStateNotifications = 0;
      model.addListener((String? property) {
        if (property == CanteenViewModel.weekStateProperty) {
          weekStateNotifications++;
        }
      }, const [CanteenViewModel.weekStateProperty]);

      await model.loadWeek(weekStart, allowNetworkRefresh: false);
      expect(weekStateNotifications, 2);

      final allMeals = model.mealsForDay(weekStart, weekStart);
      expect(
        identical(allMeals, model.mealsForDay(weekStart, weekStart)),
        isTrue,
      );

      model.setFilter(CanteenFilter.vegan);
      final veganMeals = model.mealsForDay(weekStart, weekStart);
      expect(veganMeals.map((meal) => meal.name), <String>['vegan meal']);
      expect(
        identical(veganMeals, model.mealsForDay(weekStart, weekStart)),
        isTrue,
      );

      model.setFilter(CanteenFilter.all);
      expect(
        identical(allMeals, model.mealsForDay(weekStart, weekStart)),
        isTrue,
      );

      provider.menus = _menusForWeek(weekStart, mealPrefix: 'Replacement');
      await model.loadWeek(
        weekStart,
        forceRefresh: true,
        allowNetworkRefresh: false,
      );

      final replacementMeals = model.mealsForDay(weekStart, weekStart);
      expect(replacementMeals.map((meal) => meal.name), <String>[
        'Replacement pork meal',
        'Replacement vegan meal',
      ]);
      expect(identical(allMeals, replacementMeals), isFalse);
      expect(
        identical(model.visibleContentDays, model.visibleContentDays),
        isTrue,
      );
    },
  );

  test('exposes immutable weekly render data', () async {
    final weekStart = DateTime(2026, 7, 13);
    final model = CanteenViewModel(
      _RenderStateProvider(_menusForWeek(weekStart)),
      TestCanteenLocationService(),
    );
    addTearDown(model.dispose);

    await model.loadWeek(weekStart, allowNetworkRefresh: false);

    final menus = model.weeklyMenusFor(weekStart);
    expect(
      () => menus.add(DailyMenu(date: weekStart, meals: const [])),
      throwsUnsupportedError,
    );
    expect(model.contentDaysForWeek(weekStart), <DateTime>[weekStart]);
  });
}

List<DailyMenu> _menusForWeek(DateTime weekStart, {String mealPrefix = ''}) {
  final day = toStartOfDay(weekStart);
  final prefix = mealPrefix.isEmpty ? '' : '$mealPrefix ';
  return List<DailyMenu>.generate(5, (index) {
    final date = day.add(Duration(days: index));
    if (index != 0) return DailyMenu(date: date, meals: const []);
    return DailyMenu(
      date: date,
      meals: <Meal>[
        Meal(
          date: date,
          name: '${prefix}pork meal',
          category: 'Main dish',
          price: 3.5,
          notes: const [],
          mealTypes: const [MealType.pork],
        ),
        Meal(
          date: date,
          name: '${prefix}vegan meal',
          category: 'Main dish',
          price: 3.5,
          notes: const [],
          mealTypes: const [MealType.vegan],
        ),
      ],
    );
  });
}

class _RenderStateProvider extends CanteenProvider {
  List<DailyMenu> menus;

  _RenderStateProvider(this.menus)
    : super(
        CanteenMealRepository(_EmptyDatabaseAccess()),
        TestCanteenLocationService(),
        CanteenScraper(),
        DhbwAppCanteenSource(),
      );

  @override
  Future<List<DailyMenu>> getCachedWeek(DateTime date) async => menus;

  @override
  Future<List<DailyMenu>> refreshWeek(
    DateTime date, [
    CancellationToken? cancellationToken,
  ]) async => menus;

  @override
  Future<DateTime?> lastUpdatedForWeek(DateTime date) async => null;
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
  Future<void> insertBatch(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {}

  @override
  Future<int> deleteWhere(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async => 0;
}
