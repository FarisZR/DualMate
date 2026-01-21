import 'package:dhbwstudentapp/common/util/cancellation_token.dart';
import 'package:dhbwstudentapp/schedule/model/schedule_query_result.dart';
import 'package:dhbwstudentapp/schedule/service/rapla/rapla_schedule_source.dart';

class MockRaplaScheduleSource extends RaplaScheduleSource {
  final ScheduleQueryResult result;

  MockRaplaScheduleSource(this.result);

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    return result;
  }

  @override
  void setEndpointUrl(String url) {}
}
