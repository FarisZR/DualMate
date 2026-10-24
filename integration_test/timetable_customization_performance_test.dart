import 'dart:ui' show FrameTiming;

import 'package:dualmate/common/appstart/performance_fixture_mode.dart';
import 'package:dualmate/common/appstart/service_injector.dart';
import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_page.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_view_model.dart';
import 'package:dualmate/schedule/ui/customization/timetable_module_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiwi/kiwi.dart';

import 'support/cold_navigation_profile_metrics.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('customization opening scrolling toggling and expanding', (
    tester,
  ) async {
    if (!isPerformanceFixtureMode)
      throw StateError('Use the isolated performance fixture app.');
    injectServices(false);
    final c = KiwiContainer();
    final repository = c.resolve<TimetableRepository>();
    final sourceProvider = c.resolve<ScheduleSourceProvider>();
    final entries = c.resolve<ScheduleEntryRepository>();
    final configurations = [
      for (final name in ['B4', 'B6'])
        TimetableConfiguration(
          id: 'ical:$name',
          label: name,
          type: ScheduleSourceType.Ical,
          value: 'https://example.com/$name.ics',
          includeAll: name == 'B4',
        ),
    ];
    await sourceProvider.saveTimetables(configurations);
    await entries.deleteAllScheduleEntries();
    final now = DateTime.now();
    await entries.saveSchedule(
      Schedule.fromList([
        for (final source in configurations)
          for (var i = 0; i < 80; i++)
            ScheduleEntry(
              sourceIdentity: source.id,
              title:
                  'Module ${i.toString().padLeft(3, '0')} — Software Engineering',
              start: now,
              end: now.add(const Duration(hours: 1)),
              details: '',
              room: '',
              professor: '',
              type: ScheduleEntryType.Class,
            ),
      ]),
    );
    final models = <TimetableCustomizationViewModel>[];
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        theme: ColorPalettes.buildTheme(AppTheme.Light),
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
              onPressed: () {
                final model = TimetableCustomizationViewModel(
                  repository: repository,
                  sourceProvider: sourceProvider,
                  scheduleProvider: c.resolve(),
                  entryRepository: entries,
                );
                models.add(model);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TimetableCustomizationPage(viewModel: model),
                  ),
                );
              },
              child: const Text('Open customization'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reports = <String, dynamic>{};
    Future<void> measure(String name, Future<void> Function() action) async {
      // Drain engine batches before and after each isolated interaction.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final frames = <FrameTiming>[];
      final callback = frames.addAll;
      binding.addTimingsCallback(callback);
      final watch = Stopwatch()..start();
      if (const bool.fromEnvironment('TIMETABLE_TRACE')) {
        await binding.traceAction(
          action,
          streams: const ['all'],
          reportKey: 'timeline_$name',
        );
      } else {
        await action();
      }
      watch.stop();
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      binding.removeTimingsCallback(callback);
      expect(frames, isNotEmpty);
      reports[name] = summarizeFrameDurations(
        buildDurationsUs: frames.map((f) => f.buildDuration.inMicroseconds),
        rasterDurationsUs: frames.map((f) => f.rasterDuration.inMicroseconds),
        interactionDurationUs: watch.elapsedMicroseconds,
        finalStateReached: true,
        intermediateFramesRendered: true,
        isAnimated: true,
      );
    }

    await measure('open_160_modules', () async {
      await tester.tap(find.text('Open customization'));
      await tester.pumpAndSettle();
    });
    reports['initial_live_module_rows'] = find
        .byType(TimetableModuleTile)
        .evaluate()
        .length;
    expect(reports['initial_live_module_rows'], lessThan(40));
    await measure('toggle_module', () async {
      await tester.tap(find.text('Module 000 — Software Engineering').first);
      await tester.pumpAndSettle();
    });
    await measure('collapse_expand', () async {
      await tester.tap(find.text('B4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B4'));
      await tester.pumpAndSettle();
    });
    await measure('scroll_modules', () async {
      final list = find.byType(CustomScrollView).first;
      await tester.fling(list, const Offset(0, -650), 1800);
      await tester.pumpAndSettle();
      await tester.fling(list, const Offset(0, 650), 1800);
      await tester.pumpAndSettle();
    });
    binding.reportData = {
      ...?binding.reportData,
      'customization_performance': reports,
    };
    await tester.pumpWidget(const SizedBox());
    for (final model in models) {
      model.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
