import 'dart:async';

import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/common/util/cancelable_mutex.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/credentials.dart';
import 'package:dualmate/dualis/model/module.dart';
import 'package:dualmate/dualis/model/semester.dart';
import 'package:dualmate/dualis/model/study_grades.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:flutter/foundation.dart';

enum LoginState {
  Initializing,
  LoggedOut,
  LoggingIn,
  RestoringSession,
  LoggingOut,
  LoggedIn,
  LoginFailed,
}

class StudyGradesViewModel extends BaseViewModel {
  static const Duration _staleRefreshDuration = Duration(hours: 6);

  final DualisService _dualisService;

  final PreferencesProvider _preferencesProvider;

  LoginState _loginState = LoginState.Initializing;
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

  int _studyGradesLoadEpoch = 0;
  int _allModulesLoadEpoch = 0;
  int _semesterNamesLoadEpoch = 0;
  int _currentSemesterLoadEpoch = 0;
  bool _pageActivationInFlight = false;
  bool _refreshInFlight = false;
  bool _autoRestoreSuppressed = false;

  StudyGradesViewModel(this._preferencesProvider, this._dualisService);

  Future<bool> login(Credentials credentials) async {
    _autoRestoreSuppressed = false;
    return _loginWithCredentials(
      credentials,
      inProgressState: LoginState.LoggingIn,
      failureState: LoginState.LoginFailed,
    );
  }

  Future<void> onPageVisible() async {
    if (_pageActivationInFlight || isDisposed) {
      return;
    }

    await PerformanceTelemetry.instance.measureTask(
      'dualis.open',
      args: {'sourceType': 'unknown'},
      action: (_) async {
        _pageActivationInFlight = true;
        try {
          if (_loginState == LoginState.LoggedIn) {
            if (await _isRefreshStale()) {
              await refreshData(force: true);
            }
            return;
          }

          if (_loginState == LoginState.LoggingIn ||
              _loginState == LoginState.LoggingOut ||
              _loginState == LoginState.RestoringSession) {
            return;
          }

          await restoreSessionIfPossible();
        } finally {
          _pageActivationInFlight = false;
        }
      },
    );
  }

  Future<bool> restoreSessionIfPossible() async {
    if (_autoRestoreSuppressed) {
      _loginState = LoginState.LoggedOut;
      notifyListeners("loginState");
      return false;
    }

    final credentials = await _preferencesProvider.loadDualisCredentials();
    if (credentials.username.isEmpty || credentials.password.isEmpty) {
      _loginState = LoginState.LoggedOut;
      notifyListeners("loginState");
      return false;
    }

    return _loginWithCredentials(
      credentials,
      inProgressState: LoginState.RestoringSession,
      failureState: LoginState.LoggedOut,
    );
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
    final epoch = ++_studyGradesLoadEpoch;
    _isLoadingStudyGrades = true;
    notifyListeners("isLoadingStudyGrades");

    await _studyGradesCancellationToken.acquireAndCancelOther();
    if (epoch != _studyGradesLoadEpoch) {
      _studyGradesCancellationToken.release();
      return;
    }

    try {
      final loadedStudyGrades = await PerformanceTelemetry.instance.measureTask(
        'dualis.results.parse',
        args: {'sourceType': 'unknown'},
        action: (task) async {
          final grades = await _dualisService.queryStudyGrades(
            _studyGradesCancellationToken.token,
          );
          task.setData('loadedEntryCount', 1);
          return grades;
        },
      );
      _applyDualisState(() {
        _studyGrades = loadedStudyGrades;
      });
    } on OperationCancelledException catch (_) {
    } finally {
      _studyGradesCancellationToken.release();
      if (epoch != _studyGradesLoadEpoch) {
        return;
      }
      _isLoadingStudyGrades = false;
    }

    notifyListeners("studyGrades");
    notifyListeners("isLoadingStudyGrades");
  }

  Future<void> loadAllModules() async {
    final epoch = ++_allModulesLoadEpoch;
    _isLoadingAllModules = true;
    notifyListeners("isLoadingAllModules");

    await _allModulesCancellationToken.acquireAndCancelOther();
    if (epoch != _allModulesLoadEpoch) {
      _allModulesCancellationToken.release();
      return;
    }

    try {
      final loadedModules = await PerformanceTelemetry.instance.measureTask(
        'dualis.results.parse',
        args: {'sourceType': 'unknown'},
        action: (task) async {
          final modules = await _dualisService.queryAllModules(
            _allModulesCancellationToken.token,
          );
          task.setData('loadedEntryCount', modules.length);
          return modules;
        },
      );
      _applyDualisState(() {
        _allModules = loadedModules;
      });
    } on OperationCancelledException catch (_) {
    } finally {
      _allModulesCancellationToken.release();
      if (epoch != _allModulesLoadEpoch) {
        return;
      }
      _isLoadingAllModules = false;
    }

    notifyListeners("allModules");
    notifyListeners("isLoadingAllModules");
  }

  Future<void> loadSemester(String semesterName) async {
    await loadSemesterByName(semesterName);
  }

