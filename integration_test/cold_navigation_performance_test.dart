import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dualmate/canteen/ui/canteen_page.dart';
import 'package:dualmate/canteen/ui/widgets/meal_card.dart';
import 'package:dualmate/common/appstart/performance_fixture_mode.dart';
import 'package:dualmate/common/appstart/performance_fixture_schedule_source.dart';
import 'package:dualmate/date_management/ui/date_management_page.dart';
import 'package:dualmate/date_management/ui/widgets/important_event_section_card.dart';
import 'package:dualmate/dualis/ui/dualis_page.dart';
import 'package:dualmate/dualis/ui/exam_results_page/exam_results_page.dart';
import 'package:dualmate/dualis/service/fake_data_dualis_scraper.dart';
import 'package:dualmate/main.dart' as app;
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_entry_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'support/cold_navigation_fixture.dart';
import 'support/cold_navigation_profile_metrics.dart';

const String _profileMode = String.fromEnvironment(
  'PERF_PROFILE_MODE',
  defaultValue: 'diagnostic',
);
const bool _requiresVmServiceReadinessCheck = bool.fromEnvironment(
  'PERF_TIMELINE_READY_CHECK',
  defaultValue: false,
);
const Duration _pollStep = Duration(milliseconds: 16);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'records loaded cold-navigation frame timing per visible interaction',
    (tester) async {
      if (!isPerformanceFixtureMode) {
        throw StateError(
          'Run with --dart-define=PERF_TEST_OFFLINE_FIXTURES=true. '
          'The profile harness refuses to use network-backed production data.',
        );
      }

      final fixture = await ColdNavigationFixture.prepare();
      await _waitForVmServiceReadiness();
      final frameTimings = <FrameTiming>[];
      final frameTimingCallback = frameTimings.addAll;
      final recorder = _ScenarioRecorder(
        binding: binding,
        tester: tester,
        frameTimings: frameTimings,
        profileMode: _profileMode,
      );
      binding.addTimingsCallback(frameTimingCallback);

      Object? harnessFailure;
      StackTrace? harnessFailureStack;
      try {
        if (_profileMode == 'combined') {
          await _runCombinedJourney(tester, recorder);
        } else {
          await _runDiagnosticScenarios(tester, recorder, fixture);
        }
      } catch (error, stack) {
        harnessFailure = error;
        harnessFailureStack = stack;
        rethrow;
      } finally {
        binding.removeTimingsCallback(frameTimingCallback);
        if (harnessFailure != null) {
          recorder.recordHarnessFailure(harnessFailure, harnessFailureStack);
        }
        binding.reportData ??= <String, dynamic>{};
        binding.reportData!['cold_navigation_profile'] = recorder.toJson();
      }
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

/// `traceAction` opens a VM-service socket from the app process. The engine
/// reports its URI before that listener is always accepting connections, so use
/// a successful connection as the readiness condition instead of a delay.
Future<void> _waitForVmServiceReadiness() async {
  if (!_requiresVmServiceReadinessCheck) return;

  final serviceInfo = await developer.Service.getInfo();
  final serviceUri = serviceInfo.serverUri;
  if (serviceUri == null) {
    throw StateError(
      'The Dart VM service URI is unavailable for timeline tracing.',
    );
  }

  final port = serviceUri.port;
  debugPrint('PERF_TIMELINE_SERVICE_PORT=$port');
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final socket = await Socket.connect(
        serviceUri.host,
        port,
        timeout: const Duration(milliseconds: 250),
      );
      socket.destroy();
      return;
    } on SocketException {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  throw StateError(
    'Timed out waiting for the local Dart VM service on port $port.',
  );
}

Future<void> _runDiagnosticScenarios(
  WidgetTester tester,
  _ScenarioRecorder recorder,
  ColdNavigationFixture fixture,
) async {
  await recorder.measure(
    'schedule_cold_placeholder_to_populated',
    animated: false,
    action: () async {
      unawaited(app.main());
      await _waitFor(
        tester,
        find.byKey(const ValueKey<String>('main_page_initial_placeholder')),
        description: 'cold startup placeholder',
      );
      await _waitForLoadedSchedule(tester);
      return const _ScenarioEvidence(
        finalStateReached: true,
        intermediateFramesRendered: true,
        finalStateDescription:
            'schedule entries rendered after startup placeholder',
      );
    },
  );

  await _waitForWeeklyScheduleInitialization(tester);
  await recorder.measure(
    'schedule_cold_first_populated_swipe',
    action: () => _swipeScheduleForward(
      tester,
      description: 'cold first swipe',
      expectedWeekStart: fixture.tallWeekStart,
    ),
  );

  await _settleLoadedState(tester);
  await recorder.measure(
    'schedule_settled_populated_swipe',
    action: () => _swipeScheduleBackward(
      tester,
      description: 'settled repeated swipe',
      expectedWeekStart: fixture.currentWeekStart,
    ),
  );

  await recorder.measure(
    'schedule_short_to_tall_height_transition',
    action: () => _swipeScheduleForward(
      tester,
      description: 'short to tall week transition',
      expectedWeekStart: fixture.tallWeekStart,
    ),
  );

  await recorder.measure(
    'schedule_memory_cached_week_navigation',
    action: () => _swipeScheduleBackward(
      tester,
      description: 'memory cached populated week navigation',
      expectedWeekStart: fixture.currentWeekStart,
    ),
  );

  await recorder.measure(
    'schedule_database_cached_week_navigation',
    action: () async {
      for (var index = 0; index < 3; index++) {
        final expectedWeekStart = <DateTime>[
          fixture.tallWeekStart,
          fixture.intermediateWeekStart,
          fixture.databaseCachedWeekStart,
        ][index];
        final evidence = await _swipeScheduleForward(
          tester,
          description: 'database cached week navigation ${index + 1}',
          expectedWeekStart: expectedWeekStart,
          settleAfter: index == 2,
        );
        if (!evidence.finalStateReached ||
            !evidence.intermediateFramesRendered) {
          return evidence;
        }
      }
      final expectedPage = find.byKey(
        ValueKey<String>(
          'week_page_${fixture.databaseCachedWeekStart.toIso8601String()}',
        ),
      );
      return _ScenarioEvidence(
        finalStateReached: expectedPage.evaluate().isNotEmpty,
        intermediateFramesRendered: true,
        finalStateDescription:
            'database-cached populated schedule week rendered',
      );
    },
  );

  await recorder.measure(
    'schedule_refresh_required_week_navigation',
    action: () async {
      final navigation = await _swipeScheduleForward(
        tester,
        description: 'refresh-required week navigation',
        expectedWeekStart: fixture.refreshRequiredWeekStart,
        settleAfter: false,
      );
      final refreshedEntry = find.byWidgetPredicate(
        (widget) =>
            widget is ScheduleEntryWidget &&
            widget.scheduleEntry.title ==
                PerformanceFixtureScheduleSource.refreshedEntryTitle,
        description: 'refreshed fixture Schedule entry',
      );
      final contentWasDeferred = refreshedEntry.evaluate().isEmpty;
      await _refreshVisibleSchedule(tester, fixture.refreshRequiredWeekStart);
      await _waitFor(
        tester,
        refreshedEntry,
        description: 'refresh-required populated Schedule content',
        timeout: const Duration(seconds: 4),
      );
      await _settleLoadedState(tester);
      return _ScenarioEvidence(
        finalStateReached:
            navigation.finalStateReached &&
            refreshedEntry.evaluate().isNotEmpty,
        intermediateFramesRendered:
            navigation.intermediateFramesRendered || contentWasDeferred,
        finalStateDescription:
            'uncached week rendered through the local visible-refresh path',
      );
    },
  );

  await _settleLoadedState(tester);
  await recorder.measure(
    'drawer_cold_open_over_populated_schedule',
    action: () => _openDrawer(tester, description: 'cold drawer open'),
  );
  await _closeDrawerWithoutNavigation(tester);
  await _settleLoadedState(tester);
  await recorder.measure(
    'drawer_settled_open_over_populated_schedule',
    action: () => _openDrawer(tester, description: 'settled drawer open'),
  );
  await _closeDrawerWithoutNavigation(tester);

  await _openDrawerForSetup(tester);
  await recorder.measure(
    'drawer_close_to_canteen',
    action: () => _selectDrawerDestination(
      tester,
      keyName: 'drawer_item_canteen',
      destination: find.byType(CanteenPage),
      destinationDescription: 'Canteen',
    ),
  );
  await recorder.measure(
    'canteen_cold_first_navigation_to_populated',
    animated: false,
    action: () => _waitForCanteenContent(tester, settle: false),
  );
  await recorder.measure(
    'canteen_cold_loaded_day_swipe',
    action: () => _swipeCanteenForward(tester, description: 'cold day swipe'),
  );
  await _settleLoadedState(tester);
  await recorder.measure(
    'canteen_settled_day_meal_count_height_transition',
    action: () => _swipeCanteenForward(
      tester,
      description: 'varied meal count transition',
    ),
  );
  await _settleLoadedState(tester);
  await recorder.measure(
    'canteen_settled_repeated_interaction',
    action: () => _swipeCanteenBackward(
      tester,
      description: 'settled repeated day swipe',
    ),
  );

  await _openDrawerForSetup(tester);
  await recorder.measure(
    'drawer_close_to_dates',
    action: () => _selectDrawerDestination(
      tester,
      keyName: 'drawer_item_date_management',
      destination: find.byType(DateManagementPage),
      destinationDescription: 'Dates',
    ),
  );
  await recorder.measure(
    'dates_first_navigation_to_page',
    animated: false,
    action: () async {
      await _waitFor(
        tester,
        find.byType(DateManagementPage),
        description: 'Dates page construction',
      );
      return const _ScenarioEvidence(
        finalStateReached: true,
        intermediateFramesRendered: true,
        finalStateDescription:
            'Dates page is visible before cached data arrives',
      );
    },
  );
  await recorder.measure(
    'dates_loading_to_populated_content',
    animated: false,
    action: () => _waitForDateRows(tester, settle: false),
  );
  await recorder.measure(
    'dates_cold_loaded_list_scroll',
    action: () =>
        _scrollFirstDescendant(tester, find.byType(DateManagementPage)),
  );
  await _settleLoadedState(tester);
  await _openDrawerForSetup(tester);
  await recorder.measure(
    'drawer_close_to_dualis',
    action: () => _selectDrawerDestination(
      tester,
      keyName: 'drawer_item_dualis',
      destination: find.byType(DualisPage),
      destinationDescription: 'Dualis',
    ),
  );
  await recorder.measure(
    'dualis_first_navigation_to_restoring_state',
    animated: false,
    action: () async {
      await _waitFor(
        tester,
        find.byType(DualisPage),
        description: 'Dualis page construction',
      );
      final restoring = find.byKey(
        const ValueKey<String>('dualis_restoring_page'),
      );
      final loaded = find.byKey(
        const ValueKey<String>(
          'dualis_modules_ready_${FakeDataDualisScraper.demoModuleCount}',
        ),
      );
      await _pumpUntil(
        tester,
        condition: () =>
            restoring.evaluate().isNotEmpty || loaded.evaluate().isNotEmpty,
        description: 'Dualis restoring or populated state',
      );
      final sawRestoring = restoring.evaluate().isNotEmpty;
      return _ScenarioEvidence(
        finalStateReached: sawRestoring || loaded.evaluate().isNotEmpty,
        intermediateFramesRendered: sawRestoring,
        finalStateDescription: sawRestoring
            ? 'Dualis restoring state is visible'
            : 'Dualis restored directly to populated demo content',
      );
    },
  );
  await recorder.measure(
    'dualis_loading_to_populated_content',
    animated: false,
    action: () => _waitForDualisContent(tester, settle: false),
  );
  await recorder.measure(
    'dualis_cold_loaded_result_scroll',
    action: () => _scrollFirstDescendant(tester, find.byType(DualisPage)),
  );
  await _settleLoadedState(tester);
  await recorder.measure(
    'dualis_loaded_tab_switch',
    animated: false,
    action: () => _switchDualisTab(tester),
  );
}

Future<void> _runCombinedJourney(
  WidgetTester tester,
  _ScenarioRecorder recorder,
) async {
  await recorder.measure(
    'combined_cold_start_journey',
    animated: false,
    action: () async {
      unawaited(app.main());
      await _waitForLoadedSchedule(tester);

      await _openDrawerForSetup(tester);
      await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_canteen',
        destination: find.byType(CanteenPage),
        destinationDescription: 'Canteen',
      );
      await _waitForCanteenContent(tester);

      await _openDrawerForSetup(tester);
      await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_date_management',
        destination: find.byType(DateManagementPage),
        destinationDescription: 'Dates',
      );
      await _waitForDateRows(tester);

      await _openDrawerForSetup(tester);
      await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_dualis',
        destination: find.byType(DualisPage),
        destinationDescription: 'Dualis',
      );
      await _waitForDualisContent(tester);

      return const _ScenarioEvidence(
        finalStateReached: true,
        intermediateFramesRendered: true,
        finalStateDescription:
            'Schedule, Canteen, Dates, and Dualis loaded in one cold journey',
      );
    },
  );
}

