import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';

abstract class ScheduleSource {
  ///
  /// Queries the schedule from the implemented service. The resulting schedule
  /// contains all entries between the `from` and `to` date.
  /// When a `cancellationToken` is provided the operation may be cancelled.
  /// Returns a future which gives the updated schedule or throws an exception
  /// if an error happened or the operation was cancelled
  ///
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]);

  bool canQuery();
}

class ScheduleQueryFailedException implements Exception {
  final dynamic innerException;
  final StackTrace? trace;

  ScheduleQueryFailedException(this.innerException, [this.trace]);

  @override
  String toString() {
    return (innerException?.toString() ?? "") +
        "\n" +
        (trace?.toString() ?? "");
  }
}

class ServiceRequestFailed implements Exception {
  final String message;

  ServiceRequestFailed(this.message);

  @override
  String toString() {
    return message;
  }
}

class EndpointUrlInvalid implements Exception {}

/// Whether [error] represents an expected external network/request failure
/// that should be tracked as telemetry but not escalated into a Sentry Issue.
///
/// This intentionally only matches the typed network/request subtype so that
/// parse regressions, database/cache errors, and other unexpected exceptions
/// keep flowing to Sentry.
bool isExpectedScheduleFetchFailure(Object error) {
  if (error is ServiceRequestFailed) return true;
  if (error is ScheduleQueryFailedException) {
    return error.innerException is ServiceRequestFailed;
  }
  return false;
}
