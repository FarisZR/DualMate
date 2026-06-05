import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/exam.dart';
import 'package:dualmate/dualis/model/exam_grade.dart';
import 'package:dualmate/dualis/model/study_grades.dart';
import 'package:dualmate/dualis/service/dualis_scraper.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/dualis/service/dualis_website_model.dart';
import 'package:dualmate/schedule/model/schedule.dart';

///
/// DualisScraper implementation which returns fake data
///
class FakeDataDualisScraper implements DualisScraper {
  bool _isLoggedIn = false;

  @override
  bool isLoggedIn() {
    return _isLoggedIn;
  }

  @override
  Future<List<DualisModule>> loadAllModules([
    CancellationToken? cancellationToken,
  ]) async {
    await Future.delayed(Duration(milliseconds: 200));

    return Future.value([
      DualisModule(
        "T3INF1001",
        "Software Engineering",
        "1.7",
        "5",
        ExamState.Passed,
        "demo://software-engineering",
      ),
      DualisModule(
        "T3INF1002",
        "Datenbanken",
        "2.0",
        "5",
        ExamState.Passed,
        "demo://databases",
      ),
      DualisModule(
        "T3INF1003",
        "Mathematik",
        "",
        "5",
        ExamState.Pending,
        "demo://mathematics",
      ),
    ]);
  }

  @override
  Future<List<DualisExam>> loadModuleExams(
    String moduleDetailsUrl, [
    CancellationToken? cancellationToken,
  ]) async {
    await Future.delayed(Duration(milliseconds: 200));
    return Future.value([
      DualisExam(
        "Klausur",
        "Software Engineering",
        ExamGrade.graded("1.7"),
        "1",
        "SoSe 2026",
      ),
      DualisExam(
        "Projektarbeit",
        "Software Engineering",
        ExamGrade.passed(),
        "1",
        "SoSe 2026",
      ),
    ]);
  }

  @override
  Future<Schedule> loadMonthlySchedule(
    DateTime dateInMonth,
    CancellationToken? cancellationToken,
  ) async {
    await Future.delayed(Duration(milliseconds: 200));
    return Future.value(Schedule.fromList([]));
  }

  @override
  Future<List<DualisModule>> loadSemesterModules(
    String semesterName, [
    CancellationToken? cancellationToken,
  ]) async {
    await Future.delayed(Duration(milliseconds: 200));
    return Future.value([
      DualisModule(
        "T3INF1001",
        "Software Engineering",
        "1.7",
        "5",
        ExamState.Passed,
        "demo://software-engineering",
      ),
      DualisModule(
        "T3INF1002",
        "Datenbanken",
        "2.0",
        "5",
        ExamState.Passed,
        "demo://databases",
      ),
    ]);
  }

  @override
  Future<List<DualisSemester>> loadSemesters([
    CancellationToken? cancellationToken,
  ]) async {
    await Future.delayed(Duration(milliseconds: 200));
    return Future.value([
      DualisSemester("SoSe 2026", "demo://semester/sose-2026", []),
    ]);
  }

  @override
  Future<StudyGrades> loadStudyGrades(
    CancellationToken? cancellationToken,
  ) async {
    await Future.delayed(Duration(milliseconds: 200));
    return Future.value(StudyGrades(1.7, 1.8, 210, 96));
  }

  @override
  Future<LoginResult> login(
    String username,
    String password,
    CancellationToken? cancellationToken,
  ) async {
    await Future.delayed(Duration(milliseconds: 200));
    _isLoggedIn = true;
    return Future.value(LoginResult.LoggedIn);
  }

  @override
  Future<LoginResult> loginWithPreviousCredentials(
    CancellationToken? cancellationToken,
  ) async {
    await Future.delayed(Duration(milliseconds: 200));
    _isLoggedIn = true;
    return Future.value(LoginResult.LoggedIn);
  }

  @override
  Future<void> logout(CancellationToken? cancellationToken) async {
    await Future.delayed(Duration(milliseconds: 200));
    _isLoggedIn = false;
  }

  @override
  void setLoginCredentials(String username, String password) {}
}
