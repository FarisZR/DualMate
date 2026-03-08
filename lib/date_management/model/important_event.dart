import 'package:dualmate/schedule/model/schedule_entry.dart';

class ImportantEvent {
  final String title;
  final DateTime start;
  final DateTime end;
  final String professor;
  final ScheduleEntryType type;

  ImportantEvent({
    required this.title,
    required this.start,
    required this.end,
    this.professor = '',
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
      type: type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'professor': professor,
      'type': type.index,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ImportantEvent &&
        other.title == title &&
        other.start == start &&
        other.end == end &&
        other.professor == professor &&
        other.type == type;
  }

  @override
  int get hashCode {
    return title.hashCode ^
        start.hashCode ^
        end.hashCode ^
        professor.hashCode ^
        type.hashCode;
  }
}
