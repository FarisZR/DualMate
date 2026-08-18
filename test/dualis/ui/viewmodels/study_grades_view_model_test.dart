import 'dart:async';

import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/credentials.dart';
import 'package:dualmate/dualis/model/module.dart';
import 'package:dualmate/dualis/model/semester.dart';
import 'package:dualmate/dualis/model/study_grades.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/dualis/ui/viewmodels/study_grades_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('login falls back to LoginFailed on unexpected service errors',
      () async {
    final service = _StudyGradesTestService(
      loginThrows: true,
      blockFirstModulesRequest: false,
    );
    final viewModel = StudyGradesViewModel(_buildPreferences(), service);
    addTearDown(viewModel.dispose);

    final success = await viewModel.login(Credentials('u', 'p'));

    expect(success, isFalse);
    expect(viewModel.loginState, LoginState.LoginFailed);
  });

  test('loadAllModules keeps loading=true for the newest in-flight request',
      () async {
    final service = _StudyGradesTestService();
    final viewModel = StudyGradesViewModel(_buildPreferences(), service);
    addTearDown(viewModel.dispose);

    unawaited(viewModel.loadAllModules());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(viewModel.isLoadingAllModules, isTrue);

    unawaited(viewModel.loadAllModules());
    await service.secondModulesRequestStarted.future;
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(viewModel.isLoadingAllModules, isTrue);

    service.releaseSecondModulesRequest();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(viewModel.isLoadingAllModules, isFalse);
  });

  test('restores the Dualis session from saved credentials on page open',
      () async {
    final preferences = _buildPreferences();
    await preferences.storeDualisCredentials(Credentials('saved-user', 'saved-pass'));
    final service = _StudyGradesTestService(blockFirstModulesRequest: false);
    final viewModel = StudyGradesViewModel(preferences, service);
    addTearDown(viewModel.dispose);

    final success = await viewModel.restoreSessionIfPossible();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(success, isTrue);
    expect(service.loginCalls, 1);
    expect(service.lastLoginUsername, 'saved-user');
    expect(service.lastLoginPassword, 'saved-pass');
    expect(viewModel.loginState, LoginState.LoggedIn);
    expect(service.clearCacheCalls, 1);
  });

  test('refreshData(force: true) clears cached Dualis data before reloading',
      () async {
    final preferences = _buildPreferences();
    final service = _StudyGradesTestService(blockFirstModulesRequest: false);
    final viewModel = StudyGradesViewModel(preferences, service);
    addTearDown(viewModel.dispose);

    final success = await viewModel.login(Credentials('u', 'p'));
    expect(success, isTrue);

    await _waitForDualisRefresh(preferences);

    service.resetCallCounters();

    await viewModel.refreshData(force: true);

    expect(service.clearCacheCalls, 1);
    expect(service.queryStudyGradesCalls, 1);
    expect(service.queryAllModulesCalls, 1);
    expect(service.querySemesterNamesCalls, 1);
  });

  test('refreshData completes and clears GPA loading when grades fail',
      () async {
    final preferences = _buildPreferences();
    final service = _StudyGradesTestService(blockFirstModulesRequest: false);
    service.studyGradesResult = StudyGrades(1.7, 1.8, 210, 96);
    final viewModel = StudyGradesViewModel(preferences, service);
    addTearDown(viewModel.dispose);

    expect(await viewModel.login(Credentials('u', 'p')), isTrue);
    await _waitForDualisRefresh(preferences);
    final lastSuccessfulRefreshAt =
        await preferences.getDualisLastRefreshAt();

    service.studyGradesThrows = true;
    service.resetCallCounters();

    await expectLater(viewModel.refreshData(force: true), completes);

    expect(viewModel.isLoadingStudyGrades, isFalse);
    expect(service.queryStudyGradesCalls, 1);
    expect(service.queryAllModulesCalls, 1);
    expect(service.querySemesterNamesCalls, 1);
    expect(viewModel.studyGrades.gpaTotal, 1.7);
    expect(viewModel.studyGrades.gpaMainModules, 1.8);
    expect(viewModel.studyGrades.creditsTotal, 210);
    expect(viewModel.studyGrades.creditsGained, 96);
    expect(
      await preferences.getDualisLastRefreshAt(),
      lastSuccessfulRefreshAt,
    );
  });

  test('login refresh keeps the three Dualis branches concurrent', () async {
    final preferences = _buildPreferences();
    final service = _ParallelRefreshService();
    final viewModel = StudyGradesViewModel(preferences, service);
    addTearDown(viewModel.dispose);

    expect(await viewModel.login(Credentials('u', 'p')), isTrue);

    await Future.wait<void>([
      service.studyGradesStarted.future,
      service.allModulesStarted.future,
      service.semesterNamesStarted.future,
    ]).timeout(const Duration(seconds: 2));

    expect(service.maximumConcurrentQueries, 3);

    service.releaseQueries();
    await _waitForDualisRefresh(preferences);
  });
}

