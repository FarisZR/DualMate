import 'package:dualmate/schedule/ui/viewmodels/schedule_freshness_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns stale before any fetch', () {
    final gate = ScheduleFreshnessGate(
      staleAfter: const Duration(minutes: 30),
    );
    final start = DateTime(2026, 1, 27);
    final end = DateTime(2026, 2, 3);
    final now = DateTime(2026, 1, 27, 12, 0, 0);

    expect(gate.isStale(start, end, now), isTrue);
  });

  test('returns fresh for same range within window', () {
    final gate = ScheduleFreshnessGate(
      staleAfter: const Duration(minutes: 30),
    );
    final start = DateTime(2026, 1, 27);
    final end = DateTime(2026, 2, 3);
    final now = DateTime(2026, 1, 27, 12, 0, 0);

    gate.markFetched(start, end, now);
    expect(
      gate.isStale(start, end, now.add(const Duration(minutes: 10))),
      isFalse,
    );
  });

  test('returns stale for same range after window', () {
    final gate = ScheduleFreshnessGate(
      staleAfter: const Duration(minutes: 30),
    );
    final start = DateTime(2026, 1, 27);
    final end = DateTime(2026, 2, 3);
    final now = DateTime(2026, 1, 27, 12, 0, 0);

    gate.markFetched(start, end, now);
    expect(
      gate.isStale(start, end, now.add(const Duration(minutes: 45))),
      isTrue,
    );
  });

  test('returns stale for different range even within window', () {
    final gate = ScheduleFreshnessGate(
      staleAfter: const Duration(minutes: 30),
    );
    final start = DateTime(2026, 1, 27);
    final end = DateTime(2026, 2, 3);
    final now = DateTime(2026, 1, 27, 12, 0, 0);

    gate.markFetched(start, end, now);
    expect(
      gate.isStale(
        start.add(const Duration(days: 7)),
        end.add(const Duration(days: 7)),
        now.add(const Duration(minutes: 10)),
      ),
      isTrue,
    );
  });
}
