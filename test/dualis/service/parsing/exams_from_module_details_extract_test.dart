import 'dart:io';

import 'package:dualmate/dualis/service/parsing/exams_from_module_details_extract.dart';
import 'package:dualmate/dualis/model/exam_grade.dart';
import 'package:dualmate/dualis/service/parsing/parsing_utils.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main() async {
  var moduleDetailsPage = await File(Directory.current.absolute.path +
          '/test/dualis/service/parsing/html_resources/module_details.html')
      .readAsString();

  test('ExamsFromModuleDetailsExtract', () async {
    var extract = ExamsFromModuleDetailsExtract();

    var exams = extract.extractExamsFromModuleDetails(moduleDetailsPage);

    expect(exams.length, 2);

    expect(exams[0].name, "Klausurarbeit (50%)");
    expect(exams[0].semester, "WiSe xx/yy");
    expect(exams[0].grade.gradeValue, "4,0");
    expect(exams[0].grade.state, ExamGradeState.Graded);
    expect(exams[0].moduleName, "T3INF1001.1 Lineare Algebra (STG-TINF19IN)");
    expect(exams[0].tryNr, "Versuch  1");

    expect(exams[1].grade.gradeValue, "");
    expect(exams[1].grade.state, ExamGradeState.NotGraded);
  });

  test('ExamsFromModuleDetailsExtract invalid html throws exception', () async {
    var extract = ExamsFromModuleDetailsExtract();

    try {
      extract.extractExamsFromModuleDetails("Lorem ipsum");
    } on ParseException {
      return;
    }

    fail("Exception not thrown!");
  });

  test('ExamsFromModuleDetailsExtract handles missing tbody gracefully',
      () async {
    var extract = ExamsFromModuleDetailsExtract();

    final html = """
      <html><body>
        <table>
          <tr><td class='level01'>Versuch  1</td></tr>
          <tr><td class='level02'>Module A</td></tr>
          <tr>
            <td class='tbdata'>WiSe xx/yy</td>
            <td class='tbdata'>Exam X</td>
            <td class='tbdata'>ignored</td>
            <td class='tbdata'>4,0</td>
          </tr>
        </table>
      </body></html>
    """;

    final exams = extract.extractExamsFromModuleDetails(html);

    expect(exams.length, 1);
    expect(exams.first.name, "Exam X");
    expect(exams.first.semester, "WiSe xx/yy");
    expect(exams.first.moduleName, "Module A");
    expect(exams.first.tryNr, "Versuch  1");
  });
}
