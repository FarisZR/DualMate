import 'package:dhbwstudentapp/common/util/string_utils.dart';
import 'package:dhbwstudentapp/dualis/service/parsing/parsing_utils.dart';
import 'package:dhbwstudentapp/schedule/model/schedule_entry.dart';
import 'package:html/dom.dart';
import 'package:intl/intl.dart';

class RaplaParsingUtils {
  static const String WEEK_BLOCK_CLASS = "week_block";
  static const String TOOLTIP_CLASS = "tooltip";
  static const String INFOTABLE_CLASS = "infotable";
  static const String RESOURCE_CLASS = "resource";
  static const String LABEL_CLASS = "label";
  static const String VALUE_CLASS = "value";
  static const String STYLE_ATTRIBUTE = "style";
  static const String CLASS_NAME_LABEL = "Veranstaltungsname:";
  static const String CLASS_NAME_LABEL_ALTERNATIVE = "Name:";
  static const String CLASS_TITLE_LABEL = "Titel:";
  static const String PROFESSOR_NAME_LABEL = "Personen:";
  static const String DETAILS_LABEL = "Bemerkung:";
  static const String RESOURCES_LABEL = "Ressourcen:";

  static const String colorExam = "#ff0000";
  static const String colorExamAlt = "#e2001a";
  static const String colorSpecialEvent = "#c0e2ff";
  static const String colorSpecialEventAlt = "#a3ddff";
  static const String colorPublicHoliday = "#cccccc";
  static const String colorPublicHolidayAlt = "#ee61ff";

  static const Map<String, ScheduleEntryType> entryTypeMapping = {
    "Feiertag": ScheduleEntryType.PublicHoliday,
    "Online-Format (ohne Raumbelegung)": ScheduleEntryType.Online,
    "Vorlesung / Lehrbetrieb": ScheduleEntryType.Class,
    "Lehrveranstaltung": ScheduleEntryType.Class,
    "Klausur / Prüfung": ScheduleEntryType.Exam,
    "Prüfung": ScheduleEntryType.Exam,
    "Pruefung": ScheduleEntryType.Exam
  };

  static ScheduleEntry extractScheduleEntryOrThrow(
      Element value, DateTime date) {
    // The tooltip tag contains the most relevant information
    var tooltip = value.getElementsByClassName(TOOLTIP_CLASS);

    // The only reliable way to extract the time
    var timeAndClassName = value.getElementsByTagName("a");

    if (timeAndClassName.isEmpty)
      throw ElementNotFoundParseException("time and date container");

    var descriptionInCell = timeAndClassName[0].text;

    var start = _parseTime(descriptionInCell.substring(0, 5), date);
    var end = _parseTime(descriptionInCell.substring(7, 12), date);

    if (start == null || end == null) {
      throw ParseException.withInner("Invalid time format", StackTrace.current);
    }

    // The important information is stored in a html element called tooltip.
    // Depending on the Rapla configuration the tooltip is available or not.
    // When there is no tooltip fallback to extract the available information
    // From the cell itself.
    // TODO: Display a warning that information is not extracted from the
    //       tooltip. Then provide a link with a manual to activate it in Rapla
    if (tooltip.isEmpty) {
      var scheduleEntry =
          extractScheduleDetailsFromCell(timeAndClassName, start, end);
      return improveScheduleEntry(scheduleEntry);
    } else {
      var scheduleEntry =
          extractScheduleFromTooltip(tooltip, value, start, end);
      return improveScheduleEntry(scheduleEntry);
    }
  }

  static ScheduleEntry improveScheduleEntry(ScheduleEntry scheduleEntry) {
    var professor = scheduleEntry.professor;
    if (professor.endsWith(",")) {
      scheduleEntry = scheduleEntry.copyWith(
          professor: professor.substring(0, professor.length - 1));
    }

    return scheduleEntry.copyWith(
      title: trimAndEscapeString(scheduleEntry.title),
      details: trimAndEscapeString(scheduleEntry.details),
      professor: trimAndEscapeString(scheduleEntry.professor),
      room: trimAndEscapeString(scheduleEntry.room),
    );
  }

  static ScheduleEntry extractScheduleFromTooltip(
      List<Element> tooltip,
      Element value,
      DateTime start,
      DateTime end) {
    var infotable = tooltip[0].getElementsByClassName(INFOTABLE_CLASS);

    if (infotable.isEmpty) {
      throw ElementNotFoundParseException("infotable container");
    }

    Map<String, String> properties = _parsePropertiesTable(infotable[0]);
    var type = _extractEntryType(tooltip, value);
    var title = properties[CLASS_NAME_LABEL] ??
        properties[CLASS_TITLE_LABEL] ??
        properties[CLASS_NAME_LABEL_ALTERNATIVE] ??
        "";

    var professor = properties[PROFESSOR_NAME_LABEL] ?? "";
    var details = properties[DETAILS_LABEL] ?? "";
    var resource = properties[RESOURCES_LABEL] ?? _extractResources(value);

    var scheduleEntry = ScheduleEntry(
      start: start,
      end: end,
      title: title,
      details: details,
      professor: professor,
      type: type,
      room: resource,
    );
    return scheduleEntry;
  }

