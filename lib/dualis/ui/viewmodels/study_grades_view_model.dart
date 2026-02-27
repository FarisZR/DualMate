import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/common/util/cancelable_mutex.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/credentials.dart';
import 'package:dualmate/dualis/model/module.dart';
import 'package:dualmate/dualis/model/semester.dart';
import 'package:dualmate/dualis/model/study_grades.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';

enum LoginState {
  LoggedOut,
  LoggingIn,
  LoggingOut,
  LoggedIn,
  LoginFailed,
}

class StudyGradesViewModel extends BaseViewModel {
  final DualisService _dualisService;

  final PreferencesProvider _preferencesProvider;

  LoginState _loginState = LoginState.LoggedOut;
  LoginState get loginState => _loginState;

  StudyGrades _studyGrades = StudyGrades(0, 0, 0, 0);
  StudyGrades get studyGrades => _studyGrades;
  final CancelableMutex _studyGradesCancellationToken = CancelableMutex();

  List<Module> _allModules = [];
  List<Module> get allModules => _allModules;
  final CancelableMutex _allModulesCancellationToken = CancelableMutex();

  List<String> _semesterNames = [];
  List<String> get allSemesterNames => _semesterNames;
  final CancelableMutex _semesterNamesCancellationToken = CancelableMutex();

  Semester _currentSemester = Semester("", []);
  Semester get currentSemester => _currentSemester;
  final CancelableMutex _currentSemesterCancellationToken = CancelableMutex();

  String _currentSemesterName = "";
  String get currentSemesterName => _currentSemesterName;

  String _currentLoadingSemesterName = "";

  bool _isLoadingStudyGrades = false;
  bool get isLoadingStudyGrades => _isLoadingStudyGrades;

  bool _isLoadingAllModules = false;
  bool get isLoadingAllModules => _isLoadingAllModules;

  bool _isLoadingSemesterNames = false;
  bool get isLoadingSemesterNames => _isLoadingSemesterNames;

  bool _isLoadingCurrentSemester = false;
  bool get isLoadingCurrentSemester => _isLoadingCurrentSemester;

  StudyGradesViewModel(this._preferencesProvider, this._dualisService);

  Future<bool> login(Credentials credentials) async {
    _loginState = LoginState.LoggingIn;
    notifyListeners("loginState");

    bool success;

    try {
      var result = await _dualisService.login(
        credentials.username,
        credentials.password,
      );

      success = result == LoginResult.LoggedIn;
    } on OperationCancelledException catch (_) {
      success = false;
    }

    _loginState = success ? LoginState.LoggedIn : LoginState.LoginFailed;

    notifyListeners("loginState");

    if (!success) {
      return false;
    }

    loadStudyGrades();
    loadSemesterNames();
    loadAllModules();

    return true;
  }

  Future<void> clearCredentials() async {
    await _preferencesProvider.setStoreDualisCredentials(false);

    // When the schedule source is Dualis the login credentials should not be
    // cleared
    if (await _preferencesProvider.getScheduleSourceType() ==
        ScheduleSourceType.Dualis.index) {
      return;
    }

    await _preferencesProvider.clearDualisCredentials();
  }

  Future<Credentials> loadCredentials() async {
    return await _preferencesProvider.loadDualisCredentials();
  }

  Future<void> saveCredentials(Credentials credentials) async {
    await _preferencesProvider.storeDualisCredentials(credentials);
    await _preferencesProvider.setStoreDualisCredentials(true);
  }

  Future<bool> getDoSaveCredentials() {
    return _preferencesProvider.getStoreDualisCredentials();
  }

  Future<void> loadStudyGrades() async {
    _isLoadingStudyGrades = true;
    notifyListeners("isLoadingStudyGrades");

    await _studyGradesCancellationToken.acquireAndCancelOther();

    try {
      _studyGrades = await _dualisService
          .queryStudyGrades(_studyGradesCancellationToken.token);
    } on OperationCancelledException catch (_) {
    } finally {
      _studyGradesCancellationToken.release();
      _isLoadingStudyGrades = false;
    }

    notifyListeners("studyGrades");
    notifyListeners("isLoadingStudyGrades");
  }

  Future<void> loadAllModules() async {
    _isLoadingAllModules = true;
    notifyListeners("isLoadingAllModules");

    await _allModulesCancellationToken.acquireAndCancelOther();

    try {
      _allModules = await _dualisService.queryAllModules(
        _allModulesCancellationToken.token,
      );
    } on OperationCancelledException catch (_) {
    } finally {
      _allModulesCancellationToken.release();
      _isLoadingAllModules = false;
    }

    notifyListeners("allModules");
    notifyListeners("isLoadingAllModules");
  }

  Future<void> loadSemester(String semesterName) async {
    if (_currentSemesterName == semesterName) return Future.value();

    if (_currentLoadingSemesterName == semesterName) return Future.value();

    await _preferencesProvider.setLastViewedSemester(semesterName);

    _currentLoadingSemesterName = semesterName;
    _currentSemesterName = semesterName;
    _isLoadingCurrentSemester = true;
    _currentSemester = Semester("", []);
    notifyListeners("currentSemesterName");
    notifyListeners("currentSemester");
    notifyListeners("isLoadingCurrentSemester");

    await _currentSemesterCancellationToken.acquireAndCancelOther();

    try {
      _currentSemester = await _dualisService.querySemester(
        semesterName,
        _currentSemesterCancellationToken.token,
      );
    } on OperationCancelledException catch (_) {
    } finally {
      _currentSemesterCancellationToken.release();
      _currentLoadingSemesterName = "";
      _isLoadingCurrentSemester = false;
    }

    notifyListeners("currentSemester");
    notifyListeners("isLoadingCurrentSemester");
  }

  Future<void> loadSemesterNames() async {
    _isLoadingSemesterNames = true;
    notifyListeners("isLoadingSemesterNames");

    await _semesterNamesCancellationToken.acquireAndCancelOther();

    try {
      _semesterNames = await _dualisService.querySemesterNames(
        _semesterNamesCancellationToken.token,
      );
    } on OperationCancelledException catch (_) {
    } finally {
      _semesterNamesCancellationToken.release();
      _isLoadingSemesterNames = false;
    }

    notifyListeners("semesterNames");
    notifyListeners("isLoadingSemesterNames");

    await _loadInitialSemester();
  }

  Future _loadInitialSemester() async {
    if (_semesterNames.isEmpty) return;

    var lastViewedSemester = await _preferencesProvider.getLastViewedSemester();

    if (_semesterNames.contains(lastViewedSemester)) {
      loadSemester(lastViewedSemester);
    } else {
      loadSemester(_semesterNames.first);
    }
  }

  Future<void> logout() async {
    _loginState = LoginState.LoggingOut;
    notifyListeners("loginState");

    _semesterNamesCancellationToken.cancel();
    _currentSemesterCancellationToken.cancel();
    _allModulesCancellationToken.cancel();
    _studyGradesCancellationToken.cancel();

    await _dualisService.logout();

    _loginState = LoginState.LoggedOut;
    _studyGrades = StudyGrades(0, 0, 0, 0);
    _allModules = [];
    _semesterNames = [];
    _currentSemester = Semester("", []);
    _currentSemesterName = "";
    _currentLoadingSemesterName = "";
    _isLoadingStudyGrades = false;
    _isLoadingAllModules = false;
    _isLoadingSemesterNames = false;
    _isLoadingCurrentSemester = false;

    notifyListeners();
  }
}
