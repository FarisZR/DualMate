import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rule identifiers are deterministic and scope-specific', () {
    final start = DateTime(2026, 7, 20, 9);
    final recurring = ClassReminderIdentity.ruleId(
      scope: ClassReminderScope.recurring,
      canonicalTitle: 'Recht',
      sourceIdentity: 'rapla:a',
    );
    final oneTime = ClassReminderIdentity.ruleId(
      scope: ClassReminderScope.oneTime,
      canonicalTitle: 'Recht',
      sourceIdentity: 'rapla:a',
      occurrenceStart: start,
    );

    expect(
      ClassReminderIdentity.ruleId(
        scope: ClassReminderScope.recurring,
        canonicalTitle: 'Recht',
        sourceIdentity: 'rapla:a',
      ),
      recurring,
    );
    expect(recurring, startsWith('class-reminder-'));
    expect(oneTime, isNot(recurring));
  });

  test(
    'notification identifiers are deterministic, negative and source scoped',
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
      expect(first, lessThan(0));
      expect(first, greaterThanOrEqualTo(-(1 << 31)));
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
