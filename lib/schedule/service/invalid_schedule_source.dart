import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

class InvalidScheduleSource extends ScheduleSource {
  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) {
    throw StateError("Schedule source not properly configured");
  }

  @override
  bool canQuery() {
    return false;
  }
}
