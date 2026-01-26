import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';

///
/// Parses an ICAL file extracts all schedule entries
///
class IcalParser {
  /// Matches a calendar entry. The first group contains the text between
  /// the BEGIN:VEVENT and END:VEVENT
  final String calendarEntryRegex = "BEGIN:VEVENT(.*?)END:VEVENT";

  /// Matches a property in the form of:
  /// KEY:Value
  /// or:
  /// DTSTAMP;VALUE=DATE-TIME:20201008T000006Z
  final String propertyRegex = r"([^;:\n\r\s]+)(;[^:]*)?:(.*)";

  /// Matches the date time format:
  /// YYYYMMDDTHHmmss
  final String dateTimeRegex =
      "([0-9]{4})([0-9]{2})([0-9]{2})T([0-9]{2})([0-9]{2})([0-9]{2})(Z?)";

  ScheduleQueryResult parseIcal(String icalData) {
    var regex = RegExp(
      calendarEntryRegex,
      multiLine: true,
      unicode: true,
      dotAll: true,
    );

    var matches = regex.allMatches(icalData);

    List<ScheduleEntry> entries = [];

    for (var match in matches) {
      var rawEntry = match.group(1);
      if (rawEntry == null) continue;
      var entry = _parseEntry(rawEntry);
      if (entry != null) {
        entries.add(entry);
      }
    }

    return ScheduleQueryResult(
      Schedule.fromList(entries),
      [],
    );
  }

  ScheduleEntry? _parseEntry(String entryData) {
    var allProperties = RegExp(
      propertyRegex,
      unicode: true,
    ).allMatches(entryData);

    Map<String, String> properties = {};

    for (var property in allProperties) {
      var key = property.group(1);
      if (key == null) continue;
      properties[key] = property.group(3) ?? "";
    }

    var start = _parseDate(properties["DTSTART"]);
    var end = _parseDate(properties["DTEND"]);
    if (start == null || end == null) return null;

    return ScheduleEntry(
      start: start,
      end: end,
      room: properties["LOCATION"] ?? "",
      title: properties["SUMMARY"] ?? "",
      type: ScheduleEntryType.Class,
      details: properties["DESCRIPTION"] ?? "",
      professor: "",
    );
  }

  DateTime? _parseDate(String? date) {
    var match = RegExp(
      dateTimeRegex,
      unicode: true,
    ).firstMatch(date ?? "");

    if (match == null) {
      return null;
    }

    var year = int.tryParse(match.group(1) ?? "");
    var month = int.tryParse(match.group(2) ?? "");
    var day = int.tryParse(match.group(3) ?? "");
    var hour = int.tryParse(match.group(4) ?? "");
    var minute = int.tryParse(match.group(5) ?? "");
    var second = int.tryParse(match.group(6) ?? "");

    if ([year, month, day, hour, minute, second].contains(null)) {
      return null;
    }

    return DateTime(
      year!,
      month!,
      day!,
      hour!,
      minute!,
      second!,
    );
  }
}
