enum ClassReminderScope { oneTime, recurring }

class ClassReminderRule {
  final String id;
  final ClassReminderScope scope;
  final String canonicalTitle;
  final Duration offset;
  final String sourceIdentity;
  final DateTime? occurrenceStart;
  final DateTime? occurrenceEnd;

  const ClassReminderRule({
    required this.id,
    required this.scope,
    required this.canonicalTitle,
    required this.offset,
    required this.sourceIdentity,
    this.occurrenceStart,
    this.occurrenceEnd,
  });

  bool get isOneTime => scope == ClassReminderScope.oneTime;
}

class ScheduledClassNotification {
  final String ruleId;
  final String occurrenceIdentity;
  final String sourceIdentity;
  final int notificationId;
  final DateTime scheduledTime;
  final DateTime classStart;
  final String contentFingerprint;

  const ScheduledClassNotification({
    required this.ruleId,
    required this.occurrenceIdentity,
    required this.sourceIdentity,
    required this.notificationId,
    required this.scheduledTime,
    required this.classStart,
    required this.contentFingerprint,
  });
}

abstract final class ClassReminderIdentity {
  static String occurrence({
    required String canonicalTitle,
    required DateTime occurrenceStart,
    required String sourceIdentity,
  }) =>
      '$sourceIdentity|$canonicalTitle|${occurrenceStart.toUtc().millisecondsSinceEpoch}';

  static int notificationId({
    required String ruleId,
    required DateTime occurrenceStart,
    required String sourceIdentity,
  }) {
    final input =
        '$sourceIdentity|$ruleId|${occurrenceStart.toUtc().millisecondsSinceEpoch}';
    var hash = 0x811c9dc5;
    for (final byte in input.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
