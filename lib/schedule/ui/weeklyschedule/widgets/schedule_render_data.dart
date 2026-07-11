import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_entry_alignment.dart';
import 'package:flutter/foundation.dart';

/// Immutable, viewport-independent layout data for one rendered schedule week.
///
/// Preparing overlap columns requires grouping and sorting every schedule entry.
/// Keeping that work separate from viewport geometry lets hour-range animations
/// reuse the same result for every frame.
class ScheduleRenderData {
  final Schedule schedule;
  final DateTime displayStart;
  final DateTime displayEnd;
  final int displayedDays;
  final List<List<PreparedScheduleEntry>> entriesByDay;

  @visibleForTesting
  static VoidCallback? debugOnPrepare;

  ScheduleRenderData._({
    required this.schedule,
    required this.displayStart,
    required this.displayEnd,
    required this.displayedDays,
    required this.entriesByDay,
  });

  factory ScheduleRenderData.prepare({
    required Schedule schedule,
    required DateTime displayStart,
    required DateTime displayEnd,
  }) {
    assert(() {
      debugOnPrepare?.call();
      return true;
    }());

    final normalizedStart = toStartOfDay(displayStart);
    final normalizedEnd = toStartOfDay(displayEnd);
    var days = normalizedEnd.difference(normalizedStart).inDays + 1;
    days = days.clamp(5, 7);

    final entriesByDay = <List<PreparedScheduleEntry>>[];
    var dayStart = normalizedStart;
    for (var dayIndex = 0; dayIndex < days; dayIndex++) {
      final dayEnd = tomorrow(dayStart);
      final entries = schedule.entries
          .where((entry) {
            return entry.start.isBefore(dayEnd) && entry.end.isAfter(dayStart);
          })
          .toList(growable: false);
      final aligned = ScheduleEntryAlignmentAlgorithm().layoutEntries(entries);
      entriesByDay.add(
        List<PreparedScheduleEntry>.unmodifiable(
          aligned.map(
            (value) => PreparedScheduleEntry(
              entry: value.entry,
              leftColumn: value.leftColumn,
              rightColumn: value.rightColumn,
            ),
          ),
        ),
      );
      dayStart = dayEnd;
    }

    return ScheduleRenderData._(
      schedule: schedule,
      displayStart: displayStart,
      displayEnd: displayEnd,
      displayedDays: days,
      entriesByDay: List<List<PreparedScheduleEntry>>.unmodifiable(
        entriesByDay,
      ),
    );
  }

  bool matches({
    required Schedule schedule,
    required DateTime displayStart,
    required DateTime displayEnd,
  }) {
    return identical(this.schedule, schedule) &&
        this.displayStart == displayStart &&
        this.displayEnd == displayEnd;
  }
}

class PreparedScheduleEntry {
  final ScheduleEntry entry;
  final double leftColumn;
  final double rightColumn;

  const PreparedScheduleEntry({
    required this.entry,
    required this.leftColumn,
    required this.rightColumn,
  });
}

@immutable
class ScheduleViewport {
  final double startHour;
  final double endHour;

  const ScheduleViewport({required this.startHour, required this.endHour});

  static ScheduleViewport lerp(
    ScheduleViewport begin,
    ScheduleViewport end,
    double t,
  ) {
    return ScheduleViewport(
      startHour: begin.startHour + ((end.startHour - begin.startHour) * t),
      endHour: begin.endHour + ((end.endHour - begin.endHour) * t),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ScheduleViewport &&
            other.startHour == startHour &&
            other.endHour == endHour;
  }

  @override
  int get hashCode => Object.hash(startHour, endHour);
}
