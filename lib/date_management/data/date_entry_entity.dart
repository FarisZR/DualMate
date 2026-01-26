import 'package:dualmate/common/data/database_entity.dart';
import 'package:dualmate/date_management/model/date_entry.dart';

class DateEntryEntity extends DatabaseEntity {
  late DateEntry _dateEntry;

  DateEntryEntity.fromModel(DateEntry dateEntry) {
    _dateEntry = dateEntry;
  }

  DateEntryEntity.fromMap(Map<String, dynamic> map) {
    fromMap(map);
  }

  @override
  void fromMap(Map<String, dynamic> map) {
    var date = map["date"] != null
        ? DateTime.fromMillisecondsSinceEpoch(map["date"])
        : DateTime.fromMillisecondsSinceEpoch(0);

    _dateEntry = DateEntry(
      comment: map["comment"] ?? "",
      description: map["description"] ?? "",
      year: map["year"] ?? "",
      databaseName: map["databaseName"] ?? "",
      start: date,
      end: date,
      room: map["room"] ?? "",
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      "date": _dateEntry.start.millisecondsSinceEpoch,
      "comment": _dateEntry.comment,
      "description": _dateEntry.description,
      "year": _dateEntry.year,
      "databaseName": _dateEntry.databaseName
    };
  }

  DateEntry asDateEntry() => _dateEntry;

  static String tableName() => "DateEntries";
}
