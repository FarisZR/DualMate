import 'package:dhbwstudentapp/schedule/model/schedule.dart';
import 'package:dhbwstudentapp/schedule/model/schedule_entry.dart';
import 'package:dhbwstudentapp/schedule/model/schedule_query_result.dart';
import 'package:dhbwstudentapp/schedule/service/rapla/rapla_parsing_utils.dart';
import 'package:html/dom.dart';

///
/// Implements the parsing of the rapla service when the response is a month
/// table
///
class RaplaMonthlyResponseParser {
  static ScheduleQueryResult parseMonthlyTable(
    Element monthTable,
  ) {
    var title = monthTable.parent?.getElementsByClassName("title") ?? [];
    if (title.isEmpty) {
      return ScheduleQueryResult(
        Schedule.fromList([]),
        [ParseError("Missing month title", StackTrace.current)],
      );
    }

    var monthAndYear = title[0].text;
    var yearString = monthAndYear.split(" ")[1];
    var year = int.tryParse(yearString);
    var month = _monthStringToDateTime(monthAndYear);

    if (year == null || month == null) {
      return ScheduleQueryResult(
        Schedule.fromList([]),
        [ParseError("Invalid month/year", StackTrace.current)],
      );
    }

    var dayCells = monthTable.getElementsByClassName("month_cell");

    var allEntries = <ScheduleEntry>[];
    var parseErrors = <ParseError>[];

    for (var dayCell in dayCells) {
      var dayNumber = dayCell.getElementsByTagName("div");
      var dayEntries = dayCell.getElementsByClassName("month_block");

      if (dayNumber.isEmpty || dayEntries.isEmpty) continue;

      var dayNumberString = dayNumber[0].text;
      var day = int.tryParse(dayNumberString);
      if (day == null) continue;

      for (var dayEntry in dayEntries) {
        try {
          var entry = RaplaParsingUtils.extractScheduleEntryOrThrow(
            dayEntry,
            DateTime(year, month, day),
          );

          allEntries.add(entry);
        } catch (exception, trace) {
          parseErrors.add(ParseError(exception, trace));
        }
      }
    }

    return ScheduleQueryResult(Schedule.fromList(allEntries), parseErrors);
  }

  static int? _monthStringToDateTime(String monthAndYear) {
    var monthString = monthAndYear.split(" ")[0];
    var monthNames = {
      "Januar": DateTime.january,
      "Februar": DateTime.february,
      "März": DateTime.march,
      "April": DateTime.april,
      "Mai": DateTime.may,
      "Juni": DateTime.june,
      "Juli": DateTime.july,
      "August": DateTime.august,
      "September": DateTime.september,
      "Oktober": DateTime.october,
      "November": DateTime.november,
      "Dezember": DateTime.december,
    };

    return monthNames[monthString];
  }
}
