import 'package:dualmate/common/data/database_entity.dart';
import 'package:dualmate/schedule/model/schedule_query_information.dart';

class ScheduleQueryInformationEntity extends DatabaseEntity {
  late ScheduleQueryInformation _scheduleQueryInformation;

  ScheduleQueryInformationEntity.fromModel(
    ScheduleQueryInformation scheduleQueryInformation,
  ) {
    _scheduleQueryInformation = scheduleQueryInformation;
  }

  ScheduleQueryInformationEntity.fromMap(Map<String, dynamic> map) {
    fromMap(map);
  }

  @override
  void fromMap(Map<String, dynamic> map) {
    DateTime startDate =
        DateTime.fromMillisecondsSinceEpoch(map["start"] ?? 0);

    DateTime endDate = DateTime.fromMillisecondsSinceEpoch(map["end"] ?? 0);

    DateTime queryTimeDate =
        DateTime.fromMillisecondsSinceEpoch(map["queryTime"] ?? 0);

    _scheduleQueryInformation =
        ScheduleQueryInformation(startDate, endDate, queryTimeDate);
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      "start": _scheduleQueryInformation.start.millisecondsSinceEpoch,
      "end": _scheduleQueryInformation.end.millisecondsSinceEpoch,
      "queryTime": _scheduleQueryInformation.queryTime.millisecondsSinceEpoch,
    };
  }

  ScheduleQueryInformation asScheduleQueryInformation() =>
      _scheduleQueryInformation;

  static String tableName() => "ScheduleQueryInformation";
}