Future<_ScenarioEvidence> _swipeScheduleForward(
  WidgetTester tester, {
  required String description,
  required DateTime expectedWeekStart,
  bool settleAfter = true,
}) {
  return _swipePageView(
    tester,
    pageView: find.byKey(const ValueKey<String>('weekly_schedule_page_view')),
    description: description,
    finalStateFinder: find.byKey(
      ValueKey<String>('week_page_${expectedWeekStart.toIso8601String()}'),
    ),
    trigger: () => _animatePager(
      tester,
      find.byKey(const ValueKey<String>('weekly_schedule_page_view')),
      1,
    ),
    afterAnimation: () => _commitScheduleWeek(tester, expectedWeekStart),
    settleAfter: settleAfter,
  );
}

Future<_ScenarioEvidence> _swipeScheduleBackward(
  WidgetTester tester, {
  required String description,
  required DateTime expectedWeekStart,
}) {
  return _swipePageView(
    tester,
    pageView: find.byKey(const ValueKey<String>('weekly_schedule_page_view')),
    description: description,
    finalStateFinder: find.byKey(
      ValueKey<String>('week_page_${expectedWeekStart.toIso8601String()}'),
    ),
    trigger: () => _animatePager(
      tester,
      find.byKey(const ValueKey<String>('weekly_schedule_page_view')),
      -1,
    ),
    afterAnimation: () => _commitScheduleWeek(tester, expectedWeekStart),
  );
}

