import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/study_grades.dart';
import 'package:dualmate/dualis/service/dualis_scraper.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/dualis/service/dualis_website_model.dart';
import 'package:dualmate/dualis/service/fake_account_dualis_scraper_decorator.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo credentials log in and route Dualis reads to fake data', () async {
    final originalScraper = _RecordingDualisScraper();
    final scraper = FakeAccountDualisScraperDecorator(originalScraper);

    final loginResult = await scraper.login(
      FakeAccountDualisScraperDecorator.demoUsername,
      FakeAccountDualisScraperDecorator.demoPassword,
      CancellationToken(),
    );

    expect(loginResult, LoginResult.LoggedIn);
    expect(originalScraper.loginCalls, 0);

    final studyGrades = await scraper.loadStudyGrades(CancellationToken());
    final semesters = await scraper.loadSemesters(CancellationToken());
    final modules = await scraper.loadAllModules(CancellationToken());
    final semesterModules = await scraper.loadSemesterModules(
      'SoSe 2026',
      CancellationToken(),
    );
    final exams = await scraper.loadModuleExams(
      'demo://software-engineering',
      CancellationToken(),
    );

    expect(studyGrades.gpaTotal, 1.7);
    expect(studyGrades.gpaMainModules, 1.8);
    expect(studyGrades.creditsGained, 96);
    expect(semesters.single.semesterName, 'SoSe 2026');
    expect(
      modules.map((module) => module.name),
      contains('Software Engineering'),
    );
    expect(
      semesterModules.map((module) => module.name),
      contains('Datenbanken'),
    );
    expect(exams.map((exam) => exam.name), contains('Klausur'));
    expect(originalScraper.loadStudyGradesCalls, 0);
    expect(originalScraper.loadSemestersCalls, 0);
    expect(originalScraper.loadAllModulesCalls, 0);
    expect(originalScraper.loadSemesterModulesCalls, 0);
    expect(originalScraper.loadModuleExamsCalls, 0);
  });

  test(
    'demo credential matching tolerates leading and trailing whitespace',
    () async {
      final originalScraper = _RecordingDualisScraper();
      final scraper = FakeAccountDualisScraperDecorator(originalScraper);

      final result = await scraper.login(
        ' ${FakeAccountDualisScraperDecorator.demoUsername} ',
        ' ${FakeAccountDualisScraperDecorator.demoPassword} ',
        CancellationToken(),
      );

      expect(result, LoginResult.LoggedIn);
      expect(originalScraper.loginCalls, 0);
    },
  );

  test('non-demo credentials stay on the original Dualis scraper', () async {
    final originalScraper = _RecordingDualisScraper();
    final scraper = FakeAccountDualisScraperDecorator(originalScraper);

    final result = await scraper.login(
      'student@example.com',
      'real-password',
      CancellationToken(),
    );

    expect(result, LoginResult.LoginFailed);
    expect(originalScraper.loginCalls, 1);

    await scraper.loadStudyGrades(CancellationToken());
    expect(originalScraper.loadStudyGradesCalls, 1);
  });

  test(
    'setLoginCredentials selects demo data for previous-credentials login',
    () async {
      final originalScraper = _RecordingDualisScraper();
      final scraper = FakeAccountDualisScraperDecorator(originalScraper);

      scraper.setLoginCredentials(
        FakeAccountDualisScraperDecorator.demoUsername,
        FakeAccountDualisScraperDecorator.demoPassword,
      );

      final result = await scraper.loginWithPreviousCredentials(
        CancellationToken(),
      );
      final modules = await scraper.loadAllModules(CancellationToken());

      expect(result, LoginResult.LoggedIn);
      expect(
        modules.map((module) => module.name),
        contains('Software Engineering'),
      );
      expect(originalScraper.setLoginCredentialsCalls, 0);
      expect(originalScraper.loginWithPreviousCredentialsCalls, 0);
    },
  );

  test('logout clears fake login state', () async {
    final scraper = FakeAccountDualisScraperDecorator(
      _RecordingDualisScraper(),
    );

    await scraper.login(
      FakeAccountDualisScraperDecorator.demoUsername,
      FakeAccountDualisScraperDecorator.demoPassword,
      CancellationToken(),
    );
    expect(scraper.isLoggedIn(), isTrue);

    await scraper.logout(CancellationToken());

    expect(scraper.isLoggedIn(), isFalse);
  });

  test('logout prevents demo restore through previous credentials', () async {
    final originalScraper = _RecordingDualisScraper();
    final scraper = FakeAccountDualisScraperDecorator(originalScraper);

    scraper.setLoginCredentials(
      FakeAccountDualisScraperDecorator.demoUsername,
      FakeAccountDualisScraperDecorator.demoPassword,
    );
    expect(
      await scraper.loginWithPreviousCredentials(CancellationToken()),
      LoginResult.LoggedIn,
    );

    await scraper.logout(CancellationToken());

    expect(
      await scraper.loginWithPreviousCredentials(CancellationToken()),
      LoginResult.LoginFailed,
    );
    expect(originalScraper.loginWithPreviousCredentialsCalls, 1);
  });
}

class _RecordingDualisScraper implements DualisScraper {
  int loginCalls = 0;
  int loginWithPreviousCredentialsCalls = 0;
  int setLoginCredentialsCalls = 0;
  int loadStudyGradesCalls = 0;
  int loadSemestersCalls = 0;
  int loadAllModulesCalls = 0;
  int loadSemesterModulesCalls = 0;
  int loadModuleExamsCalls = 0;

  @override
  bool isLoggedIn() => false;

  @override
  Future<List<DualisModule>> loadAllModules([
    CancellationToken? cancellationToken,
  ]) async {
    loadAllModulesCalls += 1;
    return const <DualisModule>[];
  }

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
  ) async {
    return Schedule.fromList([]);
  }

  @override
  Future<List<DualisModule>> loadSemesterModules(
    String semesterName, [
    CancellationToken? cancellationToken,
  ]) async {
    loadSemesterModulesCalls += 1;
    return const <DualisModule>[];
  }

  @override
  Future<List<DualisSemester>> loadSemesters([
    CancellationToken? cancellationToken,
  ]) async {
    loadSemestersCalls += 1;
    return const <DualisSemester>[];
  }

  @override
  Future<StudyGrades> loadStudyGrades(
    CancellationToken? cancellationToken,
  ) async {
    loadStudyGradesCalls += 1;
    return StudyGrades(0, 0, 0, 0);
  }

  @override
  Future<LoginResult> login(
    String username,
    String password,
    CancellationToken? cancellationToken,
  ) async {
    loginCalls += 1;
    return LoginResult.LoginFailed;
  }

  @override
  Future<LoginResult> loginWithPreviousCredentials(
    CancellationToken? cancellationToken,
  ) async {
    loginWithPreviousCredentialsCalls += 1;
    return LoginResult.LoginFailed;
  }

  @override
  Future<void> logout(CancellationToken? cancellationToken) async {}

  @override
  void setLoginCredentials(String username, String password) {
    setLoginCredentialsCalls += 1;
  }
}
