import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';

class ScheduleFilter {
  final ScheduleFilterRepository _scheduleFilterRepository;
  final TimetableRepository? timetables;

  ScheduleFilter(this._scheduleFilterRepository, {this.timetables});

  Future<Schedule> filter(Schedule original) async {
    if (timetables != null) {
      final configurations = await timetables!.load();
      final byId = {for (final source in configurations) source.id: source};
      return original.copyWith(
        entries: original.entries.where((entry) {
          final source =
              byId[entry.sourceIdentity] ??
              (entry.sourceIdentity.isEmpty && configurations.isNotEmpty
                  ? configurations.first
                  : null);
          return source != null && source.includes(entry.title);
        }).toList(),
      );
    }
    var allHiddenNames = await _scheduleFilterRepository.queryAllHiddenNames();

    var allEntries = <ScheduleEntry>[];

    for (var entry in original.entries) {
      if (allHiddenNames.contains(entry.title)) {
        continue;
      }

      allEntries.add(entry);
    }

    return original.copyWith(entries: allEntries);
  }
}