Future<void> _commitScheduleWeek(
  WidgetTester tester,
  DateTime weekStart,
) async {
  final weeklyPage = find.byType(WeeklySchedulePage);
  await _waitFor(
    tester,
    weeklyPage,
    description: 'weekly schedule page before pager commit',
  );
  final context = tester.element(weeklyPage.first);
  await Provider.of<WeeklyScheduleViewModel>(
    context,
    listen: false,
  ).openWeekContaining(weekStart);
}

Future<void> _refreshVisibleSchedule(
  WidgetTester tester,
  DateTime weekStart,
) async {
  final weeklyPage = find.byType(WeeklySchedulePage);
  await _waitFor(
    tester,
    weeklyPage,
    description: 'weekly schedule page before visible refresh',
  );
  final context = tester.element(weeklyPage.first);
  await Provider.of<WeeklyScheduleViewModel>(
    context,
    listen: false,
  ).openWeekContainingFromWidget(weekStart);
}

Future<_ScenarioEvidence> _swipeCanteenForward(
  WidgetTester tester, {
  required String description,
}) {
  return _swipeCanteenDay(
    tester,
    description: description,
    preferForward: true,
  );
}

Future<_ScenarioEvidence> _swipeCanteenBackward(
  WidgetTester tester, {
  required String description,
}) {
  return _swipeCanteenDay(
    tester,
    description: description,
    preferForward: false,
  );
}

