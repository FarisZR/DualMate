import 'package:dualmate/common/logging/crash_reporting.dart'
    as crash_reporting;
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/error_report_schedule_source_decorator.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late crash_reporting.ExceptionReporter originalReporter;
  late List<Object> reportedErrors;

  setUp(() {
    originalReporter = crash_reporting.reportExceptionImpl;
    reportedErrors = <Object>[];
    crash_reporting.reportExceptionImpl = (error, trace) async {
      reportedErrors.add(error);
    };
  });

  tearDown(() {
    crash_reporting.reportExceptionImpl = originalReporter;
  });

  test('rethrows connectivity query failures without reporting', () async {
    final source = ErrorReportScheduleSourceDecorator(
      _ThrowingScheduleSource(
        ScheduleQueryFailedException(
          ServiceRequestFailed('Http request failed!'),
        ),
      ),
    );

    await expectLater(
      source.querySchedule(DateTime(2026, 2, 9), DateTime(2026, 2, 16)),
      throwsA(isA<ScheduleQueryFailedException>()),
    );

    expect(reportedErrors, isEmpty);
  });

  test('reports parser query failures before rethrowing', () async {
    final failure = ScheduleQueryFailedException(
      FormatException('Invalid time format'),
    );
    final source = ErrorReportScheduleSourceDecorator(
      _ThrowingScheduleSource(failure),
    );

    await expectLater(
      source.querySchedule(DateTime(2026, 2, 9), DateTime(2026, 2, 16)),
      throwsA(same(failure)),
    );

    expect(reportedErrors, <Object>[failure]);
  });
}

class _ThrowingScheduleSource extends ScheduleSource {
  final Object error;

  _ThrowingScheduleSource(this.error);

  @override
  bool canQuery() => true;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    throw error;
  }
}
