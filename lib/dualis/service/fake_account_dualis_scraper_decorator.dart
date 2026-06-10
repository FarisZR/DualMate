import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/study_grades.dart';
import 'package:dualmate/dualis/service/dualis_scraper.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/dualis/service/dualis_website_model.dart';
import 'package:dualmate/dualis/service/fake_data_dualis_scraper.dart';
import 'package:dualmate/schedule/model/schedule.dart';

///
/// This DualisScraper decorator allows to enter specific fake account
/// information in order to get beyond the Dualis login without having a
/// dualis account.
/// Background: The Google Play review process needs login credentials to every
/// restricted area of the app.
///
class FakeAccountDualisScraperDecorator implements DualisScraper {
  static const String demoUsername = "review@dualmate.app";
  static const String demoPassword = "DualisDemo2026!";

  final DualisScraper _fakeDualisScraper = FakeDataDualisScraper();
  final DualisScraper _originalDualisScraper;

  late DualisScraper _currentDualisScraper;

  FakeAccountDualisScraperDecorator(this._originalDualisScraper) {
    _currentDualisScraper = _originalDualisScraper;
  }

  @override
  bool isLoggedIn() {
    return _currentDualisScraper.isLoggedIn();
  }

  @override
  Future<List<DualisModule>> loadAllModules([
    CancellationToken? cancellationToken,
  ]) {
    return _currentDualisScraper.loadAllModules(
      cancellationToken ?? CancellationToken(),
    );
  }

  @override
  Future<List<DualisExam>> loadModuleExams(
    String moduleDetailsUrl, [
    CancellationToken? cancellationToken,
  ]) {
    return _currentDualisScraper.loadModuleExams(
      moduleDetailsUrl,
      cancellationToken ?? CancellationToken(),
    );
  }

  @override
  Future<Schedule> loadMonthlySchedule(
    DateTime dateInMonth,
    CancellationToken? cancellationToken,
  ) {
    return _currentDualisScraper.loadMonthlySchedule(
      dateInMonth,
      cancellationToken ?? CancellationToken(),
    );
  }

  @override
  Future<List<DualisModule>> loadSemesterModules(
    String semesterName, [
    CancellationToken? cancellationToken,
  ]) {
    return _currentDualisScraper.loadSemesterModules(
      semesterName,
      cancellationToken ?? CancellationToken(),
    );
  }

  @override
  Future<List<DualisSemester>> loadSemesters([
    CancellationToken? cancellationToken,
  ]) {
    return _currentDualisScraper.loadSemesters(
      cancellationToken ?? CancellationToken(),
    );
  }

  @override
  Future<StudyGrades> loadStudyGrades(CancellationToken? cancellationToken) {
    return _currentDualisScraper.loadStudyGrades(
      cancellationToken ?? CancellationToken(),
    );
  }

  @override
  Future<LoginResult> login(
    String username,
    String password,
    CancellationToken? cancellationToken,
  ) {
    if (_isDemoAccount(username, password)) {
      _currentDualisScraper = _fakeDualisScraper;
    } else {
      _currentDualisScraper = _originalDualisScraper;
    }
    return _currentDualisScraper.login(
      username,
      password,
      cancellationToken ?? CancellationToken(),
    );
  }

  @override
  Future<LoginResult> loginWithPreviousCredentials(
    CancellationToken? cancellationToken,
  ) {
    return _currentDualisScraper.loginWithPreviousCredentials(
      cancellationToken ?? CancellationToken(),
    );
  }

  @override
  Future<void> logout(CancellationToken? cancellationToken) async {
    try {
      await _currentDualisScraper.logout(
        cancellationToken ?? CancellationToken(),
      );
    } finally {
      _currentDualisScraper = _originalDualisScraper;
    }
  }

  @override
  void setLoginCredentials(String username, String password) {
    if (_isDemoAccount(username, password)) {
      _currentDualisScraper = _fakeDualisScraper;
    } else {
      _currentDualisScraper = _originalDualisScraper;
    }

    return _currentDualisScraper.setLoginCredentials(username, password);
  }

  bool _isDemoAccount(String username, String password) {
    return username.trim() == demoUsername && password.trim() == demoPassword;
  }
}
