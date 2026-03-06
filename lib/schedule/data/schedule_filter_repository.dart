import 'package:dualmate/common/data/database_access.dart';

class ScheduleFilterRepository {
  final DatabaseAccess _database;

  ScheduleFilterRepository(this._database);

  Future<List<String>> queryAllHiddenNames() async {
    var rows = await _database.queryRows("ScheduleEntryFilters");

    var names = rows.map((e) => e['title'] as String).toList();
    return names;
  }

  Future<void> saveAllHiddenNames(List<String> hiddenNames) async {
    await _database.deleteWhere("ScheduleEntryFilters");
    await _database.insertBatch(
      "ScheduleEntryFilters",
      hiddenNames.map((name) => {'title': name}).toList(),
    );
  }
}
