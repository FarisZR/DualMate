import 'dart:async';

import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/model/exam.dart';
import 'package:dualmate/dualis/model/exam_grade.dart';
import 'package:dualmate/dualis/model/module.dart';
import 'package:dualmate/dualis/model/semester.dart';
import 'package:dualmate/dualis/model/study_grades.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/dualis/ui/exam_results_page/exam_results_page.dart';
import 'package:dualmate/dualis/ui/study_overview/study_overview_page.dart';
import 'package:dualmate/dualis/ui/viewmodels/study_grades_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows loading placeholder while module list is fetched', (
    tester,
  ) async {
    final dualisService = _BlockingDualisService();
    final preferences = PreferencesProvider(
      _FakePreferencesAccess(),
      _FakeSecureStorageAccess(),
    );
    final viewModel = StudyGradesViewModel(preferences, dualisService);
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_wrapWithApp(viewModel));

    unawaited(viewModel.loadAllModules());
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('dualis_modules_loading')),
      findsOneWidget,
    );

    dualisService.completeModules([
      Module(
        const <Exam>[],
        'M1',
        'Algorithms',
        '5',
        '1.3',
        ExamState.Passed,
      ),
    ]);

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('dualis_modules_loading')),
      findsNothing,
    );
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('shows loading placeholder while semester modules are fetched', (
    tester,
  ) async {
    final dualisService = _BlockingDualisService();
    final preferences = PreferencesProvider(
      _FakePreferencesAccess(),
      _FakeSecureStorageAccess(),
    );
    final viewModel = StudyGradesViewModel(preferences, dualisService);
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_wrapWithExamResultsApp(viewModel));

    unawaited(viewModel.loadSemester('WS2026'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('dualis_semester_loading')),
      findsOneWidget,
    );

    dualisService.completeSemester(
      'WS2026',
      Semester(
        'WS2026',
        [
          Module(
            const <Exam>[],
            'M2',
            'Databases',
            '5',
            '2.0',
            ExamState.Passed,
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('dualis_semester_loading')),
      findsNothing,
    );
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('exam rows do not overflow with long wrapped labels', (
    tester,
  ) async {
    final dualisService = _BlockingDualisService();
    final preferences = PreferencesProvider(
      _FakePreferencesAccess(),
      _FakeSecureStorageAccess(),
    );
    final viewModel = StudyGradesViewModel(preferences, dualisService);
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_wrapWithExamResultsApp(viewModel));

    unawaited(viewModel.loadSemester('SoSe 2026'));
    await tester.pump();

    dualisService.completeSemester(
      'SoSe 2026',
      Semester(
        'SoSe 2026',
        [
          Module(
            [
              Exam(
                'Kombinierte Pruefung mit Klausur (<50 %) (100%)',
                ExamGrade.graded('1,7'),
                ExamState.Passed,
                'SoSe 2026',
              ),
            ],
            'M3',
            'Schluesselqualifikationen',
            '5,0',
            '1,7',
            ExamState.Passed,
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    final exceptions = <Object>[];
    Object? exception;
    while ((exception = tester.takeException()) != null) {
      exceptions.add(exception!);
    }

    expect(exceptions, isEmpty);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.textContaining('Kombinierte Pruefung'), findsOneWidget);
  });
}

Widget _wrapWithApp(StudyGradesViewModel viewModel) {
  return ChangeNotifierProvider<StudyGradesViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: Scaffold(
        body: PropertyChangeProvider<StudyGradesViewModel, String>(
          value: viewModel,
          child: StudyOverviewPage(),
        ),
      ),
    ),
  );
}

Widget _wrapWithExamResultsApp(StudyGradesViewModel viewModel) {
  return ChangeNotifierProvider<StudyGradesViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: Scaffold(
        body: PropertyChangeProvider<StudyGradesViewModel, String>(
          value: viewModel,
          child: ExamResultsPage(),
        ),
      ),
    ),
  );
}

class _BlockingDualisService extends DualisService {
  final Completer<List<Module>> _allModulesCompleter =
      Completer<List<Module>>();
  final Map<String, Completer<Semester>> _semesterCompleters =
      <String, Completer<Semester>>{};

  @override
  Future<LoginResult> login(
    String username,
    String password, [
    CancellationToken? cancellationToken,
  ]) async {
    return LoginResult.LoggedIn;
  }

  @override
  Future<List<Module>> queryAllModules([
    CancellationToken? cancellationToken,
  ]) {
    return _allModulesCompleter.future;
  }

  @override
  Future<Semester> querySemester(
    String name, [
    CancellationToken? cancellationToken,
  ]) {
    return _semesterCompleters
        .putIfAbsent(name, () => Completer<Semester>())
        .future;
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

  void completeModules(List<Module> modules) {
    if (_allModulesCompleter.isCompleted) {
      return;
    }
    _allModulesCompleter.complete(modules);
  }

  void completeSemester(String name, Semester semester) {
    final completer =
        _semesterCompleters.putIfAbsent(name, () => Completer<Semester>());
    if (completer.isCompleted) {
      return;
    }
    completer.complete(semester);
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
