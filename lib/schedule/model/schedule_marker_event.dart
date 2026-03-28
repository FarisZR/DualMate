import 'package:dualmate/schedule/model/schedule_entry.dart';

class ScheduleMarkerEvent {
  static const String examWeekKeyword = 'klausurwoche';
  static const String theoryPhaseKeyword = 'theoriephase';
  static const String beginKeyword = 'beginn';

  static bool isMarkerEntry(ScheduleEntry entry) {
    if (entry.type != ScheduleEntryType.SpecialEvent &&
        entry.type != ScheduleEntryType.Exam &&
        entry.type != ScheduleEntryType.PublicHoliday) {
      return false;
    }

    if (entry.type == ScheduleEntryType.PublicHoliday) {
      return true;
    }

    return isExamWeekTitle(entry.title) || isTheoryPhaseStartTitle(entry.title);
  }

  static bool isExamWeekTitle(String title) {
    return _normalizeTitle(title).contains(examWeekKeyword);
  }

  static bool isTheoryPhaseStartTitle(String title) {
    var normalized = _normalizeTitle(title);
    return normalized.contains(beginKeyword) &&
        normalized.contains(theoryPhaseKeyword);
  }

  static String _normalizeTitle(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[\s\.-]'), '');
  }
}
