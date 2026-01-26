import 'package:dualmate/dualis/service/parsing/parsing_utils.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';

class MonthlyScheduleExtract {
  Schedule extractScheduleFromMonthly(String body) {
    try {
      return _extractScheduleFromMonthly(body);
    } catch (e, trace) {
      if (e.runtimeType is ParseException) rethrow;
      throw ParseException.withInner(e, trace);
    }
  }

  Schedule _extractScheduleFromMonthly(String body) {
    var document = parse(body);

    var appointments = document.getElementsByClassName("apmntLink");

    var allEntries = <ScheduleEntry>[];

    for (var appointment in appointments) {
      var entry = _extractEntry(appointment);

      if (entry != null) {
        allEntries.add(entry);
      }
    }

    allEntries.sort(
      (ScheduleEntry e1, ScheduleEntry e2) => e1.start.compareTo(e2.start),
    );

    return Schedule.fromList(allEntries);
  }

  ScheduleEntry? _extractEntry(Element appointment) {
    var date = appointment.parent
        ?.parent
        ?.querySelector(".tbsubhead a")
        ?.attributes["title"];

    var information = appointment.attributes["title"];
    if (date == null || information == null) return null;

    var informationParts = information.split(" / ");
    if (informationParts.length < 3) return null;

    var startAndEnd = informationParts[0].split(" - ");
    if (startAndEnd.length < 2) return null;

    var start = "$date ${startAndEnd[0]}";
    var end = "$date ${startAndEnd[1]}";
    var room = informationParts[1];
    var title = informationParts[2];

    var dateFormat = DateFormat("dd.MM.yyyy HH:mm");
    var startDate = dateFormat.parse(start);
    var endDate = dateFormat.parse(end);

    var entry = ScheduleEntry(
      title: title,
      professor: "",
      details: "",
      room: room,
      type: ScheduleEntryType.Class,
      start: startDate,
      end: endDate,
    );

    return entry;
  }
}
