import 'package:dualmate/canteen/data/canteen_meal_entity.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/util/date_utils.dart';

class CanteenMealRepository {
  final DatabaseAccess _database;

  CanteenMealRepository(this._database);

  Future<List<Meal>> queryMealsForDay(DateTime date) async {
    var start = toStartOfDay(date);
    var end = start.add(const Duration(days: 1));

    return queryMealsBetween(start, end);
  }

  Future<List<Meal>> queryMealsBetween(DateTime start, DateTime end) async {
    var rows = await _database.queryRows(
      CanteenMealEntity.tableName(),
      where: "date>=? AND date<?",
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: "date ASC, category ASC, name ASC",
    );

    var meals = <Meal>[];
    for (var row in rows) {
      meals.add(CanteenMealEntity.fromMap(row).asMeal());
    }

    return meals;
  }

  Future<DateTime?> lastUpdatedBetween(DateTime start, DateTime end) async {
    var rows = await _database.rawQuery(
      "SELECT MAX(date) as last_date FROM ${CanteenMealEntity.tableName()} WHERE date>=? AND date<?",
      [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );

    if (rows.isEmpty) return null;

    var value = rows.first["last_date"];
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    return null;
  }

  Future<void> saveMeals(List<Meal> meals) async {
    var rows =
        meals.map((meal) => CanteenMealEntity.fromModel(meal).toMap()).toList();
    await _database.insertBatch(CanteenMealEntity.tableName(), rows);
  }

  Future<void> deleteMealsBetween(DateTime start, DateTime end) async {
    await _database.deleteWhere(
      CanteenMealEntity.tableName(),
      where: "date>=? AND date<?",
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );
  }
}
