import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/reminders/canonical_class_name.dart';

class SchedulePrettifier {
  Schedule prettifySchedule(Schedule schedule) {
    var allEntries = <ScheduleEntry>[];

    for (var entry in schedule.entries) {
      allEntries.add(prettifyScheduleEntry(entry));
    }

    return schedule.copyWith(entries: allEntries);
  }

  ScheduleEntry prettifyScheduleEntry(ScheduleEntry entry) {
    entry = _removeCourseFromTitle(entry);
    entry = _removeOnlinePrefix(entry);

    return entry;
  }

  ScheduleEntry _removeOnlinePrefix(ScheduleEntry entry) {
    // Sometimes the entry type is not set correctly. When the title of a class
    // begins with "Online - " it implies that it is online
    // In this case remove the online prefix and set the type correctly

    final withoutMarker = CanonicalClassName.removeOnlineMarker(entry.title);
    final newTitle = withoutMarker.trim();

    if (withoutMarker == entry.title) {
      return entry;
    }

    var type = ScheduleEntryType.Online;

    return entry.copyWith(title: newTitle, type: type);
  }

  ScheduleEntry _removeCourseFromTitle(ScheduleEntry entry) {
    var title = entry.title;
    var details = entry.details;

    final prefix = CanonicalClassName.courseCodePrefix(title);
    if (prefix == null) return entry;
    final normalizedPrefix = prefix.replaceFirst(RegExp(r'\s*-\s*$'), '');
    details = details.trim().isEmpty
        ? normalizedPrefix
        : '$normalizedPrefix - $details';
    title = CanonicalClassName.removeCourseCodePrefix(title).trim();

    return entry.copyWith(title: title, details: details);
  }
}
