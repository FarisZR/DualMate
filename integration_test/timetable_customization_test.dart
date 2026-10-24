import 'dart:io';

import 'package:dualmate/common/appstart/performance_fixture_mode.dart';
import 'package:dualmate/common/appstart/service_injector.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_page.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiwi/kiwi.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('mix sources, save, reload offline, and render both themes', (
    tester,
  ) async {
    Future<void> demoPause() async {
      if (const bool.fromEnvironment('RECORD_UI_DEMO'))
        await tester.pump(const Duration(milliseconds: 1000));
    }

    binding.testTextInput.register();
    final semantics = binding.ensureSemantics();
    if (!isPerformanceFixtureMode)
      throw StateError(
        'Use PERF_TEST_OFFLINE_FIXTURES=true to isolate this test app.',
      );
    injectServices(false);
    final c = KiwiContainer();
    final repository = c.resolve<TimetableRepository>();
    final sources = c.resolve<ScheduleSourceProvider>();
    final entries = c.resolve<ScheduleEntryRepository>();
    final provider = c.resolve<ScheduleProvider>();
    final database = c.resolve<DatabaseAccess>();
    await repository.save([]);
    await database.deleteWhere('ScheduleEntries');
    final primary = TimetableConfiguration(
      id: 'rapla:b4',
      label: 'B4',
      type: ScheduleSourceType.Rapla,
      value: 'https://rapla.example/rapla?key=b4',
      includeAll: true,
    );
    await sources.saveTimetables([primary]);
    final now = DateTime.now();
    await entries.saveSchedule(
      Schedule.fromList([
        for (final title in [
          'Software Engineering',
          'Database Systems',
          'Mathematics',
          'Computer Networks',
        ])
          ScheduleEntry(
            sourceIdentity: primary.id,
            title: title,
            start: DateTime(now.year, now.month, now.day + 1, 9),
            end: DateTime(now.year, now.month, now.day + 1, 10),
            details: '',
            professor: '',
            room: 'A1',
            type: ScheduleEntryType.Class,
          ),
      ]),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    server.listen((request) async {
      request.response.write(
        'BEGIN:VCALENDAR\r\n${['Formal Languages', 'Artificial Intelligence', 'Numerical Methods', 'Mathematics'].map((title) => 'BEGIN:VEVENT\r\nSUMMARY:$title\r\nDTSTART:${date}T110000\r\nDTEND:${date}T120000\r\nEND:VEVENT\r\n').join()}END:VCALENDAR\r\n',
      );
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final theme = ValueNotifier(ThemeMode.light);
    final locale = ValueNotifier(const Locale('en'));
    final key = GlobalKey<NavigatorState>();
    TimetableCustomizationViewModel model() => TimetableCustomizationViewModel(
      repository: repository,
      sourceProvider: sources,
      scheduleProvider: provider,
      entryRepository: entries,
    );
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: theme,
        builder: (context, mode, _) => ValueListenableBuilder(
          valueListenable: locale,
          builder: (context, language, _) => MaterialApp(
            navigatorKey: key,
            theme: ColorPalettes.buildTheme(AppTheme.Light),
            darkTheme: ColorPalettes.buildTheme(AppTheme.Dark),
            themeMode: mode,
            locale: language,
            localizationsDelegates: const [
              LocalizationDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('de')],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TimetableCustomizationPage(viewModel: model()),
                    ),
                  ),
                  child: const Text('Open customization'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open customization'));
    await tester.pumpAndSettle();
    await demoPause();
    await tester.tap(find.text('Mathematics'));
    await tester.tap(find.text('Computer Networks'));
    await demoPause();
    await tester.scrollUntilVisible(
      find.text('Add timetable'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add timetable'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'B6');
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'B6',
    );
    await tester.tap(find.byType(DropdownButtonFormField<ScheduleSourceType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('iCal Calendar').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'http://127.0.0.1:${server.port}/b6.ics',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'B6',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      contains('127.0.0.1'),
    );
    await demoPause();
    await tester.tap(find.widgetWithText(FilledButton, 'Ok'));
    await tester.pumpAndSettle();
    final activeModel = tester
        .widget<TimetableCustomizationPage>(
          find.byType(TimetableCustomizationPage),
        )
        .viewModel!;
    for (var i = 0; i < 100 && activeModel.loadingSource; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(activeModel.sources, hasLength(2));
    await tester.scrollUntilVisible(
      find.text('Formal Languages'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Formal Languages'));
    await tester.pumpAndSettle();
    await demoPause();
    await tester.tap(find.byKey(const ValueKey('timetable_save_changes')));
    await tester.pumpAndSettle();
    final saved = await repository.load();
    expect(saved, hasLength(2));
    expect(saved.first.includes('Mathematics'), isFalse);
    expect(saved.last.includes('Formal Languages'), isTrue);
    expect(saved.last.includes('Mathematics'), isFalse);
    final visible = await provider.getCachedSchedule(
      now.subtract(const Duration(days: 1)),
      now.add(const Duration(days: 7)),
    );
    expect(visible.entries.map((e) => e.title).toSet(), {
      'Software Engineering',
      'Database Systems',
      'Formal Languages',
    });
    await server.close(force: true);
    await tester.tap(find.text('Open customization'));
    await tester.pumpAndSettle();
    await demoPause();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('timetable-tablet-light');
    theme.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    await binding.takeScreenshot('timetable-tablet-dark');
    locale.value = const Locale('de');
    await tester.pumpAndSettle();
    expect(find.text('Stundenplan anpassen'), findsOneWidget);
    await binding.takeScreenshot('timetable-tablet-dark-de');
    expect(tester.takeException(), isNull);
    semantics.dispose();
    binding.testTextInput.unregister();
  });
}