Future<void> _waitForDualisRefresh(PreferencesProvider preferences) async {
  await Future.doWhile(() async {
    if (await preferences.getDualisLastRefreshAt() != null) {
      return false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return true;
  }).timeout(const Duration(seconds: 2));
}

PreferencesProvider _buildPreferences() {
  return PreferencesProvider(
    _FakePreferencesAccess(),
    _FakeSecureStorageAccess(),
  );
}

class _StudyGradesTestService extends DualisService {
  final bool loginThrows;
  final bool blockFirstModulesRequest;
  int _allModulesCallCount = 0;
  int loginCalls = 0;
  int clearCacheCalls = 0;
  int queryStudyGradesCalls = 0;
  int queryAllModulesCalls = 0;
  int querySemesterNamesCalls = 0;
  int querySemesterCalls = 0;
  bool studyGradesThrows = false;
  StudyGrades studyGradesResult = StudyGrades(0, 0, 0, 0);
  String? lastLoginUsername;
  String? lastLoginPassword;
  final Completer<void> secondModulesRequestStarted = Completer<void>();
  final Completer<void> _releaseSecondModulesRequest = Completer<void>();

  _StudyGradesTestService({
    this.loginThrows = false,
    this.blockFirstModulesRequest = true,
  });

  @override
  Future<LoginResult> login(
    String username,
    String password, [
    CancellationToken? cancellationToken,
  ]) async {
    loginCalls += 1;
    lastLoginUsername = username;
    lastLoginPassword = password;
    if (loginThrows) {
      throw Exception('login exploded');
    }
    return LoginResult.LoggedIn;
  }

  @override
  Future<List<Module>> queryAllModules([
    CancellationToken? cancellationToken,
  ]) async {
    queryAllModulesCalls += 1;
    _allModulesCallCount += 1;
    final token = cancellationToken;

    if (blockFirstModulesRequest) {
      if (_allModulesCallCount == 1) {
        while (token != null && !token.isCancelled()) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        throw OperationCancelledException();
      }

      if (!secondModulesRequestStarted.isCompleted) {
        secondModulesRequestStarted.complete();
      }
      await _releaseSecondModulesRequest.future;
    }

    return const <Module>[];
  }

  void releaseSecondModulesRequest() {
    if (_releaseSecondModulesRequest.isCompleted) {
      return;
    }
    _releaseSecondModulesRequest.complete();
  }

  @override
  Future<StudyGrades> queryStudyGrades([
    CancellationToken? cancellationToken,
  ]) async {
    queryStudyGradesCalls += 1;
    if (studyGradesThrows) {
      throw StateError('student results unavailable');
    }
    return studyGradesResult;
  }

  @override
  Future<List<String>> querySemesterNames([
    CancellationToken? cancellationToken,
  ]) async {
    querySemesterNamesCalls += 1;
    return const <String>['SoSe2026'];
  }

  @override
  Future<Semester> querySemester(
    String name, [
    CancellationToken? cancellationToken,
  ]) async {
    querySemesterCalls += 1;
    return Semester(name, const <Module>[]);
  }

  @override
  Future<void> logout([
    CancellationToken? cancellationToken,
  ]) async {}

  @override
  void clearCache() {
    clearCacheCalls += 1;
  }

  void resetCallCounters() {
    clearCacheCalls = 0;
    queryStudyGradesCalls = 0;
    queryAllModulesCalls = 0;
    querySemesterNamesCalls = 0;
    querySemesterCalls = 0;
  }
}

class _ParallelRefreshService extends DualisService {
  final Completer<void> studyGradesStarted = Completer<void>();
  final Completer<void> allModulesStarted = Completer<void>();
  final Completer<void> semesterNamesStarted = Completer<void>();
  final Completer<void> _release = Completer<void>();

  int _activeQueries = 0;
  int maximumConcurrentQueries = 0;

  @override
  Future<LoginResult> login(
    String username,
    String password, [
    CancellationToken? cancellationToken,
  ]) async => LoginResult.LoggedIn;

  @override
  Future<StudyGrades> queryStudyGrades([
    CancellationToken? cancellationToken,
  ]) async {
    studyGradesStarted.complete();
    await _waitForRelease();
    return StudyGrades(0, 0, 0, 0);
  }

  @override
  Future<List<Module>> queryAllModules([
    CancellationToken? cancellationToken,
  ]) async {
    allModulesStarted.complete();
    await _waitForRelease();
    return const <Module>[];
  }

  @override
  Future<List<String>> querySemesterNames([
    CancellationToken? cancellationToken,
  ]) async {
    semesterNamesStarted.complete();
    await _waitForRelease();
    return const <String>[];
  }

  Future<void> _waitForRelease() async {
    _activeQueries += 1;
    if (_activeQueries > maximumConcurrentQueries) {
      maximumConcurrentQueries = _activeQueries;
    }
    try {
      await _release.future;
    } finally {
      _activeQueries -= 1;
    }
  }

  void releaseQueries() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }

  @override
  Future<Semester> querySemester(
    String name, [
    CancellationToken? cancellationToken,
  ]) async => Semester(name, const <Module>[]);

  @override
  Future<void> logout([
    CancellationToken? cancellationToken,
  ]) async {}

  @override
  void clearCache() {}
}

class _FakePreferencesAccess extends PreferencesAccess {
  final Map<String, Object?> _store = <String, Object?>{};

  @override
  Future<void> set<T>(String key, T value) async {
    _store[key] = value;
  }

  @override
  Future<T?> get<T>(String key) async {
    return _store[key] as T?;
  }
}

class _FakeSecureStorageAccess extends SecureStorageAccess {
  final Map<String, String?> _store = <String, String?>{};

  @override
  Future<void> set(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> get(String key) async {
    return _store[key];
  }
}
