import 'dart:developer' as developer;

import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/canteen/service/canteen_scraper.dart';
import 'package:dualmate/canteen/ui/canteen_page.dart';
import 'package:dualmate/canteen/ui/widgets/meal_card.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/date_management/ui/date_management_page.dart';
import 'package:dualmate/date_management/ui/widgets/important_event_section_card.dart';
import 'package:dualmate/dualis/service/fake_account_dualis_scraper_decorator.dart';
import 'package:dualmate/dualis/ui/dualis_page.dart';
import 'package:dualmate/main.dart' as app;
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_information.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/service/rapla/rapla_schedule_source.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_entry_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _realisticRaplaScheduleUrl =
    'https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=strand&file=TINF25B5';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold launch loaded navigation has no 120hz janky frames', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      PreferencesProvider.IsFirstStartKey: false,
      PreferencesProvider.ScheduleSourceType: ScheduleSourceType.Rapla.index,
      PreferencesProvider.RaplaUrlKey: _realisticRaplaScheduleUrl,
      PreferencesProvider.UseDhMineForDates: false,
      PreferencesProvider.DontShowRateNowDialog: true,
      PreferencesProvider.DidShowWidgetHelpDialog: true,
      PreferencesProvider.DualisStoreCredentials: true,
      PreferencesProvider.SelectedCanteenLocationId:
          CanteenLocations.karlsruheId,
      PreferencesProvider.CachedCanteenLocationId: CanteenLocations.karlsruheId,
    });

    await _seedDemoDualisCredentials();
    await _seedRealisticCachedSchedule();
    await _seedLoadedCanteenCache();

    final frameTimings = <FrameTiming>[];
    final segments = <String, Map<String, dynamic>>{};
    final callback = frameTimings.addAll;
    binding.addTimingsCallback(callback);

    try {
      await binding.traceAction(
        () async {
          await _measureSegment(
            tester,
            frameTimings,
            segments,
            'launch',
            () async {
              app.main();

              await _pumpUntilFound(
                tester,
                find.byKey(
                  const ValueKey<String>('main_page_initial_placeholder'),
                ),
                timeout: const Duration(milliseconds: 900),
              );
              await _pumpUntilFound(
                tester,
                find.byTooltip('Open navigation menu'),
                timeout: const Duration(seconds: 2),
              );
            },
          );

          await _measureSegment(
            tester,
            frameTimings,
            segments,
            'schedule_loaded_swipes',
            () => _exerciseSchedule(tester),
          );
          await _measureSegment(
            tester,
            frameTimings,
            segments,
            'open_canteen_loaded',
            () => _openSection(
              tester,
              keyName: 'drawer_item_canteen',
              expected: find.byType(CanteenPage),
              content: find.byType(MealCard),
              contentTimeout: const Duration(seconds: 10),
            ),
          );
          await _measureSegment(
            tester,
            frameTimings,
            segments,
            'canteen_swipes',
            () => _exerciseCanteenPager(tester),
          );
          await _measureSegment(
            tester,
            frameTimings,
            segments,
            'open_dates',
            () => _openSection(
              tester,
              keyName: 'drawer_item_date_management',
              expected: find.byType(DateManagementPage),
              content: find.byType(ImportantEventSectionCard),
              contentTimeout: const Duration(seconds: 10),
            ),
          );
          await _measureSegment(
            tester,
            frameTimings,
            segments,
            'dates_scroll',
            () => _exerciseFirstScrollable(tester),
          );
          await _measureSegment(
            tester,
            frameTimings,
            segments,
            'open_dualis',
            () => _openSection(
              tester,
              keyName: 'drawer_item_dualis',
              expected: find.byType(DualisPage),
              content: _dualisLoadingOrLoadedFinder(),
              contentTimeout: const Duration(seconds: 3),
            ),
          );
          await _measureSegment(
            tester,
            frameTimings,
            segments,
            'dualis_visible_wait',
            () => _exerciseDualisLoaded(tester),
          );
        },
        streams: const <String>['all'],
        reportKey: 'aggressive_cold_navigation_timeline',
      );
    } finally {
      binding.removeTimingsCallback(callback);
    }

    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['aggressive_cold_navigation_frames'] =
        _summarizeFrameTimings(frameTimings)..['segments'] = segments;
  });
}

Future<void> _measureSegment(
  WidgetTester tester,
  List<FrameTiming> frameTimings,
  Map<String, Map<String, dynamic>> segments,
  String label,
  Future<void> Function() action,
) async {
  final startIndex = frameTimings.length;
  final timelineTask = developer.TimelineTask();
  timelineTask.start('segment:$label');
  try {
    await action();
    await tester.pump(const Duration(milliseconds: 160));
  } finally {
    timelineTask.finish();
  }
  segments[label] = _summarizeFrameTimings(
    frameTimings.skip(startIndex).toList(growable: false),
  );
}

