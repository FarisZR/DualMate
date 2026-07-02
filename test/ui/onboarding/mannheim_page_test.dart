import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/logging/crash_reporting.dart'
    as crash_reporting;
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/service/mannheim/mannheim_course_service.dart';
import 'package:dualmate/ui/onboarding/viewmodels/mannheim_view_model.dart';
import 'package:dualmate/ui/onboarding/viewmodels/onboarding_view_model_base.dart';
import 'package:dualmate/ui/onboarding/widgets/mannheim_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

void main() {
  setUp(() {
    crash_reporting.reportExceptionImpl = (_, __) async {};
  });

  tearDown(() {
    crash_reporting.reportExceptionImpl =
        crash_reporting.reportExceptionToSentry;
  });

  testWidgets('search field filters Mannheim courses locally', (tester) async {
    final viewModel = MannheimViewModel(
      _FakeScheduleSourceProvider(),
      loadCoursesFromSource: () async => [
        MannheimCourse.fromProfileName('WWI23A'),
        MannheimCourse.fromProfileName('TINF23AI2'),
        MannheimCourse.fromProfileName('WRSW23ST1'),
      ],
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    expect(find.text('WWI23A'), findsOneWidget);
    expect(find.text('TINF23AI2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tinf');
    await tester.pump();

    expect(find.text('WWI23A'), findsNothing);
    expect(find.text('TINF23AI2'), findsOneWidget);
    expect(find.text('WRSW23ST1'), findsNothing);
  });

  testWidgets('selecting a Mannheim course marks it selected', (tester) async {
    final viewModel = MannheimViewModel(
      _FakeScheduleSourceProvider(),
      loadCoursesFromSource: () async => [
        MannheimCourse.fromProfileName('WWI23A'),
      ],
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    await tester.tap(find.text('WWI23A'));
    await tester.pump();

    expect(viewModel.selectedCourse?.name, 'WWI23A');
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('empty Mannheim course list shows empty state', (tester) async {
    final viewModel = MannheimViewModel(
      _FakeScheduleSourceProvider(),
      loadCoursesFromSource: () async => [],
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    expect(find.text('No courses are currently available'), findsOneWidget);
  });

  testWidgets('empty Mannheim search result shows search empty state', (
    tester,
  ) async {
    final viewModel = MannheimViewModel(
      _FakeScheduleSourceProvider(),
      loadCoursesFromSource: () async => [
        MannheimCourse.fromProfileName('WWI23A'),
      ],
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();

    expect(find.text('No courses match your search'), findsOneWidget);
  });

  testWidgets('failed Mannheim course load can be retried', (tester) async {
    var calls = 0;
    final viewModel = MannheimViewModel(
      _FakeScheduleSourceProvider(),
      loadCoursesFromSource: () async {
        calls += 1;
        if (calls == 1) {
          throw StateError('offline');
        }
        return [MannheimCourse.fromProfileName('WWI23A')];
      },
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    expect(find.text('Could not load the courses'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    expect(find.text('WWI23A'), findsOneWidget);
  });
}

Widget _wrapWithApp(MannheimViewModel viewModel) {
  return MaterialApp(
    localizationsDelegates: const [
      LocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('de')],
    home: Scaffold(
      body: PropertyChangeProvider<OnboardingStepViewModel, String>(
        value: viewModel,
        child: MannheimPage(),
      ),
    ),
  );
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
