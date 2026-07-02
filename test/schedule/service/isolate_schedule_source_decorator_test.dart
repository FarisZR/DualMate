import 'package:dualmate/common/logging/diagnostic_exception_filter.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/isolate_schedule_source_decorator.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'preserves suppressible request failures across isolate boundary',
    () async {
      final source = IsolateScheduleSourceDecorator(
        _ThrowingScheduleSource(
          ScheduleQueryFailedException(
            ServiceRequestFailed('Http request failed!'),
          ),
        ),
      );

      Object? caught;
      try {
        await source.querySchedule(DateTime(2026, 2, 9), DateTime(2026, 2, 16));
      } catch (error) {
        caught = error;
      }

      expect(caught, isA<ScheduleQueryFailedException>());
      expect(shouldSuppressDiagnosticsException(caught!), isTrue);
    },
  );
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