  static ScheduleEntry extractScheduleDetailsFromCell(
      List<Element> timeAndClassName,
      DateTime start,
      DateTime end) {
    var descriptionHtml = timeAndClassName[0].innerHtml.substring(12);
    var descriptionParts = descriptionHtml.split("<br>");

    var title = "";
    var details = "";

    if (descriptionParts.length == 1) {
      title = descriptionParts[0];
    } else if (descriptionParts.length > 0) {
      title = descriptionParts[1];
      details = descriptionParts.join("\n");
    }

    var scheduleEntry = ScheduleEntry(
      start: start,
      end: end,
      title: title,
      details: details,
      professor: "",
      type: ScheduleEntryType.Unknown,
      room: "",
    );
    return scheduleEntry;
  }

  static ScheduleEntryType _extractEntryType(
    List<Element> tooltip,
    Element value,
  ) {
    if (tooltip.isEmpty) return ScheduleEntryType.Unknown;

    var strongTag = tooltip[0].getElementsByTagName("strong");
    if (strongTag.isEmpty) return ScheduleEntryType.Unknown;

    var typeString = strongTag[0].innerHtml;
    if (typeString == "Sonstiger Termin") {
      return _mapSpecialEventType(value.attributes[STYLE_ATTRIBUTE]);
    }

    if (typeString == "Lehrveranstaltung" ||
        typeString == "Vorlesung / Lehrbetrieb") {
      return _mapClassType(value.attributes[STYLE_ATTRIBUTE], typeString);
    }

    return entryTypeMapping[typeString] ?? ScheduleEntryType.Unknown;
  }

  static ScheduleEntryType _mapSpecialEventType(String? style) {
    var backgroundColor = _extractBackgroundColor(style);
    if (backgroundColor == null) return ScheduleEntryType.Unknown;

    switch (backgroundColor) {
      case colorExam:
      case colorExamAlt:
        return ScheduleEntryType.Exam;
      case colorSpecialEvent:
      case colorSpecialEventAlt:
        return ScheduleEntryType.SpecialEvent;
      case colorPublicHoliday:
      case colorPublicHolidayAlt:
        return ScheduleEntryType.PublicHoliday;
      default:
        return ScheduleEntryType.Unknown;
    }
  }

  static ScheduleEntryType _mapClassType(String? style, String fallbackType) {
    var backgroundColor = _extractBackgroundColor(style);
    if (backgroundColor == null) {
      return entryTypeMapping[fallbackType] ?? ScheduleEntryType.Class;
    }

    switch (backgroundColor) {
      case colorExam:
      case colorExamAlt:
        return ScheduleEntryType.Exam;
      case colorPublicHoliday:
      case colorPublicHolidayAlt:
        return ScheduleEntryType.PublicHoliday;
      default:
        return entryTypeMapping[fallbackType] ?? ScheduleEntryType.Class;
    }
  }

  static String? _extractBackgroundColor(String? style) {
    if (style == null || style.isEmpty) return null;

    var styleParts = style.split(";");
    for (var part in styleParts) {
      var trimmed = part.trim();
      if (!trimmed.startsWith("background-color")) continue;

      var colorParts = trimmed.split(":");
      if (colorParts.length < 2) continue;

      return colorParts[1].trim().toLowerCase();
    }

    return null;
  }

  static Map<String, String> _parsePropertiesTable(Element infotable) {
    var map = <String, String>{};
    var labels = infotable.getElementsByClassName(LABEL_CLASS);
    var values = infotable.getElementsByClassName(VALUE_CLASS);

    for (var i = 0; i < labels.length; i++) {
      map[labels[i].innerHtml] =
          i < values.length ? values[i].innerHtml : "";
    }
    return map;
  }

  static DateTime? _parseTime(String timeString, DateTime date) {
    try {
      var time = DateFormat("HH:mm").parse(timeString.substring(0, 5));
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    } catch (e) {
      return null;
    }
  }

  static String _extractResources(Element value) {
    var resources = value.getElementsByClassName(RESOURCE_CLASS);

    var resourcesList = <String>[];
    for (var resource in resources) {
      resourcesList.add(resource.innerHtml);
    }

    return concatStringList(resourcesList, ", ");
  }

  static String readYearOrThrow(Document document) {
    // The only reliable way to read the year of this schedule is to parse the
    // selected year in the date selector
    var comboBoxes = document.getElementsByTagName("select");

    String year = "";
    for (var box in comboBoxes) {
      if (box.attributes.containsKey("name") &&
          box.attributes["name"] == "year") {
        var entries = box.getElementsByTagName("option");

        for (var entry in entries) {
          if (entry.attributes.containsKey("selected") &&
              entry.attributes["selected"] == "") {
            year = entry.text;

            break;
          }
        }

        break;
      }
    }

    if (year.isEmpty) {
      throw ElementNotFoundParseException("year selector");
    }
    return year;
  }
}
