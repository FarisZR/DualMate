import 'package:dualmate/schedule/ui/viewmodels/schedule_update_request_gate.dart';
import 'package:test/test.dart';

void main() {
  test('allows initial request', () {
    final gate = ScheduleUpdateRequestGate(
      minInterval: const Duration(milliseconds: 300),
    );
    final start = DateTime(2026, 1, 27);
    final end = DateTime(2026, 2, 3);
    final now = DateTime(2026, 1, 27, 12, 0, 0, 0);

    expect(gate.shouldAllow(start, end, now), isTrue);
  });

  test('blocks same range within interval', () {
    final gate = ScheduleUpdateRequestGate(
      minInterval: const Duration(milliseconds: 300),
    );
    final start = DateTime(2026, 1, 27);
    final end = DateTime(2026, 2, 3);
    final now = DateTime(2026, 1, 27, 12, 0, 0, 0);

    expect(gate.shouldAllow(start, end, now), isTrue);
    expect(
      gate.shouldAllow(start, end, now.add(const Duration(milliseconds: 150))),
      isFalse,
    );
  });

  test('allows same range after interval', () {
    final gate = ScheduleUpdateRequestGate(
      minInterval: const Duration(milliseconds: 300),
    );
    final start = DateTime(2026, 1, 27);
    final end = DateTime(2026, 2, 3);
    final now = DateTime(2026, 1, 27, 12, 0, 0, 0);

    expect(gate.shouldAllow(start, end, now), isTrue);
    expect(
      gate.shouldAllow(start, end, now.add(const Duration(milliseconds: 400))),
      isTrue,
    );
  });

  test('allows different range within interval', () {
    final gate = ScheduleUpdateRequestGate(
      minInterval: const Duration(milliseconds: 300),
    );
    final start = DateTime(2026, 1, 27);
    final end = DateTime(2026, 2, 3);
    final now = DateTime(2026, 1, 27, 12, 0, 0, 0);

    expect(gate.shouldAllow(start, end, now), isTrue);
    expect(
      gate.shouldAllow(
        start.add(const Duration(days: 7)),
        end.add(const Duration(days: 7)),
        now.add(const Duration(milliseconds: 150)),
      ),
      isTrue,
    );
  });

  test('allows same range within interval when forced', () {
    final gate = ScheduleUpdateRequestGate(
      minInterval: const Duration(milliseconds: 300),
    );
    final start = DateTime(2026, 1, 27);
    final end = DateTime(2026, 2, 3);
    final now = DateTime(2026, 1, 27, 12, 0, 0, 0);

    expect(gate.shouldAllow(start, end, now), isTrue);
    expect(
      gate.shouldAllow(
        start,
        end,
        now.add(const Duration(milliseconds: 150)),
        force: true,
      ),
      isTrue,
    );
  });
}
