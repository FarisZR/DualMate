import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/foundation.dart';

/// Immutable render-facing state for the currently visible schedule week.
///
/// Schedule is intentionally mutable for the cache and database layers. The
/// weekly page, however, only needs a stable value to decide whether a visible
/// render actually changed. Keeping a copied entry sequence here lets the
/// view-model suppress equivalent cache results without relying on Schedule
/// identity.
@immutable
class VisibleWeeklyScheduleSnapshot {
  final int version;
  final DateTime weekStart;
  final DateTime weekEnd;
  final DateTime displayStart;
  final DateTime displayEnd;
  final int displayStartHour;
  final int displayEndHour;
  final List<ScheduleEntry> entries;

  VisibleWeeklyScheduleSnapshot({
    required this.version,
    required this.weekStart,
    required this.weekEnd,
    required this.displayStart,
    required this.displayEnd,
    required this.displayStartHour,
    required this.displayEndHour,
    required Iterable<ScheduleEntry> entries,
  }) : entries = List<ScheduleEntry>.unmodifiable(entries);

  VisibleWeeklyScheduleSnapshot withVersion(int nextVersion) {
    return VisibleWeeklyScheduleSnapshot(
      version: nextVersion,
      weekStart: weekStart,
      weekEnd: weekEnd,
      displayStart: displayStart,
      displayEnd: displayEnd,
      displayStartHour: displayStartHour,
      displayEndHour: displayEndHour,
      entries: entries,
    );
  }

  bool hasSameVisibleContent(VisibleWeeklyScheduleSnapshot other) {
    if (weekStart != other.weekStart ||
        weekEnd != other.weekEnd ||
        displayStart != other.displayStart ||
        displayEnd != other.displayEnd ||
        displayStartHour != other.displayStartHour ||
        displayEndHour != other.displayEndHour ||
        entries.length != other.entries.length) {
      return false;
    }

    for (var index = 0; index < entries.length; index++) {
      if (!_hasSameVisibleEntry(entries[index], other.entries[index])) {
        return false;
      }
    }
    return true;
  }

  static bool _hasSameVisibleEntry(ScheduleEntry first, ScheduleEntry second) {
    return first.start == second.start &&
        first.end == second.end &&
        first.title == second.title &&
        first.details == second.details &&
        first.professor == second.professor &&
        first.room == second.room &&
        first.type == second.type;
  }

  static VisibleWeeklyScheduleSnapshot fromSchedule({
    required int version,
    required DateTime weekStart,
    required DateTime weekEnd,
    required DateTime displayStart,
    required DateTime displayEnd,
    required int displayStartHour,
    required int displayEndHour,
    required Schedule? schedule,
  }) {
    return VisibleWeeklyScheduleSnapshot(
      version: version,
      weekStart: weekStart,
      weekEnd: weekEnd,
      displayStart: displayStart,
      displayEnd: displayEnd,
      displayStartHour: displayStartHour,
      displayEndHour: displayEndHour,
      entries: schedule?.entries ?? const <ScheduleEntry>[],
    );
  }
}