Future<_ScenarioEvidence> _swipeCanteenDay(
  WidgetTester tester, {
  required String description,
  required bool preferForward,
}) async {
  final pageView = _canteenPageView(tester);
  await _waitFor(tester, pageView, description: '$description page view');
  final page = tester.widget<PageView>(pageView.first);
  final controller = page.controller;
  final count = page.childrenDelegate.estimatedChildCount ?? 0;
  if (controller == null || controller.positions.length != 1 || count < 2) {
    return const _ScenarioEvidence(
      finalStateReached: false,
      intermediateFramesRendered: false,
      finalStateDescription:
          'Canteen pager did not expose adjacent content days',
    );
  }
  final current = (controller.page ?? controller.initialPage.toDouble())
      .round();
  final delta = preferForward
      ? (current < count - 1 ? 1 : -1)
      : (current > 0 ? -1 : 1);
  return _swipePageView(
    tester,
    pageView: pageView,
    description: description,
    expectedPageDelta: delta,
    finalStateFinder: null,
    trigger: () => _animatePager(tester, pageView, delta),
  );
}

Future<_ScenarioEvidence> _swipePageView(
  WidgetTester tester, {
  required Finder pageView,
  required String description,
  required Finder? finalStateFinder,
  int? expectedPageDelta,
  required Future<void> Function() trigger,
  Future<void> Function()? afterAnimation,
  bool settleAfter = true,
}) async {
  await _waitFor(tester, pageView, description: '$description page view');
  final initialPage = _currentPageIndex(tester, pageView);
  if (finalStateFinder != null &&
      _isFinderFullyVisible(tester, finalStateFinder, within: pageView)) {
    return const _ScenarioEvidence(
      finalStateReached: false,
      intermediateFramesRendered: false,
      finalStateDescription: 'Expected target page was already visible',
    );
  }

  await trigger();
  await tester.pump(_pollStep);
  var intermediate =
      tester.binding.hasScheduledFrame ||
      (finalStateFinder != null
          ? !_isFinderFullyVisible(tester, finalStateFinder, within: pageView)
          : initialPage == null ||
                expectedPageDelta == null ||
                _currentPageIndex(tester, pageView) !=
                    initialPage + expectedPageDelta);

  try {
    await _pumpUntil(
      tester,
      condition: () {
        final targetIsVisible = finalStateFinder != null
            ? _isFinderFullyVisible(tester, finalStateFinder, within: pageView)
            : initialPage != null &&
                  expectedPageDelta != null &&
                  _currentPageIndex(tester, pageView) ==
                      initialPage + expectedPageDelta;
        intermediate = intermediate || !targetIsVisible;
        return targetIsVisible && !tester.binding.hasScheduledFrame;
      },
      description: '$description animation completion',
    );
  } on StateError {
    throw StateError(
      '$description did not reach its target. '
      '${_describePageView(tester, pageView, finalStateFinder)}',
    );
  }
  if (afterAnimation != null) {
    await afterAnimation();
  }
  if (finalStateFinder != null) {
    await _waitFor(
      tester,
      finalStateFinder,
      description: '$description populated final state',
    );
  }
  if (settleAfter) {
    await _settleLoadedState(tester);
  }

  return _ScenarioEvidence(
    finalStateReached: finalStateFinder != null
        ? _isFinderFullyVisible(tester, finalStateFinder, within: pageView)
        : initialPage != null &&
              expectedPageDelta != null &&
              _currentPageIndex(tester, pageView) ==
                  initialPage + expectedPageDelta,
    intermediateFramesRendered: intermediate,
    finalStateDescription: '$description reached the expected populated page',
  );
}

