import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'notification identifiers are deterministic, positive and source scoped',
    () {
      final occurrence = DateTime(2026, 7, 20, 9);
      final first = ClassReminderIdentity.notificationId(
        ruleId: 'rule-1',
        occurrenceStart: occurrence,
        sourceIdentity: 'rapla:a',
      );
      final repeat = ClassReminderIdentity.notificationId(
        ruleId: 'rule-1',
        occurrenceStart: occurrence,
        sourceIdentity: 'rapla:a',
      );
      final otherSource = ClassReminderIdentity.notificationId(
        ruleId: 'rule-1',
        occurrenceStart: occurrence,
        sourceIdentity: 'rapla:b',
      );

      expect(first, repeat);
      expect(first, greaterThan(0));
      expect(first, lessThan(1 << 31));
      expect(otherSource, isNot(first));
    },
  );

  test('each occurrence identity input changes the identity', () {
    final start = DateTime(2026, 7, 20, 9);
    final identity = ClassReminderIdentity.occurrence(
      canonicalTitle: 'Recht',
      occurrenceStart: start,
      sourceIdentity: 'rapla:a',
    );
    expect({
      identity,
      ClassReminderIdentity.occurrence(
        canonicalTitle: 'Mathematik',
        occurrenceStart: start,
        sourceIdentity: 'rapla:a',
      ),
      ClassReminderIdentity.occurrence(
        canonicalTitle: 'Recht',
        occurrenceStart: start.add(const Duration(minutes: 1)),
        sourceIdentity: 'rapla:a',
      ),
      ClassReminderIdentity.occurrence(
        canonicalTitle: 'Recht',
        occurrenceStart: start,
        sourceIdentity: 'rapla:b',
      ),
    }, hasLength(4));
  });
}
