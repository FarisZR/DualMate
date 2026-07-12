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

  testWidgets('overview module rows are built lazily', (tester) async {
    final viewModel = _buildViewModel(
      _ImmediateDualisService(
        modules: List<Module>.generate(
          100,
          (index) => Module(
            const <Exam>[],
            'module-$index',
            'Module $index',
            '5',
            '1.3',
            ExamState.Passed,
          ),
        ),
      ),
    );
    addTearDown(viewModel.dispose);

    await viewModel.loadAllModules();
    await tester.pumpWidget(_wrapOverview(viewModel));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('dualis_overview_module_row_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dualis_overview_module_row_99')),
      findsNothing,
    );
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('exam rows keep long labels safe without eager DataTable rows', (
    tester,
  ) async {
    const longExamName =
        'Kombinierte Pruefung mit Klausur und sehr langem Modulnamen';
    final viewModel = _buildViewModel(
      _ImmediateDualisService(
        semester: Semester('SoSe 2026', [
          Module(
            List<Exam>.generate(
              100,
              (index) => Exam(
                index == 0 ? longExamName : 'Exam $index',
                ExamGrade.graded('1,7'),
                ExamState.Passed,
                'SoSe 2026',
              ),
            ),
            'module-1',
            'Schluesselqualifikationen',
            '5,0',
            '1,7',
            ExamState.Passed,
          ),
        ]),
      ),
    );
    addTearDown(viewModel.dispose);

    await viewModel.loadSemester('SoSe 2026');
    await tester.pumpWidget(_wrapExamResults(viewModel));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(longExamName), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('dualis_exam_row_0_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dualis_exam_row_0_99')),
      findsNothing,
    );
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('semester loading transitions to lazy exam content', (
    tester,
  ) async {
    final service = _BlockingSemesterService();
    final viewModel = _buildViewModel(service);
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_wrapExamResults(viewModel));
    unawaited(viewModel.loadSemester('WS 2026'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('dualis_semester_loading')),
      findsOneWidget,
    );

    service.complete(
      Semester('WS 2026', [
        Module(
          const <Exam>[],
          'module-2',
          'Databases',
          '5',
          '2.0',
          ExamState.Passed,
        ),
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
  });
}

StudyGradesViewModel _buildViewModel(DualisService service) {
  return StudyGradesViewModel(
    PreferencesProvider(_MapPreferencesAccess(), _MapSecureStorageAccess()),
    service,
  );
}

Widget _wrapOverview(StudyGradesViewModel viewModel) {
  return _wrapPage(viewModel, StudyOverviewPage());
}

Widget _wrapExamResults(StudyGradesViewModel viewModel) {
  return _wrapPage(viewModel, ExamResultsPage());
}

Widget _wrapPage(StudyGradesViewModel viewModel, Widget page) {
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
          child: page,
        ),
      ),
    ),
  );
}

class _ImmediateDualisService extends DualisService {
  final List<Module> modules;
  final Semester? semester;

  _ImmediateDualisService({this.modules = const [], this.semester});

  @override
  Future<LoginResult> login(
    String username,
    String password, [
    CancellationToken? cancellationToken,
  ]) async => LoginResult.LoggedIn;

  @override
  Future<List<Module>> queryAllModules([
    CancellationToken? cancellationToken,
  ]) async => modules;

  @override
  Future<Semester> querySemester(
    String name, [
    CancellationToken? cancellationToken,
  ]) async => semester ?? Semester(name, const <Module>[]);

  @override
  Future<List<String>> querySemesterNames([
    CancellationToken? cancellationToken,
  ]) async => const <String>[];

  @override
  Future<StudyGrades> queryStudyGrades([
    CancellationToken? cancellationToken,
  ]) async => StudyGrades(0, 0, 0, 0);

  @override
  Future<void> logout([CancellationToken? cancellationToken]) async {}

  @override
  void clearCache() {}
}

class _BlockingSemesterService extends _ImmediateDualisService {
  final Completer<Semester> _semesterCompleter = Completer<Semester>();

  @override
  Future<Semester> querySemester(
    String name, [
    CancellationToken? cancellationToken,
  ]) => _semesterCompleter.future;

  void complete(Semester semester) {
    _semesterCompleter.complete(semester);
  }
}

class _MapPreferencesAccess extends PreferencesAccess {
  final Map<String, Object?> values = <String, Object?>{};

  @override
  Future<void> set<T>(String key, T value) async {
    values[key] = value;
  }

  @override
  Future<T?> get<T>(String key) async => values[key] as T?;
}

class _MapSecureStorageAccess extends SecureStorageAccess {
  @override
  Future<void> set(String key, String value) async {}

  @override
  Future<String?> get(String key) async => null;
}