Future<void> _animatePager(
  WidgetTester tester,
  Finder pageView,
  int delta,
) async {
  await _waitFor(tester, pageView, description: 'page view before animation');
  final controller = tester.widget<PageView>(pageView.first).controller;
  if (controller == null || !controller.hasClients) {
    throw StateError('PageView controller was unavailable.');
  }
  final currentPage = controller.positions.length == 1
      ? (controller.page ?? controller.initialPage.toDouble()).round()
      : controller.initialPage;
  unawaited(
    controller.animateToPage(
      currentPage + delta,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
    ),
  );
}

bool _isFinderFullyVisible(
  WidgetTester tester,
  Finder finder, {
  required Finder within,
}) {
  if (finder.evaluate().isEmpty || within.evaluate().isEmpty) return false;
  final viewport = tester.getRect(within.first);
  for (final element in finder.evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox || !renderObject.hasSize) continue;
    final target = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final visible = target.intersect(viewport);
    if (visible.width >= target.width * 0.98 &&
        visible.height >= target.height * 0.98) {
      return true;
    }
  }
  return false;
}

String _describePageView(WidgetTester tester, Finder pageView, Finder? target) {
  final controller = pageView.evaluate().isEmpty
      ? null
      : tester.widget<PageView>(pageView.first).controller;
  final positions = controller == null
      ? 'none'
      : controller.positions
            .map(
              (position) =>
                  'pixels=${position.pixels.toStringAsFixed(1)},'
                  'viewport=${position.viewportDimension.toStringAsFixed(1)}',
            )
            .join(';');
  final targetRects = <String>[];
  for (final element in target?.evaluate() ?? const <Element>[]) {
    final renderObject = element.renderObject;
    if (renderObject is RenderBox && renderObject.hasSize) {
      final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      targetRects.add(rect.toString());
    }
  }
  return 'pagePositions=[$positions], targetCount=${target?.evaluate().length ?? 0}, '
      'targetRects=$targetRects';
}

int? _currentPageIndex(WidgetTester tester, Finder pageView) {
  if (pageView.evaluate().isEmpty) return null;
  final controller = tester.widget<PageView>(pageView.first).controller;
  if (controller == null || controller.positions.length != 1) return null;
  return (controller.page ?? controller.initialPage.toDouble()).round();
}

