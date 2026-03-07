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
    final service = _StudyGradesTestService(loginThrows: true);
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
}

PreferencesProvider _buildPreferences() {
  return PreferencesProvider(
    _FakePreferencesAccess(),
    _FakeSecureStorageAccess(),
  );
}

class _StudyGradesTestService extends DualisService {
  final bool loginThrows;
  int _allModulesCallCount = 0;
  final Completer<void> secondModulesRequestStarted = Completer<void>();
  final Completer<void> _releaseSecondModulesRequest = Completer<void>();

  _StudyGradesTestService({this.loginThrows = false});

  @override
  Future<LoginResult> login(
    String username,
    String password, [
    CancellationToken? cancellationToken,
  ]) async {
    if (loginThrows) {
      throw Exception('login exploded');
    }
    return LoginResult.LoggedIn;
  }

  @override
  Future<List<Module>> queryAllModules([
    CancellationToken? cancellationToken,
  ]) async {
    _allModulesCallCount += 1;
    final token = cancellationToken;

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
    return StudyGrades(0, 0, 0, 0);
  }

  @override
  Future<List<String>> querySemesterNames([
    CancellationToken? cancellationToken,
  ]) async {
    return const <String>[];
  }

  @override
  Future<Semester> querySemester(
    String name, [
    CancellationToken? cancellationToken,
  ]) async {
    return Semester(name, const <Module>[]);
  }

  @override
  Future<void> logout([
    CancellationToken? cancellationToken,
  ]) async {}
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
