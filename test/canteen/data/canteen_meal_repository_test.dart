import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final sunday in [DateTime(2026, 3, 29), DateTime(2026, 10, 25)]) {
    test(
      'day query ends at the following calendar midnight: $sunday',
      () async {
        final database = _RecordingDatabase();
        await CanteenMealRepository(database).queryMealsForDay(sunday);
        expect(database.bounds, [
          sunday.millisecondsSinceEpoch,
          DateTime(
            sunday.year,
            sunday.month,
            sunday.day + 1,
          ).millisecondsSinceEpoch,
        ]);
      },
    );
  }
}

class _RecordingDatabase extends DatabaseAccess {
  List<Object?>? bounds;

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
    bounds = whereArgs;
    return [];
  }
}
