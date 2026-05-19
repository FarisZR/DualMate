import 'dart:async';

import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/credentials.dart';
import 'package:dualmate/dualis/model/module.dart';
import 'package:dualmate/dualis/model/semester.dart';
import 'package:dualmate/dualis/model/study_grades.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/dualis/ui/dualis_page.dart';
import 'package:dualmate/dualis/ui/login/dualis_login_page.dart';
import 'package:dualmate/dualis/ui/viewmodels/study_grades_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    KiwiContainer().clear();
  });

  tearDown(() {
    KiwiContainer().clear();
  });

  testWidgets('does not show login page before restoring saved session', (
    tester,
  ) async {
    final preferences = PreferencesProvider(
      _FakePreferencesAccess(),
      _FakeSecureStorageAccess(),
    );
    KiwiContainer().registerInstance<PreferencesProvider>(preferences);
    await preferences.storeDualisCredentials(Credentials('saved-user', 'saved-pass'));

    final dualisService = _DelayedLoginDualisService();
    final viewModel = StudyGradesViewModel(preferences, dualisService);
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    expect(find.byType(DualisLoginPage), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('dualis_restoring_page')),
      findsOneWidget,
    );

    dualisService.completeLogin();
    await tester.pumpAndSettle();

    expect(find.byType(DualisLoginPage), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('dualis_logged_in_pager')),
      findsOneWidget,
    );
  });
}

Widget _wrapWithApp(StudyGradesViewModel viewModel) {
  final sectionIndex = ValueNotifier<int>(2);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<StudyGradesViewModel>.value(value: viewModel),
      ChangeNotifierProvider<ValueNotifier<int>>.value(value: sectionIndex),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: const Scaffold(body: DualisPage(sectionIndex: 2)),
    ),
  );
}

class _DelayedLoginDualisService extends DualisService {
  final Completer<void> _loginCompleter = Completer<void>();

  @override
  Future<LoginResult> login(
    String username,
    String password, [
    CancellationToken? cancellationToken,
  ]) async {
    await _loginCompleter.future;
    return LoginResult.LoggedIn;
  }

  @override
  Future<List<Module>> queryAllModules([
    CancellationToken? cancellationToken,
  ]) async {
    return const <Module>[];
  }

  @override
  Future<Semester> querySemester(
    String name, [
    CancellationToken? cancellationToken,
  ]) async {
    return Semester(name, const <Module>[]);
  }

  @override
  Future<List<String>> querySemesterNames([
    CancellationToken? cancellationToken,
  ]) async {
    return const <String>[];
  }

  @override
  Future<StudyGrades> queryStudyGrades([
    CancellationToken? cancellationToken,
  ]) async {
    return StudyGrades(0, 0, 0, 0);
  }

  @override
  Future<void> logout([
    CancellationToken? cancellationToken,
  ]) async {}

  @override
  void clearCache() {}

  void completeLogin() {
    if (_loginCompleter.isCompleted) {
      return;
    }
    _loginCompleter.complete();
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