  Future<void> loadSemesterByName(
    String semesterName, {
    bool force = false,
  }) async {
    if (!force && _currentSemesterName == semesterName) {
      return Future.value();
    }

    if (_currentLoadingSemesterName == semesterName) return Future.value();

    await _preferencesProvider.setLastViewedSemester(semesterName);

    final epoch = ++_currentSemesterLoadEpoch;
    _currentLoadingSemesterName = semesterName;
    _currentSemesterName = semesterName;
    _isLoadingCurrentSemester = true;
    _currentSemester = Semester("", []);
    notifyListeners("currentSemesterName");
    notifyListeners("currentSemester");
    notifyListeners("isLoadingCurrentSemester");

    await _currentSemesterCancellationToken.acquireAndCancelOther();
    if (epoch != _currentSemesterLoadEpoch) {
      _currentSemesterCancellationToken.release();
      return;
    }

    try {
      final loadedSemester = await PerformanceTelemetry.instance.measureTask(
        'dualis.results.parse',
        args: {'sourceType': 'unknown'},
        action: (task) async {
          final semester = await _dualisService.querySemester(
            semesterName,
            _currentSemesterCancellationToken.token,
          );
          task.setData('loadedEntryCount', semester.modules.length);
          return semester;
        },
      );
      _applyDualisState(() {
        _currentSemester = loadedSemester;
      });
    } on OperationCancelledException catch (_) {
    } finally {
      _currentSemesterCancellationToken.release();
      if (epoch != _currentSemesterLoadEpoch) {
        return;
      }
      _currentLoadingSemesterName = "";
      _isLoadingCurrentSemester = false;
    }

    notifyListeners("currentSemester");
    notifyListeners("isLoadingCurrentSemester");
  }

  Future<void> loadSemesterNames() async {
    await loadSemesterNamesForCurrentSelection();
  }

  Future<void> loadSemesterNamesForCurrentSelection({
    String? preferredSemesterName,
    bool forceCurrentSemesterReload = false,
  }) async {
    final epoch = ++_semesterNamesLoadEpoch;
    _isLoadingSemesterNames = true;
    notifyListeners("isLoadingSemesterNames");

    await _semesterNamesCancellationToken.acquireAndCancelOther();
    if (epoch != _semesterNamesLoadEpoch) {
      _semesterNamesCancellationToken.release();
      return;
    }

    try {
      final loadedSemesterNames = await PerformanceTelemetry.instance
          .measureTask(
            'dualis.results.parse',
            args: {'sourceType': 'unknown'},
            action: (task) async {
              final semesterNames = await _dualisService.querySemesterNames(
                _semesterNamesCancellationToken.token,
              );
              task.setData('loadedEntryCount', semesterNames.length);
              return semesterNames;
            },
          );
      _applyDualisState(() {
        _semesterNames = loadedSemesterNames;
      });
    } on OperationCancelledException catch (_) {
    } finally {
      _semesterNamesCancellationToken.release();
      if (epoch != _semesterNamesLoadEpoch) {
        return;
      }
      _isLoadingSemesterNames = false;
    }

    notifyListeners("semesterNames");
    notifyListeners("isLoadingSemesterNames");

    if (epoch == _semesterNamesLoadEpoch) {
      await _loadInitialSemester(
        preferredSemesterName: preferredSemesterName,
        force: forceCurrentSemesterReload,
      );
    }
  }

  Future<void> refreshData({bool force = false}) async {
    if (_loginState != LoginState.LoggedIn || _refreshInFlight) {
      return;
    }

    _refreshInFlight = true;
    try {
      if (force) {
        _dualisService.clearCache();
      }

      final preferredSemesterName = _currentSemesterName;
      await Future.wait<void>([
        loadStudyGrades(),
        loadAllModules(),
        loadSemesterNamesForCurrentSelection(
          preferredSemesterName: preferredSemesterName,
          forceCurrentSemesterReload: preferredSemesterName.isNotEmpty,
        ),
      ]);

      await _preferencesProvider.setDualisLastRefreshAt(DateTime.now());
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _loadInitialSemester({
    String? preferredSemesterName,
    bool force = false,
  }) async {
    if (_semesterNames.isEmpty) return;

    var requestedSemester = preferredSemesterName ?? _currentSemesterName;
    if (requestedSemester.isNotEmpty &&
        _semesterNames.contains(requestedSemester)) {
      await loadSemesterByName(requestedSemester, force: force);
      return;
    }

    var lastViewedSemester = await _preferencesProvider.getLastViewedSemester();

    if (_semesterNames.contains(lastViewedSemester)) {
      await loadSemesterByName(lastViewedSemester, force: force);
    } else {
      await loadSemesterByName(_semesterNames.first, force: force);
    }
  }

  Future<void> logout() async {
    _autoRestoreSuppressed = true;
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

  Future<bool> _loginWithCredentials(
    Credentials credentials, {
    required LoginState inProgressState,
    required LoginState failureState,
  }) async {
    _loginState = inProgressState;
    notifyListeners("loginState");

    bool success;

    try {
      var result = await PerformanceTelemetry.instance.measureTask(
        'dualis.login.request',
        args: {'sourceType': 'unknown'},
        action: (task) async {
          final loginResult = await _dualisService.login(
            credentials.username,
            credentials.password,
          );
          task.setData(
            'status',
            loginResult == LoginResult.LoggedIn ? 'success' : 'network_error',
          );
          return loginResult;
        },
      );

      success = result == LoginResult.LoggedIn;
    } on OperationCancelledException catch (_) {
      success = false;
    } catch (_) {
      success = false;
    }

    _loginState = success ? LoginState.LoggedIn : failureState;

    notifyListeners("loginState");

    if (!success) {
      return false;
    }

    unawaited(refreshData(force: true));
    return true;
  }

  void _applyDualisState(VoidCallback action) {
    PerformanceTelemetry.instance.measureSync(
      'dualis.state.apply',
      args: {'sourceType': 'unknown'},
      action: (_) {
        action();
      },
    );
  }

  Future<bool> _isRefreshStale() async {
    final lastRefreshAt = await _preferencesProvider.getDualisLastRefreshAt();
    if (lastRefreshAt == null) {
      return true;
    }

    return DateTime.now().difference(lastRefreshAt) >= _staleRefreshDuration;
  }
}
