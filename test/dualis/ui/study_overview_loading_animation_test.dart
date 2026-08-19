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
import 'package:dualmate/schedule/service/schedule_source.dart';
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
      Module(const <Exam>[], 'M1', 'Algorithms', '5', '1.3', ExamState.Passed),
    ]);

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('dualis_modules_loading')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('dualis_overview_module_row_0')),
      findsOneWidget,
    );
    expect(find.byType(DataTable), findsNothing);

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).last);
    final tooltipTarget = tester.getSize(find.byWidget(tooltip.child!));
    expect(tooltipTarget.width, greaterThan(0));
    expect(tooltipTarget.height, greaterThan(0));
  });

  testWidgets('restores the GPA summary when refreshing grades fails', (
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

    final initialLoad = viewModel.loadStudyGrades();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('dualis_overview_summary_loading')),
      findsOneWidget,
    );

    dualisService.completeStudyGrades(StudyGrades(1.7, 1.8, 210, 96));
    expect(await initialLoad, isTrue);
    await tester.pumpAndSettle();

    expect(find.text('1.7'), findsOneWidget);
    expect(find.text('1.8'), findsOneWidget);
    expect(find.text('96.0 / 210.0'), findsOneWidget);

    final failedRefresh = viewModel.loadStudyGrades();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('dualis_overview_summary_loading')),
      findsOneWidget,
    );

    dualisService.failStudyGrades(ServiceRequestFailed('Http request failed!'));
    expect(await failedRefresh, isFalse);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('dualis_overview_summary_loading')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('dualis_overview_summary')),
      findsOneWidget,
    );
    expect(find.text('1.7'), findsOneWidget);
    expect(find.text('1.8'), findsOneWidget);
    expect(find.text('96.0 / 210.0'), findsOneWidget);
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
      Semester('WS2026', [
        Module(const <Exam>[], 'M2', 'Databases', '5', '2.0', ExamState.Passed),
      ]),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('dualis_semester_loading')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('dualis_exam_module_header_0')),
      findsOneWidget,
    );
    expect(find.byType(DataTable), findsNothing);
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
      Semester('SoSe 2026', [
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
      ]),
    );

    await tester.pumpAndSettle();

    final exceptions = <Object>[];
    Object? exception;
    while ((exception = tester.takeException()) != null) {
      exceptions.add(exception!);
    }

    expect(exceptions, isEmpty);
    expect(
      find.byKey(const ValueKey<String>('dualis_exam_row_0_0')),
      findsOneWidget,
    );
    expect(find.byType(DataTable), findsNothing);
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
  final List<Completer<StudyGrades>> _studyGradesRequests =
      <Completer<StudyGrades>>[];
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
  Future<List<Module>> queryAllModules([CancellationToken? cancellationToken]) {
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
  Future<StudyGrades> queryStudyGrades([CancellationToken? cancellationToken]) {
    final request = Completer<StudyGrades>();
    _studyGradesRequests.add(request);
    return request.future;
  }

  @override
  Future<void> logout([CancellationToken? cancellationToken]) async {}

  @override
  void clearCache() {}

  void completeModules(List<Module> modules) {
    if (_allModulesCompleter.isCompleted) {
      return;
    }
    _allModulesCompleter.complete(modules);
  }

  void completeStudyGrades(StudyGrades studyGrades) {
    _nextStudyGradesRequest.complete(studyGrades);
  }

  void failStudyGrades(Object error) {
    _nextStudyGradesRequest.completeError(error, StackTrace.current);
  }

  Completer<StudyGrades> get _nextStudyGradesRequest =>
      _studyGradesRequests.firstWhere((request) => !request.isCompleted);

  void completeSemester(String name, Semester semester) {
    final completer = _semesterCompleters.putIfAbsent(
      name,
      () => Completer<Semester>(),
    );
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