Future<_ScenarioEvidence> _openDrawer(
  WidgetTester tester, {
  required String description,
}) async {
  final menu = find.byTooltip('Open navigation menu');
  await _waitFor(tester, menu, description: '$description menu button');
  await tester.tap(menu.first, warnIfMissed: false);
  await tester.pump(_pollStep);
  final intermediate =
      find.byType(Drawer).evaluate().isNotEmpty &&
      tester.binding.hasScheduledFrame;
  await _pumpUntil(
    tester,
    condition: () =>
        find.byType(Drawer).evaluate().isNotEmpty &&
        !tester.binding.hasScheduledFrame,
    description: '$description completion',
  );
  return _ScenarioEvidence(
    finalStateReached: find.byType(Drawer).evaluate().isNotEmpty,
    intermediateFramesRendered: intermediate,
    finalStateDescription: '$description drawer is fully open',
  );
}

Future<void> _openDrawerForSetup(WidgetTester tester) async {
  if (find.byType(Drawer).evaluate().isNotEmpty) return;
  await _openDrawer(tester, description: 'setup drawer open');
}

Future<void> _closeDrawerWithoutNavigation(WidgetTester tester) async {
  if (find.byType(Drawer).evaluate().isEmpty) return;
  await tester.tapAt(const Offset(390, 150));
  await _pumpUntil(
    tester,
    condition: () =>
        find.byType(Drawer).evaluate().isEmpty &&
        !tester.binding.hasScheduledFrame,
    description: 'drawer close without navigation',
  );
}

Future<_ScenarioEvidence> _selectDrawerDestination(
  WidgetTester tester, {
  required String keyName,
  required Finder destination,
  required String destinationDescription,
}) async {
  final item = find.byKey(ValueKey<String>(keyName));
  await _waitFor(
    tester,
    item,
    description: '$destinationDescription drawer item',
  );
  await tester.tap(item, warnIfMissed: false);
  await tester.pump(_pollStep);
  final drawerWasStillMoving =
      find.byType(Drawer).evaluate().isNotEmpty &&
      destination.evaluate().isEmpty;
  await _pumpUntil(
    tester,
    condition: () =>
        find.byType(Drawer).evaluate().isEmpty &&
        !tester.binding.hasScheduledFrame,
    description: 'drawer close to $destinationDescription',
  );

  return _ScenarioEvidence(
    finalStateReached: find.byType(Drawer).evaluate().isEmpty,
    intermediateFramesRendered: drawerWasStillMoving,
    finalStateDescription:
        'drawer closed; $destinationDescription construction '
        '${destination.evaluate().isEmpty ? 'followed' : 'overlapped'} it',
  );
}

Future<_ScenarioEvidence> _waitForCanteenContent(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await _waitFor(
    tester,
    find.byType(CanteenPage),
    description: 'Canteen page construction',
  );
  final hadNoMealsAtStart = find.byType(MealCard).evaluate().isEmpty;
  await _waitFor(
    tester,
    find.byType(MealCard),
    description: 'populated Canteen meal cards',
    timeout: const Duration(seconds: 8),
  );
  if (settle) await _settleLoadedState(tester);
  return _ScenarioEvidence(
    finalStateReached: find.byType(MealCard).evaluate().isNotEmpty,
    intermediateFramesRendered: hadNoMealsAtStart,
    finalStateDescription: 'varied cached Canteen meals are visible',
  );
}

Future<_ScenarioEvidence> _waitForDateRows(
  WidgetTester tester, {
  bool settle = true,
}) async {
  final sections = find.byType(ImportantEventSectionCard);
  final hadNoRowsAtStart = sections.evaluate().isEmpty;
  await _waitFor(
    tester,
    sections,
    description: 'populated cached Rapla Date sections',
    timeout: const Duration(seconds: 8),
  );
  if (settle) await _settleLoadedState(tester);
  return _ScenarioEvidence(
    finalStateReached: sections.evaluate().isNotEmpty,
    intermediateFramesRendered: hadNoRowsAtStart,
    finalStateDescription: 'cached Rapla Dates list contains fixture content',
  );
}

