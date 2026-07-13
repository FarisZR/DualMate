import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/exam.dart';
import 'package:dualmate/dualis/model/exam_grade.dart';
import 'package:dualmate/dualis/model/study_grades.dart';
import 'package:dualmate/dualis/service/dualis_scraper.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/dualis/service/dualis_website_model.dart';
import 'package:dualmate/dualis/service/fake_account_dualis_scraper_decorator.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'semester query pins one scraper when decorator selection changes mid-query',
    () async {
      final originalScraper = _RecordingOriginalScraper();
      late FakeAccountDualisScraperDecorator decorator;
      final selectedScraper = _SwitchingSelectedScraper(
        onSemesterModulesLoaded: () {
          decorator.setLoginCredentials('student@example.com', 'real-password');
        },
      );
      decorator = FakeAccountDualisScraperDecorator(
        originalScraper,
        fakeDualisScraper: selectedScraper,
      );
      final service = DualisServiceImpl(decorator);

      expect(
        await decorator.login(
          FakeAccountDualisScraperDecorator.demoUsername,
          FakeAccountDualisScraperDecorator.demoPassword,
          CancellationToken(),
        ),
        LoginResult.LoggedIn,
      );

      final semesterFuture = service.querySemester('SoSe 2026');
      final semester = await semesterFuture;

      expect(semester.modules, isNotEmpty);
      expect(selectedScraper.loadModuleExamsCalls, 1);
      expect(originalScraper.loadModuleExamsCalls, 0);
    },
  );
}

class _SwitchingSelectedScraper implements DualisScraper {
  final void Function() onSemesterModulesLoaded;
  int loadModuleExamsCalls = 0;
  bool _isLoggedIn = false;

  _SwitchingSelectedScraper({required this.onSemesterModulesLoaded});

  @override
  bool isLoggedIn() => _isLoggedIn;

  @override
  Future<List<DualisModule>> loadAllModules([
    CancellationToken? cancellationToken,
  ]) async => const <DualisModule>[];

  @override
  Future<List<DualisExam>> loadModuleExams(
    String moduleDetailsUrl, [
    CancellationToken? cancellationToken,
  ]) async {
    loadModuleExamsCalls += 1;
    return <DualisExam>[
      DualisExam(
        'Klausur',
        'Software Engineering',
        ExamGrade.graded('1.7'),
        '1',
        'SoSe 2026',
      ),
    ];
  }

  @override
  Future<Schedule> loadMonthlySchedule(
    DateTime dateInMonth,
    CancellationToken? cancellationToken,
  ) async => Schedule.fromList([]);

  @override
  Future<List<DualisModule>> loadSemesterModules(
    String semesterName, [
    CancellationToken? cancellationToken,
  ]) async {
    onSemesterModulesLoaded();
    return <DualisModule>[
      DualisModule(
        'T3INF1001',
        'Software Engineering',
        '1.7',
        '5',
        ExamState.Passed,
        'demo://software-engineering',
      ),
    ];
  }

  @override
  Future<List<DualisSemester>> loadSemesters([
    CancellationToken? cancellationToken,
  ]) async => const <DualisSemester>[];

  @override
  Future<StudyGrades> loadStudyGrades([
    CancellationToken? cancellationToken,
  ]) async => StudyGrades(0, 0, 0, 0);

  @override
  Future<LoginResult> login(
    String username,
    String password,
    CancellationToken? cancellationToken,
  ) async {
    _isLoggedIn = true;
    return LoginResult.LoggedIn;
  }

  @override
  Future<LoginResult> loginWithPreviousCredentials(
    CancellationToken? cancellationToken,
  ) async {
    _isLoggedIn = true;
    return LoginResult.LoggedIn;
  }

  @override
  Future<void> logout(CancellationToken? cancellationToken) async {
    _isLoggedIn = false;
  }

  @override
  void setLoginCredentials(String username, String password) {}
}

class _RecordingOriginalScraper implements DualisScraper {
  int loadModuleExamsCalls = 0;

  @override
  bool isLoggedIn() => false;

  @override
  Future<List<DualisModule>> loadAllModules([
    CancellationToken? cancellationToken,
  ]) async => const <DualisModule>[];

  @override
  Future<List<DualisExam>> loadModuleExams(
    String moduleDetailsUrl, [
    CancellationToken? cancellationToken,
  ]) async {
    loadModuleExamsCalls += 1;
    return const <DualisExam>[];
  }

  @override
  Future<Schedule> loadMonthlySchedule(
    DateTime dateInMonth,
    CancellationToken? cancellationToken,
  ) async => Schedule.fromList([]);

  @override
  Future<List<DualisModule>> loadSemesterModules(
    String semesterName, [
    CancellationToken? cancellationToken,
  ]) async => const <DualisModule>[];

  @override
  Future<List<DualisSemester>> loadSemesters([
    CancellationToken? cancellationToken,
  ]) async => const <DualisSemester>[];

  @override
  Future<StudyGrades> loadStudyGrades(
    CancellationToken? cancellationToken,
  ) async => StudyGrades(0, 0, 0, 0);

  @override
  Future<LoginResult> login(
    String username,
    String password,
    CancellationToken? cancellationToken,
  ) async => LoginResult.LoginFailed;

  @override
  Future<LoginResult> loginWithPreviousCredentials(
    CancellationToken? cancellationToken,
  ) async => LoginResult.LoginFailed;

  @override
  Future<void> logout(CancellationToken? cancellationToken) async {}

  @override
  void setLoginCredentials(String username, String password) {}
}