Future<void> _exerciseSchedule(WidgetTester tester) async {
  await _requireFound(
    tester,
    find.byType(WeeklySchedulePage),
    timeout: const Duration(seconds: 2),
    description: 'weekly schedule page',
  );
  await _requireFound(
    tester,
    find.byType(ScheduleEntryWidget),
    timeout: const Duration(seconds: 2),
    description: 'real schedule entries',
  );

  final pageView = find.descendant(
    of: find.byType(WeeklySchedulePage),
    matching: find.byKey(const ValueKey<String>('weekly_schedule_page_view')),
  );
  if (pageView.evaluate().isEmpty) return;

  for (final offset in const <Offset>[
    Offset(-420, 0),
    Offset(-420, 0),
    Offset(420, 0),
  ]) {
    await tester.fling(pageView.first, offset, 2200);
    await tester.pump(const Duration(milliseconds: 360));
    await _requireFound(
      tester,
      find.byType(ScheduleEntryWidget),
      timeout: const Duration(seconds: 2),
      description: 'real schedule entries after week swipe',
    );
  }
}

Future<void> _seedRealisticCachedSchedule() async {
  final database = DatabaseAccess();
  final entryRepository = ScheduleEntryRepository(database);
  final queryRepository = ScheduleQueryInformationRepository(database);
  final scheduleSource = RaplaScheduleSource(
    raplaUrl: _realisticRaplaScheduleUrl,
  );

  final weekStart = toStartOfDay(toDayOfWeek(DateTime.now(), DateTime.monday));
  final weeksToSeed = <DateTime>[
    toPreviousWeek(weekStart),
    weekStart,
    toNextWeek(weekStart),
    toNextWeek(toNextWeek(weekStart)),
  ];

  await entryRepository.deleteAllScheduleEntries();
  await queryRepository.deleteAllQueryInformation();

  var seededEntryCount = 0;
  var currentWeekEntryCount = 0;
  final queryTime = DateTime.now();
  for (final start in weeksToSeed) {
    final end = toNextWeek(start);
    final result = await scheduleSource.querySchedule(
      start,
      end,
      CancellationToken(),
    );
    final entryCount = result.schedule.entries.length;
    seededEntryCount += entryCount;
    if (start == weekStart) currentWeekEntryCount = entryCount;

    await entryRepository.saveSchedule(result.schedule);
    await queryRepository.saveScheduleQueryInformation(
      ScheduleQueryInformation(start, end, queryTime),
    );
  }

  await entryRepository.saveSchedule(
    Schedule.fromList(<ScheduleEntry>[
      _buildImportantDateEntry(addDays(weekStart, 14)),
    ]),
  );

  if (currentWeekEntryCount == 0 || seededEntryCount == 0) {
    throw StateError(
      'Realistic Rapla cache seed returned no current-week entries for '
      '$weekStart - ${toNextWeek(weekStart)}; total seeded entries: '
      '$seededEntryCount',
    );
  }
}

Future<void> _seedDemoDualisCredentials() async {
  const storage = FlutterSecureStorage();
  await storage.write(
    key: PreferencesProvider.DualisUsername,
    value: FakeAccountDualisScraperDecorator.demoUsername,
  );
  await storage.write(
    key: PreferencesProvider.DualisPassword,
    value: FakeAccountDualisScraperDecorator.demoPassword,
  );
}

Future<void> _seedLoadedCanteenCache() async {
  final repository = CanteenMealRepository(DatabaseAccess());
  final scraper = CanteenScraper();
  final today = _normalizeToWeekday(DateTime.now());
  final weekStart = toStartOfDay(toMonday(today));
  final weekEnd = addDays(weekStart, 5);
  final menus = await scraper.loadWeek(weekStart, CancellationToken());
  final meals = menus.expand((menu) => menu.meals).toList(growable: false);

  if (meals.isEmpty) {
    throw StateError(
      'Realistic canteen cache seed returned no meals for '
      '$weekStart - $weekEnd.',
    );
  }

  await repository.deleteMealsBetween(weekStart, weekEnd);
  await repository.saveMeals(meals);
}

ScheduleEntry _buildImportantDateEntry(DateTime day) {
  final start = DateTime(day.year, day.month, day.day, 10);
  return ScheduleEntry(
    start: start,
    end: start.add(const Duration(hours: 2)),
    title: 'Klausur Software Engineering',
    details: 'Seeded realistic important date for loaded dates perf coverage',
    professor: 'DHBW Karlsruhe',
    room: 'Audimax',
    type: ScheduleEntryType.Exam,
  );
}

DateTime _normalizeToWeekday(DateTime date) {
  final normalized = toStartOfDay(date);
  if (normalized.weekday == DateTime.saturday) {
    return addDays(normalized, 2);
  }
  if (normalized.weekday == DateTime.sunday) {
    return addDays(normalized, 1);
  }
  return normalized;
}

Future<void> _openSection(
  WidgetTester tester, {
  required String keyName,
  required Finder expected,
  Finder? content,
  Duration contentTimeout = const Duration(seconds: 3),
}) async {
  await _openDrawer(tester);
  final item = find.byKey(ValueKey<String>(keyName));
  final foundItem = await _pumpUntilFound(
    tester,
    item,
    timeout: const Duration(seconds: 1),
  );
  if (!foundItem) return;
  await tester.tap(item, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 32));
  await _requireFound(
    tester,
    expected,
    timeout: const Duration(seconds: 3),
    description: 'section $keyName',
  );
  if (content != null) {
    await _requireFound(
      tester,
      content,
      timeout: contentTimeout,
      description: 'loaded content for $keyName',
    );
  }
}