Future<_ScenarioEvidence> _waitForDualisContent(
  WidgetTester tester, {
  bool settle = true,
}) async {
  final restoring = find.byKey(const ValueKey<String>('dualis_restoring_page'));
  final sawRestoringState = restoring.evaluate().isNotEmpty;
  await _waitFor(
    tester,
    find.byKey(
      const ValueKey<String>(
        'dualis_modules_ready_${FakeDataDualisScraper.demoModuleCount}',
      ),
    ),
    description: 'populated Dualis demo modules',
    timeout: const Duration(seconds: 8),
  );
  if (settle) await _settleLoadedState(tester);
  return _ScenarioEvidence(
    finalStateReached: find
        .byKey(
          const ValueKey<String>(
            'dualis_modules_ready_${FakeDataDualisScraper.demoModuleCount}',
          ),
        )
        .evaluate()
        .isNotEmpty,
    intermediateFramesRendered: sawRestoringState,
    finalStateDescription: 'Dualis demo module content is visible',
  );
}

Future<_ScenarioEvidence> _scrollFirstDescendant(
  WidgetTester tester,
  Finder parent,
) async {
  final scrollable = find.descendant(
    of: parent,
    matching: find.byType(Scrollable),
  );
  await _waitFor(tester, scrollable, description: 'populated scrollable');
  ScrollableState? state;
  for (var index = 0; index < scrollable.evaluate().length; index++) {
    final candidate = tester.state<ScrollableState>(scrollable.at(index));
    if (candidate.position.maxScrollExtent > candidate.position.pixels) {
      state = candidate;
      break;
    }
  }
  if (state == null) {
    return const _ScenarioEvidence(
      finalStateReached: false,
      intermediateFramesRendered: false,
      finalStateDescription: 'no populated scrollable had forward extent',
    );
  }
  final before = state.position.pixels;
  final target = (before + 520).clamp(0.0, state.position.maxScrollExtent);
  if (target <= before) {
    return _ScenarioEvidence(
      finalStateReached: false,
      intermediateFramesRendered: false,
      finalStateDescription: 'populated list had no forward scroll extent',
    );
  }
  unawaited(
    state.position.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
    ),
  );
  await tester.pump(_pollStep);
  final intermediate =
      tester.binding.hasScheduledFrame || state.position.pixels > before;
  await _pumpUntil(
    tester,
    condition: () => !tester.binding.hasScheduledFrame,
    description: 'scroll completion',
  );
  return _ScenarioEvidence(
    finalStateReached: (state.position.pixels - target).abs() < 0.01,
    intermediateFramesRendered: intermediate,
    finalStateDescription:
        'populated list moved from $before to ${state.position.pixels}',
  );
}

Future<_ScenarioEvidence> _switchDualisTab(WidgetTester tester) async {
  final tabs = find.descendant(
    of: find.byType(DualisPage),
    matching: find.byType(BottomNavigationBar),
  );
  await _waitFor(tester, tabs, description: 'loaded Dualis tab bar');
  final book = find.descendant(
    of: tabs.first,
    matching: find.byIcon(Icons.book),
  );
  await _waitFor(tester, book, description: 'Dualis exam tab');
  await tester.tap(book.first, warnIfMissed: false);
  await tester.pump(_pollStep);
  await _waitFor(
    tester,
    find.byType(ExamResultsPage),
    description: 'loaded Dualis exam results page',
  );
  return const _ScenarioEvidence(
    finalStateReached: true,
    intermediateFramesRendered: true,
    finalStateDescription: 'Dualis exam tab is visible with loaded content',
  );
}

Finder _canteenPageView(WidgetTester tester) {
  final pageViews = find.descendant(
    of: find.byType(CanteenPage),
    matching: find.byType(PageView),
  );
  if (pageViews.evaluate().isEmpty) {
    return pageViews;
  }
  return pageViews.first;
}

Future<void> _waitForLoadedSchedule(WidgetTester tester) async {
  await _waitFor(
    tester,
    find.byType(WeeklySchedulePage),
    description: 'weekly schedule page',
  );
  await _waitFor(
    tester,
    find.byType(ScheduleEntryWidget),
    description: 'populated schedule entries',
    timeout: const Duration(seconds: 8),
  );
}

Future<void> _waitForWeeklyScheduleInitialization(WidgetTester tester) async {
  final weeklyPage = find.byType(WeeklySchedulePage);
  await _waitFor(tester, weeklyPage, description: 'weekly schedule page');
  await _pumpUntil(
    tester,
    condition: () {
      final context = tester.element(weeklyPage.first);
      return Provider.of<WeeklyScheduleViewModel>(
        context,
        listen: false,
      ).isInitializationComplete;
    },
    description: 'weekly schedule initialization',
  );
}

