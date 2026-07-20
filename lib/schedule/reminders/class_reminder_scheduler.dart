class ClassReminderNotificationRequest {
  final int notificationId;
  final String className;
  final DateTime classStart;
  final DateTime scheduledTime;
  final Duration offset;
  final String room;
  final String occurrenceIdentity;

  const ClassReminderNotificationRequest({
    required this.notificationId,
    required this.className,
    required this.classStart,
    required this.scheduledTime,
    required this.offset,
    required this.room,
    required this.occurrenceIdentity,
  });
}

abstract interface class ClassReminderScheduler {
  Future<void> schedule(ClassReminderNotificationRequest request);

  Future<void> cancel(int notificationId);
}
