import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

class ErrorReportScheduleSourceDecorator extends ScheduleSource {
  final ScheduleSource _scheduleSource;

  ErrorReportScheduleSourceDecorator(this._scheduleSource);

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    try {
      var schedule = await _scheduleSource.querySchedule(
        from,
        to,
        cancellationToken ?? CancellationToken(),
      );

      return schedule;
    } catch (ex, trace) {
      if (ex is OperationCancelledException) rethrow;

      // ScheduleQueryFailedException (both expected network failures and
      // unexpected ones) is handled by the calling refresh path, which uses
      // [isExpectedScheduleFetchFailure] to decide whether to report. This
      // avoids double-reporting and lets the UI/telemetry layers stay in
      // control of the Sentry Issue decision.
      if (ex is ScheduleQueryFailedException) rethrow;

      await reportException(ex, trace);
      rethrow;
    }
  }

  @override
  bool canQuery() {
    return _scheduleSource.canQuery();
  }
}
