import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';

class ErrorReportScheduleSourceDecorator extends ScheduleSource {
  final ScheduleSource _scheduleSource;

  ErrorReportScheduleSourceDecorator(this._scheduleSource);

  @override
  Future<ScheduleQueryResult> querySchedule(DateTime from, DateTime to,
      [CancellationToken? cancellationToken]) async {
    try {
      var schedule = await _scheduleSource.querySchedule(
        from,
        to,
        cancellationToken ?? CancellationToken(),
      );

      return schedule;
    } catch (ex, trace) {
      if (ex is OperationCancelledException) rethrow;
      if (ex is ScheduleQueryFailedException) {
        // Do not log connectivity exceptions
        if (ex.innerException is ServiceRequestFailed) rethrow;

        await reportException(ex, ex.trace ?? StackTrace.current);
      } else {
        await reportException(ex, trace);
      }

      rethrow;
    }
  }

  @override
  bool canQuery() {
    return _scheduleSource.canQuery();
  }
}
