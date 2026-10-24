import 'package:dualmate/common/util/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final sunday in [
    DateTime(2026, 3, 29, 12),
    DateTime(2026, 10, 25, 12),
  ]) {
    test('week start preserves wall-clock time across DST: $sunday', () {
      expect(
        toMonday(sunday),
        DateTime(sunday.year, sunday.month, sunday.day - 6, 12),
      );
    });
  }

  test('calendar arithmetic preserves UTC and subsecond precision', () {
    final date = DateTime.utc(2026, 10, 24, 12, 30, 45, 123, 456);
    expect(addDays(date, 2), DateTime.utc(2026, 10, 26, 12, 30, 45, 123, 456));
    expect(toMonday(date), DateTime.utc(2026, 10, 19, 12, 30, 45, 123, 456));
  });
}