Future<void> _settleLoadedState(WidgetTester tester) async {
  var consecutiveIdleFrames = 0;
  final deadline = tester.binding.clock.fromNowBy(const Duration(seconds: 3));
  while (consecutiveIdleFrames < 3) {
    if (tester.binding.clock.now().isAfter(deadline)) {
      throw StateError('Loaded state did not settle after three idle frames.');
    }
    await tester.pump(_pollStep);
    consecutiveIdleFrames = tester.binding.hasScheduledFrame
        ? 0
        : consecutiveIdleFrames + 1;
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  required String description,
  Duration timeout = const Duration(seconds: 4),
}) {
  return _pumpUntil(
    tester,
    condition: () => finder.evaluate().isNotEmpty,
    description: description,
    timeout: timeout,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester, {
  required bool Function() condition,
  required String description,
  Duration timeout = const Duration(seconds: 4),
}) async {
  final deadline = tester.binding.clock.fromNowBy(timeout);
  while (!condition()) {
    if (tester.binding.clock.now().isAfter(deadline)) {
      throw StateError('Timed out waiting for $description.');
    }
    await tester.pump(_pollStep);
  }
}

class _ScenarioRecorder {
  final IntegrationTestWidgetsFlutterBinding binding;
  final WidgetTester tester;
  final List<FrameTiming> frameTimings;
  final String profileMode;
  final Map<String, Map<String, dynamic>> _scenarios =
      <String, Map<String, dynamic>>{};

  _ScenarioRecorder({
    required this.binding,
    required this.tester,
    required this.frameTimings,
    required this.profileMode,
  });

  Future<void> measure(
    String scenarioId, {
    required Future<_ScenarioEvidence> Function() action,
    bool animated = true,
  }) async {
    final startIndex = frameTimings.length;
    final start = tester.binding.clock.now();
    late _ScenarioEvidence evidence;
    final timelineKey = 'cold_navigation_timeline_$scenarioId';

    await binding.traceAction(
      () async {
        final task = developer.TimelineTask(filterKey: 'cold_navigation');
        task.start('scenario:$scenarioId');
        try {
          evidence = await action();
        } finally {
          task.finish();
        }
      },
      streams: const <String>['all'],
      reportKey: timelineKey,
    );

    final interactionDuration = tester.binding.clock.now().difference(start);
    final timings = frameTimings.skip(startIndex).toList(growable: false);
    final summary = summarizeFrameDurations(
      buildDurationsUs: timings
          .map((timing) => timing.buildDuration.inMicroseconds)
          .toList(growable: false),
      rasterDurationsUs: timings
          .map((timing) => timing.rasterDuration.inMicroseconds)
          .toList(growable: false),
      interactionDurationUs: interactionDuration.inMicroseconds,
      finalStateReached: evidence.finalStateReached,
      intermediateFramesRendered: evidence.intermediateFramesRendered,
      isAnimated: animated,
    );
    summary['timeline_key'] = timelineKey;
    summary['final_state_description'] = evidence.finalStateDescription;
    _scenarios[scenarioId] = summary;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schema_version': 1,
      'profile_mode': profileMode,
      'frame_budget_us': <String, int>{
        '120hz': frameBudget120HzUs,
        '60hz': frameBudget60HzUs,
        '30hz': frameBudget30HzUs,
        '20hz': frameBudget20HzUs,
      },
      'settled_loaded_definition':
          'three consecutive idle frames after loaded content',
      'scenarios': _scenarios,
    };
  }

  void recordHarnessFailure(Object error, StackTrace? stackTrace) {
    _scenarios['harness_failure'] = <String, dynamic>{
      'frame_count': 0,
      'interaction_duration_us': 0,
      'expected_final_state_reached': false,
      'is_animated': false,
      'intermediate_frames_rendered': false,
      'final_state_description': error.toString(),
      'stack_trace': stackTrace?.toString(),
      'ui_build': <String, dynamic>{},
      'raster': <String, dynamic>{},
      'combined': <String, dynamic>{},
    };
  }
}

class _ScenarioEvidence {
  final bool finalStateReached;
  final bool intermediateFramesRendered;
  final String finalStateDescription;

  const _ScenarioEvidence({
    required this.finalStateReached,
    required this.intermediateFramesRendered,
    required this.finalStateDescription,
  });
}
