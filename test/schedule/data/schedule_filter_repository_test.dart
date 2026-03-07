import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saveAllHiddenNames writes hidden names in one batch', () async {
    final database = _TrackingDatabaseAccess();
    final repository = ScheduleFilterRepository(database);

    await repository.saveAllHiddenNames(['Class A', 'Class B']);

    expect(database.deletedTables, ['ScheduleEntryFilters']);
    expect(database.batchInsertTable, 'ScheduleEntryFilters');
    expect(database.batchInsertRows, [
      {'title': 'Class A'},
      {'title': 'Class B'},
    ]);
  });
}

class _TrackingDatabaseAccess extends DatabaseAccess {
  final List<String> deletedTables = <String>[];
  String? batchInsertTable;
  List<Map<String, dynamic>> batchInsertRows = <Map<String, dynamic>>[];

  @override
  Future<int> deleteWhere(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    deletedTables.add(table);
    return 0;
  }

  @override
  Future<void> insertBatch(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    batchInsertTable = table;
    batchInsertRows = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
