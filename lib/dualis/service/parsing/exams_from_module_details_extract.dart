import 'package:dualmate/dualis/model/exam_grade.dart';
import 'package:dualmate/dualis/service/dualis_website_model.dart';
import 'package:dualmate/dualis/service/parsing/parsing_utils.dart';
import 'package:html/parser.dart';

class ExamsFromModuleDetailsExtract {
  List<DualisExam> extractExamsFromModuleDetails(String body) {
    try {
      return _extractExamsFromModuleDetails(body);
    } on ParseException catch (e, trace) {
      if (e.runtimeType is ParseException) rethrow;
      throw ParseException.withInner(e, trace);
    }
  }

  List<DualisExam> _extractExamsFromModuleDetails(String body) {
    var document = parse(body);

    // Dualis sometimes omits <tbody>; fall back to the first table if needed
    var tbodyElements = document.getElementsByTagName("tbody");
    var tableExamsRows = tbodyElements.isNotEmpty
        ? tbodyElements.first.getElementsByTagName("tr")
        : (() {
            var tableElements = document.getElementsByTagName("table");
            if (tableElements.isEmpty) {
              throw ElementNotFoundParseException("tbody");
            }
            // Use rows directly under the table when tbody is missing
            var rows = tableElements.first.getElementsByTagName("tr");
            if (rows.isEmpty) throw ElementNotFoundParseException("tr");
            return rows;
          })();

    var currentTry = "";
    var currentModule = "";

    var exams = <DualisExam>[];

    for (var row in tableExamsRows) {
      // Save the try for all following exams (cell has the class)
      var level01s = row.getElementsByClassName("level01");
      if (level01s.isNotEmpty) {
        final cell = level01s.first;
        currentTry = trimAndEscapeString(
            cell.text.isNotEmpty ? cell.text : cell.innerHtml);
        continue;
      }

      // Save the module for all following exams (cell has the class)
      var level02s = row.getElementsByClassName("level02");
      if (level02s.isNotEmpty) {
        final cell = level02s.first;
        currentModule = trimAndEscapeString(
            cell.text.isNotEmpty ? cell.text : cell.innerHtml);
        continue;
      }

      // All exam rows contain cells with the tbdata class.
      // If there are none continue with the next row
      var tbdata = row.getElementsByClassName("tbdata");
      if (tbdata.length < 4) continue;

      var semester = tbdata[0].innerHtml;
      var name = tbdata[1].innerHtml;
      var grade = trimAndEscapeString(tbdata[3].innerHtml);

      exams.add(DualisExam(
        trimAndEscapeString(name),
        trimAndEscapeString(currentModule),
        ExamGrade.fromString(grade),
        trimAndEscapeString(currentTry),
        trimAndEscapeString(semester),
      ));
    }

    return exams;
  }
}
