import 'package:dualmate/common/logging/diagnostic_exception_filter.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/isolate_schedule_source_decorator.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancels a worker even when the source does not cooperate', () async {
    final source = IsolateScheduleSourceDecorator(_WaitingSource());
    final token = CancellationToken();
    final pending = source.querySchedule(DateTime(2026), DateTime(2027), token);
    final expectation = expectLater(
      pending,
      throwsA(isA<OperationCancelledException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    token.cancel();
    await expectation;
  });

  test('concurrent queries have independent worker lifetimes', () async {
    final source = IsolateScheduleSourceDecorator(
      _ThrowingScheduleSource(ServiceRequestFailed('offline')),
    );
    await Future.wait(
      List.generate(
        3,
        (_) => expectLater(
          source.querySchedule(DateTime(2026), DateTime(2027)),
          throwsA(isA<ScheduleQueryFailedException>()),
        ),
      ),
    );
  });
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

class _WaitingSource extends ScheduleSource {
  @override
  bool canQuery() => true;
  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? token,
  ]) async {
    await Future<void>.delayed(const Duration(days: 1));
    throw StateError('Should have cancelled the worker');
  }
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
