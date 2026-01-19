import 'package:dhbwstudentapp/common/util/cancellation_token.dart';
import 'package:dhbwstudentapp/dualis/model/study_grades.dart';
import 'package:dhbwstudentapp/dualis/service/dualis_scraper.dart';
import 'package:dhbwstudentapp/dualis/service/dualis_service.dart';
import 'package:dhbwstudentapp/dualis/service/dualis_website_model.dart';
import 'package:dhbwstudentapp/dualis/service/fake_data_dualis_scraper.dart';
import 'package:dhbwstudentapp/schedule/model/schedule.dart';

///
/// This DualisScraper decorator allows to enter specific fake account
/// information in order to get beyond the Dualis login without having a
/// dualis account.
/// Background: The AppStore review process needs login credentials to every
/// area of the app.
///
class FakeAccountDualisScraperDecorator implements DualisScraper {
  final fakeUsername = "fakeAccount@domain.de";
  final fakePassword = "Passw0rd";

  final DualisScraper _fakeDualisScraper = FakeDataDualisScraper();
  final DualisScraper _originalDualisScraper;

  late DualisScraper _currentDualisScraper;

  FakeAccountDualisScraperDecorator(
    this._originalDualisScraper,
  ) {
    _currentDualisScraper = _originalDualisScraper;
  }

  @override
  bool isLoggedIn() {
    return _currentDualisScraper.isLoggedIn();
  }

  @override
  Future<List<DualisModule>> loadAllModules(
      [CancellationToken? cancellationToken]) {
    return _currentDualisScraper
        .loadAllModules(cancellationToken ?? CancellationToken());
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
  Future<List<DualisSemester>> loadSemesters(
      [CancellationToken? cancellationToken]) {
    return _currentDualisScraper
        .loadSemesters(cancellationToken ?? CancellationToken());
  }

  @override
  Future<StudyGrades> loadStudyGrades(CancellationToken? cancellationToken) {
    return _currentDualisScraper
        .loadStudyGrades(cancellationToken ?? CancellationToken());
  }

  @override
  Future<LoginResult> login(
    String username,
    String password,
    CancellationToken? cancellationToken,
  ) {
    if (username == fakeUsername && password == fakePassword) {
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
      CancellationToken? cancellationToken) {
    return _currentDualisScraper.loginWithPreviousCredentials(
      cancellationToken ?? CancellationToken(),
    );
  }

  @override
  Future<void> logout(CancellationToken? cancellationToken) {
    return _currentDualisScraper.logout(
      cancellationToken ?? CancellationToken(),
    );
  }

  @override
  void setLoginCredentials(String username, String password) {
    if (username == fakeUsername && password == fakePassword) {
      _currentDualisScraper = _fakeDualisScraper;
    } else {
      _currentDualisScraper = _originalDualisScraper;
    }

    return _currentDualisScraper.setLoginCredentials(
      username,
      password,
    );
  }
}
