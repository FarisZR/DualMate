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
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'login falls back to LoginFailed on unexpected service errors',
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
    },
  );

  test(
    'loadAllModules keeps loading=true for the newest in-flight request',
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
    },
  );

  test(
    'restores the Dualis session from saved credentials on page open',
    () async {
      final preferences = _buildPreferences();
      await preferences.storeDualisCredentials(
        Credentials('saved-user', 'saved-pass'),
      );
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
    },
  );

  test(
    'refreshData(force: true) clears cached Dualis data before reloading',
    () async {
      final preferences = _buildPreferences();
      final service = _StudyGradesTestService(blockFirstModulesRequest: false);
      final viewModel = StudyGradesViewModel(preferences, service);
      addTearDown(viewModel.dispose);

      final success = await viewModel.login(Credentials('u', 'p'));
      expect(success, isTrue);

      while (await preferences.getDualisLastRefreshAt() == null) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      service.resetCallCounters();

      await viewModel.refreshData(force: true);

      expect(service.clearCacheCalls, 1);
      expect(service.queryStudyGradesCalls, 1);
      expect(service.queryAllModulesCalls, 1);
      expect(service.querySemesterNamesCalls, 1);
    },
  );

  test('loadStudyGrades swallows expected network failures', () async {
    final service = _NetworkErrorDualisService(
      studyGradesError: ServiceRequestFailed('Http request failed!'),
    );
    final viewModel = StudyGradesViewModel(_buildPreferences(), service);
    addTearDown(viewModel.dispose);

    await expectLater(viewModel.loadStudyGrades(), completes);
    expect(viewModel.isLoadingStudyGrades, isFalse);
  });

  test('loadAllModules swallows expected network failures', () async {
    final service = _NetworkErrorDualisService(
      allModulesError: ServiceRequestFailed('Http request failed!'),
    );
    final viewModel = StudyGradesViewModel(_buildPreferences(), service);
    addTearDown(viewModel.dispose);

    await expectLater(viewModel.loadAllModules(), completes);
    expect(viewModel.isLoadingAllModules, isFalse);
  });

  test('loadSemesterByName swallows expected network failures', () async {
    final service = _NetworkErrorDualisService(
      semesterError: ServiceRequestFailed('Http request failed!'),
    );
    final viewModel = StudyGradesViewModel(_buildPreferences(), service);
    addTearDown(viewModel.dispose);

    await expectLater(viewModel.loadSemesterByName('SoSe2026'), completes);
    expect(viewModel.isLoadingCurrentSemester, isFalse);
  });

  test('loadStudyGrades rethrows unexpected errors', () async {
    final service = _NetworkErrorDualisService(
      studyGradesError: StateError('parse regression'),
    );
    final viewModel = StudyGradesViewModel(_buildPreferences(), service);
    addTearDown(viewModel.dispose);

    await expectLater(viewModel.loadStudyGrades(), throwsA(isA<StateError>()));
  });

  test(
    'refreshData does not advance lastRefreshAt on expected network failure',
    () async {
      final preferences = _buildPreferences();
      final service = _NetworkErrorDualisService(
        studyGradesError: ServiceRequestFailed('Http request failed!'),
      );
      final viewModel = StudyGradesViewModel(preferences, service);
      addTearDown(viewModel.dispose);

      await viewModel.login(Credentials('u', 'p'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        await preferences.getDualisLastRefreshAt(),
        isNull,
        reason:
            'A network failure must not be recorded as a successful refresh',
      );
    },
  );

  test('refreshData advances lastRefreshAt when all loads succeed', () async {
    final preferences = _buildPreferences();
    final service = _NetworkErrorDualisService();
    final viewModel = StudyGradesViewModel(preferences, service);
    addTearDown(viewModel.dispose);

    await viewModel.login(Credentials('u', 'p'));

    while (await preferences.getDualisLastRefreshAt() == null) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    expect(await preferences.getDualisLastRefreshAt(), isNotNull);
  });
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
    return StudyGrades(0, 0, 0, 0);
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
  Future<void> logout([CancellationToken? cancellationToken]) async {}

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

class _NetworkErrorDualisService extends DualisService {
  final Object? studyGradesError;
  final Object? allModulesError;
  final Object? semesterError;

  _NetworkErrorDualisService({
    this.studyGradesError,
    this.allModulesError,
    this.semesterError,
  });

  @override
  Future<LoginResult> login(
    String username,
    String password, [
    CancellationToken? cancellationToken,
  ]) async {
    return LoginResult.LoggedIn;
  }

  @override
  Future<StudyGrades> queryStudyGrades([
    CancellationToken? cancellationToken,
  ]) async {
    final error = studyGradesError;
    if (error != null) throw error;
    return StudyGrades(0, 0, 0, 0);
  }

  @override
  Future<List<Module>> queryAllModules([
    CancellationToken? cancellationToken,
  ]) async {
    final error = allModulesError;
    if (error != null) throw error;
    return const <Module>[];
  }

  @override
  Future<List<String>> querySemesterNames([
    CancellationToken? cancellationToken,
  ]) async {
    return const <String>['SoSe2026'];
  }

  @override
  Future<Semester> querySemester(
    String name, [
    CancellationToken? cancellationToken,
  ]) async {
    final error = semesterError;
    if (error != null) throw error;
    return Semester(name, const <Module>[]);
  }

  @override
  Future<void> logout([CancellationToken? cancellationToken]) async {}

  @override
  void clearCache() {}
}
