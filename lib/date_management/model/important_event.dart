import 'package:dualmate/schedule/model/schedule_entry.dart';

class ImportantEvent {
  final String title;
  final DateTime start;
  final DateTime end;
  final String professor;
  final String details;
  final String room;
  final ScheduleEntryType type;

  ImportantEvent({
    required this.title,
    required this.start,
    required this.end,
    this.professor = '',
    this.details = '',
    this.room = '',
    required this.type,
  });

  bool get isSingleDay => _isSameDay(start, end);

  int get durationDays {
    var startDate = DateTime(start.year, start.month, start.day);
    var endDate = DateTime(end.year, end.month, end.day);
    return endDate.difference(startDate).inDays + 1;
  }

  bool get hasTime =>
      start.hour != 0 || start.minute != 0 || end.hour != 0 || end.minute != 0;

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  factory ImportantEvent.fromJson(Map<String, dynamic> json) {
    var typeIndex = json['type'] as int?;
    var type = ScheduleEntryType.Unknown;
    if (typeIndex != null &&
        typeIndex >= 0 &&
        typeIndex < ScheduleEntryType.values.length) {
      type = ScheduleEntryType.values[typeIndex];
    }

    var startText = json['start'] as String? ?? '';
    var endText = json['end'] as String? ?? '';
    var start =
        DateTime.tryParse(startText) ?? DateTime.fromMillisecondsSinceEpoch(0);
    var end = DateTime.tryParse(endText) ?? start;

    return ImportantEvent(
      title: json['title'] as String? ?? '',
      start: start,
      end: end,
      professor: json['professor'] as String? ?? '',
      details: json['details'] as String? ?? '',
      room: json['room'] as String? ?? '',
      type: type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'professor': professor,
      'details': details,
      'room': room,
      'type': type.index,
    };
  }

  ScheduleEntry toScheduleEntry() {
    return ScheduleEntry(
      start: start,
      end: end,
      title: title,
      details: details,
      professor: professor,
      room: room,
      type: type,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ImportantEvent &&
        other.title == title &&
        other.start == start &&
        other.end == end &&
        other.professor == professor &&
        other.details == details &&
        other.room == room &&
        other.type == type;
  }

  @override
  int get hashCode =>
      Object.hash(title, start, end, professor, details, room, type);
}