Future<void> _openDrawer(WidgetTester tester) async {
  final menu = find.byTooltip('Open navigation menu');
  final foundMenu = await _pumpUntilFound(
    tester,
    menu,
    timeout: const Duration(seconds: 1),
  );
  if (!foundMenu) return;
  await tester.tap(menu.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 320));
}

Future<void> _exerciseCanteenPager(WidgetTester tester) async {
  await _requireFound(
    tester,
    find.byKey(canteenPageViewKey),
    timeout: const Duration(seconds: 8),
    description: 'loaded canteen day pager',
  );
  await _requireFound(
    tester,
    find.byType(MealCard),
    timeout: const Duration(seconds: 2),
    description: 'canteen meal cards',
  );

  final pageView = find.descendant(
    of: find.byType(CanteenPage),
    matching: find.byKey(canteenPageViewKey),
  );
  if (pageView.evaluate().isEmpty) return;

  for (final offset in const <Offset>[
    Offset(-360, 0),
    Offset(360, 0),
    Offset(-360, 0),
  ]) {
    await tester.fling(pageView.first, offset, 1800, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 360));
  }
}

Future<void> _exerciseFirstScrollable(WidgetTester tester) async {
  await _requireFound(
    tester,
    find.byType(ImportantEventSectionCard),
    timeout: const Duration(seconds: 8),
    description: 'loaded important event sections',
  );

  final scrollables = find.descendant(
    of: find.byType(DateManagementPage),
    matching: find.byType(Scrollable),
  );
  if (scrollables.evaluate().isEmpty) return;

  await tester.fling(
    scrollables.first,
    const Offset(0, -520),
    1800,
    warnIfMissed: false,
  );
  await tester.pump(const Duration(milliseconds: 120));
  await tester.fling(
    scrollables.first,
    const Offset(0, 520),
    1800,
    warnIfMissed: false,
  );
  await tester.pump(const Duration(milliseconds: 120));
}

Future<void> _exerciseDualisLoaded(WidgetTester tester) async {
  await _requireFound(
    tester,
    _dualisLoadingOrLoadedFinder(),
    timeout: const Duration(seconds: 2),
    description: 'Dualis loading or loaded state',
  );
  await _requireFound(
    tester,
    find.byKey(const ValueKey<String>('dualis_modules_ready_3')),
    timeout: const Duration(seconds: 8),
    description: 'loaded Dualis demo module data',
  );
  await _requireFound(
    tester,
    find.text('Software Engineering'),
    timeout: const Duration(seconds: 1),
    description: 'loaded Dualis module title',
  );

  final scrollables = find.descendant(
    of: find.byType(DualisPage),
    matching: find.byType(Scrollable),
  );
  if (scrollables.evaluate().isEmpty) return;

  await tester.fling(
    scrollables.first,
    const Offset(0, -420),
    1600,
    warnIfMissed: false,
  );
  await tester.pump(const Duration(milliseconds: 160));
}

Finder _dualisLoadingOrLoadedFinder() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        (key.value == 'dualis_restoring_page' ||
            key.value == 'dualis_logged_in_pager' ||
            key.value == 'dualis_overview_summary_loading' ||
            key.value == 'dualis_modules_loading' ||
            key.value == 'dualis_overview_summary' ||
            key.value.startsWith('dualis_modules_ready_'));
  });
}

Future<void> _requireFound(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
  required String description,
}) async {
  final found = await _pumpUntilFound(tester, finder, timeout: timeout);
  if (!found) {
    throw StateError('Timed out waiting for $description.');
  }
}

Future<bool> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
}) async {
  final end = tester.binding.clock.fromNowBy(timeout);
  do {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 16));
  } while (tester.binding.clock.now().isBefore(end));

  return finder.evaluate().isNotEmpty;
}

Map<String, dynamic> _summarizeFrameTimings(List<FrameTiming> timings) {
  const budgetMicros = 8333;
  final buildTimes = timings
      .map((timing) => timing.buildDuration.inMicroseconds)
      .toList(growable: false);
  final rasterTimes = timings
      .map((timing) => timing.rasterDuration.inMicroseconds)
      .toList(growable: false);

  return <String, dynamic>{
    'frame_count': timings.length,
    'frame_build_times_us': buildTimes,
    'frame_raster_times_us': rasterTimes,
    'worst_frame_build_time_us': _maxOrZero(buildTimes),
    'worst_frame_raster_time_us': _maxOrZero(rasterTimes),
    'missed_120hz_build_budget_count': buildTimes
        .where((duration) => duration > budgetMicros)
        .length,
    'missed_120hz_raster_budget_count': rasterTimes
        .where((duration) => duration > budgetMicros)
        .length,
  };
}

int _maxOrZero(List<int> values) {
  var max = 0;
  for (final value in values) {
    if (value > max) {
      max = value;
    }
  }
  return max;
}
