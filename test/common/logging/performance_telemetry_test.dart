import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('measureTask falls back when success status callback throws', () async {
    final result = await PerformanceTelemetry.instance.measureTask<int>(
      'schedule.remote.fetch',
      successStatus: 'success',
      successStatusForResult: (_) => throw StateError('bad status callback'),
      action: (_) => 42,
    );

    expect(result, 42);
  });

  test('statusForError classifies FormatException as parse_error', () {
    expect(
      PerformanceTelemetry.statusForError(const FormatException('bad payload')),
      'parse_error',
    );
  });
}
