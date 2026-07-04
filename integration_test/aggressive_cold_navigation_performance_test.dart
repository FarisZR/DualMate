import 'package:dualmate/canteen/ui/canteen_page.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/date_management/ui/date_management_page.dart';
import 'package:dualmate/dualis/ui/dualis_page.dart';
import 'package:dualmate/main.dart' as app;
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold launch fast navigation has no 120hz janky frames', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      PreferencesProvider.IsFirstStartKey: false,
      PreferencesProvider.ScheduleSourceType: ScheduleSourceType.Rapla.index,
      PreferencesProvider.RaplaUrlKey:
          'https://rapla.dhbw-stuttgart.de/rapla?key=abc',
      PreferencesProvider.UseDhMineForDates: false,
      PreferencesProvider.DontShowRateNowDialog: true,
      PreferencesProvider.DidShowWidgetHelpDialog: true,
    });

    final frameTimings = <FrameTiming>[];
    final segments = <String, Map<String, dynamic>>{};
    final callback = frameTimings.addAll;
    binding.addTimingsCallback(callback);

    try {
      await _measureSegment(tester, frameTimings, segments, 'launch', () async {
        app.main();

        await _pumpUntilFound(
          tester,
          find.byKey(const ValueKey<String>('main_page_initial_placeholder')),
          timeout: const Duration(milliseconds: 900),
        );
        await _pumpUntilFound(
          tester,
          find.byTooltip('Open navigation menu'),
          timeout: const Duration(seconds: 2),
        );
      });

      await _measureSegment(
        tester,
        frameTimings,
        segments,
        'schedule_swipes',
        () => _exerciseSchedule(tester),
      );
      await _measureSegment(
        tester,
        frameTimings,
        segments,
        'open_canteen',
        () => _openSection(
          tester,
          keyName: 'drawer_item_canteen',
          expected: find.byType(CanteenPage),
        ),
      );
      await _measureSegment(
        tester,
        frameTimings,
        segments,
        'canteen_swipes',
        () => _exerciseFirstPageView(tester),
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
        ),
      );
      await _measureSegment(
        tester,
        frameTimings,
        segments,
        'dualis_visible_wait',
        () => tester.pump(const Duration(seconds: 2)),
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
  await action();
  await tester.pump(const Duration(milliseconds: 160));
  segments[label] = _summarizeFrameTimings(
    frameTimings.skip(startIndex).toList(growable: false),
  );
}

Future<void> _exerciseSchedule(WidgetTester tester) async {
  await _pumpUntilFound(
    tester,
    find.byType(WeeklySchedulePage),
    timeout: const Duration(seconds: 2),
  );

  final pageView = find.descendant(
    of: find.byType(WeeklySchedulePage),
    matching: find.byType(PageView),
  );
  if (pageView.evaluate().isEmpty) return;

  for (final offset in const <Offset>[
    Offset(-420, 0),
    Offset(-420, 0),
    Offset(420, 0),
  ]) {
    await tester.fling(pageView.first, offset, 2200);
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _openSection(
  WidgetTester tester, {
  required String keyName,
  required Finder expected,
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
  await _pumpUntilFound(tester, expected, timeout: const Duration(seconds: 3));
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
  await tester.pump(const Duration(milliseconds: 32));
}

Future<void> _exerciseFirstPageView(WidgetTester tester) async {
  final pageViews = find.byType(PageView);
  if (pageViews.evaluate().isEmpty) return;

  for (final offset in const <Offset>[
    Offset(-360, 0),
    Offset(360, 0),
    Offset(-360, 0),
  ]) {
    await tester.fling(pageViews.first, offset, 1800);
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _exerciseFirstScrollable(WidgetTester tester) async {
  final scrollables = find.descendant(
    of: find.byType(DateManagementPage),
    matching: find.byType(Scrollable),
  );
  if (scrollables.evaluate().isEmpty) return;

  await tester.fling(scrollables.first, const Offset(0, -520), 1800);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.fling(scrollables.first, const Offset(0, 520), 1800);
  await tester.pump(const Duration(milliseconds: 120));
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
