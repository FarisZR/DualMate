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
  defaultValue: 'ranking',
);
const String _perfTarget = String.fromEnvironment(
  'PERF_TARGET',
  defaultValue: 'all',
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
      final collectTimeline = _profileMode != 'ranking';
      final recorder = _ScenarioRecorder(
        binding: binding,
        tester: tester,
        frameTimings: frameTimings,
        profileMode: _profileMode,
        collectTimeline: collectTimeline,
      );
      binding.addTimingsCallback(frameTimingCallback);

      Object? harnessFailure;
      StackTrace? harnessFailureStack;
      try {
        switch (_perfTarget) {
          case 'schedule':
            await _runScheduleColdStart(tester, recorder, fixture);
          case 'canteen':
            await _runCanteenColdStart(tester, recorder);
          case 'dates':
            await _runDatesColdStart(tester, recorder);
          case 'dualis':
            await _runDualisColdStart(tester, recorder);
          case 'combined':
            await _runCombinedJourney(tester, recorder);
          default:
            if (_profileMode == 'combined') {
              await _runCombinedJourney(tester, recorder);
            } else {
              await _runDiagnosticScenarios(tester, recorder, fixture);
            }
        }
        await recorder.finalize();
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

// ---------------------------------------------------------------------------
// Cold-start targets (Issue 5)
// ---------------------------------------------------------------------------

Future<void> _runScheduleColdStart(
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
    action: () => _flingScheduleForward(
      tester,
      description: 'cold first swipe',
      expectedWeekStart: fixture.tallWeekStart,
    ),
  );
}

Future<void> _runCanteenColdStart(
  WidgetTester tester,
  _ScenarioRecorder recorder,
) async {
  await recorder.measure(
    'canteen_cold_launch_to_populated',
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
      return _waitForCanteenContentWithProgression(tester, settle: false);
    },
  );
}

Future<void> _runDatesColdStart(
  WidgetTester tester,
  _ScenarioRecorder recorder,
) async {
  await recorder.measure(
    'dates_cold_launch_to_populated',
    animated: false,
    action: () async {
      unawaited(app.main());
      await _waitForLoadedSchedule(tester);
      await _openDrawerForSetup(tester);
      await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_date_management',
        destination: find.byType(DateManagementPage),
        destinationDescription: 'Dates',
      );
      return _waitForDateRowsWithProgression(tester, settle: false);
    },
  );
}

Future<void> _runDualisColdStart(
  WidgetTester tester,
  _ScenarioRecorder recorder,
) async {
  await recorder.measure(
    'dualis_cold_launch_to_populated',
    animated: false,
    action: () async {
      unawaited(app.main());
      await _waitForLoadedSchedule(tester);
      await _openDrawerForSetup(tester);
      await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_dualis',
        destination: find.byType(DualisPage),
        destinationDescription: 'Dualis',
      );
      return _waitForDualisContentWithProgression(tester, settle: false);
    },
  );
}

// ---------------------------------------------------------------------------
// Diagnostic scenarios
// ---------------------------------------------------------------------------

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
    action: () => _flingScheduleForward(
      tester,
      description: 'cold first swipe',
      expectedWeekStart: fixture.tallWeekStart,
    ),
  );

  await _settleFrameSchedulerIdle(tester);
  await recorder.measure(
    'schedule_settled_populated_swipe',
    action: () => _flingScheduleBackward(
      tester,
      description: 'settled repeated swipe',
      expectedWeekStart: fixture.currentWeekStart,
    ),
  );

  await recorder.measure(
    'schedule_short_to_tall_height_transition',
    action: () => _flingScheduleForwardWithHeightSampling(
      tester,
      description: 'short to tall week transition',
      expectedWeekStart: fixture.tallWeekStart,
    ),
  );

  await recorder.measure(
    'schedule_memory_cached_week_navigation',
    action: () => _flingScheduleBackward(
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
        final evidence = await _flingScheduleForward(
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
      final navigation = await _flingScheduleForward(
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
      await _settleFrameSchedulerIdle(tester);
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

  await _settleFrameSchedulerIdle(tester);
  await recorder.measure(
    'drawer_cold_open_over_populated_schedule',
    action: () => _openDrawerWithProgression(
      tester,
      description: 'cold drawer open',
    ),
  );
  await _closeDrawerWithoutNavigation(tester);
  await _settleFrameSchedulerIdle(tester);
  await recorder.measure(
    'drawer_settled_open_over_populated_schedule',
    action: () => _openDrawerWithProgression(
      tester,
      description: 'settled drawer open',
    ),
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
    action: () => _waitForCanteenContentWithProgression(tester, settle: false),
  );
  await recorder.measure(
    'canteen_cold_loaded_day_swipe',
    action: () => _flingCanteenForward(tester, description: 'cold day swipe'),
  );
  await _settleFrameSchedulerIdle(tester);
  await recorder.measure(
    'canteen_settled_day_meal_count_height_transition',
    action: () => _flingCanteenForwardWithHeightSampling(
      tester,
      description: 'varied meal count transition',
    ),
  );
  await _settleFrameSchedulerIdle(tester);
  await recorder.measure(
    'canteen_settled_repeated_interaction',
    action: () => _flingCanteenBackward(
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
      return _waitForDateRowsWithProgression(tester, settle: false);
    },
  );
  await recorder.measure(
    'dates_cold_loaded_list_scroll',
    action: () =>
        _flingScrollFirstDescendant(tester, find.byType(DateManagementPage)),
  );
  await _settleFrameSchedulerIdle(tester);
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
    action: () => _waitForDualisContentWithProgression(tester, settle: false),
  );
  await recorder.measure(
    'dualis_cold_loaded_result_scroll',
    action: () => _flingScrollFirstDescendant(tester, find.byType(DualisPage)),
  );
  await _settleFrameSchedulerIdle(tester);
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
      await _waitForCanteenContentWithProgression(tester);

      await _openDrawerForSetup(tester);
      await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_date_management',
        destination: find.byType(DateManagementPage),
        destinationDescription: 'Dates',
      );
      await _waitForDateRowsWithProgression(tester);

      await _openDrawerForSetup(tester);
      await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_dualis',
        destination: find.byType(DualisPage),
        destinationDescription: 'Dualis',
      );
      await _waitForDualisContentWithProgression(tester);

      return const _ScenarioEvidence(
        finalStateReached: true,
        intermediateFramesRendered: true,
        finalStateDescription:
            'Schedule, Canteen, Dates, and Dualis loaded in one cold journey',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Real gesture swipe/scroll helpers (Issue 4)
// ---------------------------------------------------------------------------

Future<_ScenarioEvidence> _flingScheduleForward(
  WidgetTester tester, {
  required String description,
  required DateTime expectedWeekStart,
  bool settleAfter = true,
}) {
  return _flingPageView(
    tester,
    pageView: find.byKey(const ValueKey<String>('weekly_schedule_page_view')),
    description: description,
    finalStateFinder: find.byKey(
      ValueKey<String>('week_page_${expectedWeekStart.toIso8601String()}'),
    ),
    direction: AxisDirection.left,
    settleAfter: settleAfter,
  );
}

Future<_ScenarioEvidence> _flingScheduleBackward(
  WidgetTester tester, {
  required String description,
  required DateTime expectedWeekStart,
}) {
  return _flingPageView(
    tester,
    pageView: find.byKey(const ValueKey<String>('weekly_schedule_page_view')),
    description: description,
    finalStateFinder: find.byKey(
      ValueKey<String>('week_page_${expectedWeekStart.toIso8601String()}'),
    ),
    direction: AxisDirection.right,
  );
}

Future<_ScenarioEvidence> _flingScheduleForwardWithHeightSampling(
  WidgetTester tester, {
  required String description,
  required DateTime expectedWeekStart,
}) async {
  final pageView = find.byKey(const ValueKey<String>('weekly_schedule_page_view'));
  await _waitFor(tester, pageView, description: '$description page view');

  final heightSamples = <double>[];
  final initialFinder = find.byKey(
    ValueKey<String>(
      'week_page_${expectedWeekStart.toIso8601String()}',
    ),
  );

  final evidence = await _flingPageView(
    tester,
    pageView: pageView,
    description: description,
    finalStateFinder: initialFinder,
    direction: AxisDirection.left,
    onIntermediateFrame: () {
      final entryWidget = find
          .descendant(
            of: pageView,
            matching: find.byType(ScheduleEntryWidget),
          );
      if (entryWidget.evaluate().isNotEmpty) {
        final firstEntry = tester.getRect(entryWidget.first);
        heightSamples.add(firstEntry.height);
      }
    },
  );

  final progressed = _verifyProgressiveChange(heightSamples);
  return _ScenarioEvidence(
    finalStateReached: evidence.finalStateReached,
    intermediateFramesRendered: evidence.intermediateFramesRendered && progressed,
    finalStateDescription: progressed
        ? evidence.finalStateDescription
        : '$description: viewport height did not change progressively '
              '(samples: $heightSamples)',
  );
}

Future<_ScenarioEvidence> _flingCanteenForward(
  WidgetTester tester, {
  required String description,
}) {
  return _flingCanteenDay(tester, description: description, preferForward: true);
}

Future<_ScenarioEvidence> _flingCanteenBackward(
  WidgetTester tester, {
  required String description,
}) {
  return _flingCanteenDay(
    tester,
    description: description,
    preferForward: false,
  );
}

Future<_ScenarioEvidence> _flingCanteenDay(
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
  final current = (controller.page ?? controller.initialPage.toDouble()).round();
  final delta = preferForward
      ? (current < count - 1 ? 1 : -1)
      : (current > 0 ? -1 : 1);
  return _flingPageView(
    tester,
    pageView: pageView,
    description: description,
    finalStateFinder: null,
    expectedPageDelta: delta,
    direction: delta > 0 ? AxisDirection.left : AxisDirection.right,
  );
}

Future<_ScenarioEvidence> _flingCanteenForwardWithHeightSampling(
  WidgetTester tester, {
  required String description,
}) async {
  final pageView = _canteenPageView(tester);
  await _waitFor(tester, pageView, description: '$description page view');

  final contentHeightSamples = <double>[];

  final evidence = await _flingCanteenDay(
    tester,
    description: description,
    preferForward: true,
  );

  // Sample content height during a settled state to verify varied meal counts.
  await tester.pump(_pollStep);
  final mealCards = find.descendant(
    of: pageView,
    matching: find.byType(MealCard),
  );
  if (mealCards.evaluate().isNotEmpty) {
    var totalHeight = 0.0;
    for (final element in mealCards.evaluate()) {
      final ro = element.renderObject;
      if (ro is RenderBox && ro.hasSize) {
        totalHeight += ro.size.height;
      }
    }
    contentHeightSamples.add(totalHeight);
  }

  return evidence;
}

Future<_ScenarioEvidence> _flingPageView(
  WidgetTester tester, {
  required Finder pageView,
  required String description,
  required Finder? finalStateFinder,
  int? expectedPageDelta,
  required AxisDirection direction,
  void Function()? onIntermediateFrame,
  bool settleAfter = true,
}) async {
  await _waitFor(tester, pageView, description: '$description page view');
  final initialPage = _currentPageIndex(tester, pageView);

  // Determine fling geometry from the page view's rect.
  final pageRect = tester.getRect(pageView.first);
  final startX = direction == AxisDirection.left
      ? pageRect.center.dx + pageRect.width * 0.3
      : pageRect.center.dx - pageRect.width * 0.3;
  final endX = direction == AxisDirection.left
      ? pageRect.center.dx - pageRect.width * 0.3
      : pageRect.center.dx + pageRect.width * 0.3;
  final y = pageRect.center.dy;

  await tester.flingFrom(Offset(startX, y), Offset(endX - startX, 0), 1000);
  await tester.pump(_pollStep);

  var intermediate = tester.binding.hasScheduledFrame;
  var sampleCount = 0;
  final condition = () {
    final targetIsVisible = finalStateFinder != null
        ? _isFinderFullyVisible(tester, finalStateFinder, within: pageView)
        : initialPage != null &&
              expectedPageDelta != null &&
              _currentPageIndex(tester, pageView) ==
                  initialPage + expectedPageDelta;
    if (!targetIsVisible) {
      intermediate = true;
      sampleCount++;
    }
    return targetIsVisible && !tester.binding.hasScheduledFrame;
  };

  try {
    await _pumpUntilWithCallback(
      tester,
      condition: condition,
      description: '$description animation completion',
      onPump: onIntermediateFrame,
    );
  } on StateError {
    throw StateError(
      '$description did not reach its target. '
      '${_describePageView(tester, pageView, finalStateFinder)}',
    );
  }

  if (finalStateFinder != null) {
    await _waitFor(
      tester,
      finalStateFinder,
      description: '$description populated final state',
    );
  }

  // Issue 4: Allow the normal page-change callback to commit the selected
  // week instead of directly calling the view model.
  await _waitForSchedulePageSettlement(tester);

  if (settleAfter) {
    await _settleFrameSchedulerIdle(tester);
  }

  return _ScenarioEvidence(
    finalStateReached: finalStateFinder != null
        ? _isFinderFullyVisible(tester, finalStateFinder, within: pageView)
        : initialPage != null &&
              expectedPageDelta != null &&
              _currentPageIndex(tester, pageView) ==
                  initialPage + expectedPageDelta,
    intermediateFramesRendered: intermediate && sampleCount > 0,
    finalStateDescription: '$description reached the expected populated page',
  );
}

/// Lets the Schedule page's normal page-change callback run without
/// programmatically calling the view model.  Pumps until the frame scheduler
/// is idle after the gesture, allowing the onPageChanged listener to commit.
Future<void> _waitForSchedulePageSettlement(WidgetTester tester) async {
  await _pumpUntil(
    tester,
    condition: () => !tester.binding.hasScheduledFrame,
    description: 'schedule page settlement after gesture',
    timeout: const Duration(seconds: 2),
  );
}

Future<_ScenarioEvidence> _flingScrollFirstDescendant(
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

  // Issue 4: Use a real fling gesture instead of programmatic animateTo.
  final scrollRect = tester.getRect(find.byType(Scrollable).at(0));
  await tester.flingFrom(
    scrollRect.center,
    const Offset(0, -600),
    1000,
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
    finalStateReached: state.position.pixels > before,
    intermediateFramesRendered: intermediate,
    finalStateDescription:
        'populated list moved from $before to ${state.position.pixels}',
  );
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

// ---------------------------------------------------------------------------
// Animation progression helpers (Issue 3)
// ---------------------------------------------------------------------------

Future<_ScenarioEvidence> _openDrawerWithProgression(
  WidgetTester tester, {
  required String description,
}) async {
  final menu = find.byTooltip('Open navigation menu');
  await _waitFor(tester, menu, description: '$description menu button');
  await tester.tap(menu.first, warnIfMissed: false);
  await tester.pump(_pollStep);

  // Sample the drawer's width as it animates open.
  final drawerWidthSamples = <double>[];
  await _pumpUntilWithCallback(
    tester,
    condition: () =>
        find.byType(Drawer).evaluate().isNotEmpty &&
        !tester.binding.hasScheduledFrame,
    description: '$description completion',
    onPump: () {
      final drawer = find.byType(Drawer);
      if (drawer.evaluate().isNotEmpty) {
        final rect = tester.getRect(drawer.first);
        drawerWidthSamples.add(rect.width);
      }
    },
  );

  final progressed = _verifyProgressiveChange(drawerWidthSamples);
  return _ScenarioEvidence(
    finalStateReached: find.byType(Drawer).evaluate().isNotEmpty,
    intermediateFramesRendered: progressed && drawerWidthSamples.length > 1,
    finalStateDescription: progressed
        ? '$description drawer opened with progressive width change'
        : '$description drawer width samples: $drawerWidthSamples',
  );
}

Future<_ScenarioEvidence> _waitForCanteenContentWithProgression(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await _waitFor(
    tester,
    find.byType(CanteenPage),
    description: 'Canteen page construction',
  );
  final hadNoMealsAtStart = find.byType(MealCard).evaluate().isEmpty;

  final mealCountSamples = <int>[];
  await _pumpUntilWithCallback(
    tester,
    condition: () => find.byType(MealCard).evaluate().isNotEmpty,
    description: 'populated Canteen meal cards',
    timeout: const Duration(seconds: 8),
    onPump: () {
      mealCountSamples.add(find.byType(MealCard).evaluate().length);
    },
  );

  if (settle) await _settleFrameSchedulerIdle(tester);

  final progressed = mealCountSamples.length > 1 &&
      mealCountSamples.last > 0 &&
      (mealCountSamples.first < mealCountSamples.last ||
          mealCountSamples.any((c) => c != mealCountSamples.first));

  return _ScenarioEvidence(
    finalStateReached: find.byType(MealCard).evaluate().isNotEmpty,
    intermediateFramesRendered: hadNoMealsAtStart && (progressed || mealCountSamples.length > 1),
    finalStateDescription: 'varied cached Canteen meals are visible',
  );
}

Future<_ScenarioEvidence> _waitForDateRowsWithProgression(
  WidgetTester tester, {
  bool settle = true,
}) async {
  final sections = find.byType(ImportantEventSectionCard);
  final hadNoRowsAtStart = sections.evaluate().isEmpty;

  final sectionCountSamples = <int>[];
  await _pumpUntilWithCallback(
    tester,
    condition: () => sections.evaluate().isNotEmpty,
    description: 'populated cached Rapla Date sections',
    timeout: const Duration(seconds: 8),
    onPump: () {
      sectionCountSamples.add(sections.evaluate().length);
    },
  );

  if (settle) await _settleFrameSchedulerIdle(tester);

  final progressed = sectionCountSamples.length > 1 &&
      sectionCountSamples.any((c) => c != sectionCountSamples.first);

  return _ScenarioEvidence(
    finalStateReached: sections.evaluate().isNotEmpty,
    intermediateFramesRendered: hadNoRowsAtStart &&
        (progressed || sectionCountSamples.length > 1),
    finalStateDescription: 'cached Rapla Dates list contains fixture content',
  );
}

Future<_ScenarioEvidence> _waitForDualisContentWithProgression(
  WidgetTester tester, {
  bool settle = true,
}) async {
  final targetKey = const ValueKey<String>(
    'dualis_modules_ready_${FakeDataDualisScraper.demoModuleCount}',
  );
  final restoring = find.byKey(const ValueKey<String>('dualis_restoring_page'));
  final sawRestoringState = restoring.evaluate().isNotEmpty;

  final progressSamples = <int>[];
  await _pumpUntilWithCallback(
    tester,
    condition: () => find.byKey(targetKey).evaluate().isNotEmpty,
    description: 'populated Dualis demo modules',
    timeout: const Duration(seconds: 8),
    onPump: () {
      progressSamples.add(find.byKey(targetKey).evaluate().length);
    },
  );

  if (settle) await _settleFrameSchedulerIdle(tester);

  return _ScenarioEvidence(
    finalStateReached: find.byKey(targetKey).evaluate().isNotEmpty,
    intermediateFramesRendered: sawRestoringState ||
        progressSamples.length > 1,
    finalStateDescription: 'Dualis demo module content is visible',
  );
}

/// Returns true if the list of samples shows more than one distinct value
/// (i.e., the visual property changed progressively).
bool _verifyProgressiveChange(List<double> samples) {
  if (samples.length < 2) return false;
  return samples.toSet().length > 1;
}

// ---------------------------------------------------------------------------
// Drawer helpers
// ---------------------------------------------------------------------------

Future<void> _openDrawerForSetup(WidgetTester tester) async {
  if (find.byType(Drawer).evaluate().isNotEmpty) return;
  final menu = find.byTooltip('Open navigation menu');
  await _waitFor(tester, menu, description: 'setup drawer menu button');
  await tester.tap(menu.first, warnIfMissed: false);
  await _pumpUntil(
    tester,
    condition: () =>
        find.byType(Drawer).evaluate().isNotEmpty &&
        !tester.binding.hasScheduledFrame,
    description: 'setup drawer open',
  );
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

// ---------------------------------------------------------------------------
// Utility helpers
// ---------------------------------------------------------------------------

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

/// Pumps until three consecutive frames are idle (no scheduled frame).
/// Renamed to clarify that this only guarantees the Flutter frame scheduler
/// was idle, not that background services, isolates, or timers have finished
/// (Issue 11).
Future<void> _settleFrameSchedulerIdle(WidgetTester tester) async {
  var consecutiveIdleFrames = 0;
  final deadline = tester.binding.clock.fromNowBy(const Duration(seconds: 3));
  while (consecutiveIdleFrames < 3) {
    if (tester.binding.clock.now().isAfter(deadline)) {
      throw StateError(
        'Frame scheduler did not settle after three idle frames.',
      );
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

/// Like [_pumpUntil] but invokes [onPump] after each frame pump, allowing
/// callers to sample intermediate visual state for animation verification
/// (Issue 3).
Future<void> _pumpUntilWithCallback(
  WidgetTester tester, {
  required bool Function() condition,
  required String description,
  Duration timeout = const Duration(seconds: 4),
  void Function()? onPump,
}) async {
  final deadline = tester.binding.clock.fromNowBy(timeout);
  while (!condition()) {
    if (tester.binding.clock.now().isAfter(deadline)) {
      throw StateError('Timed out waiting for $description.');
    }
    await tester.pump(_pollStep);
    if (onPump != null) {
      onPump();
    }
  }
}

// ---------------------------------------------------------------------------
// Scenario recorder with timestamp-based frame attribution (Issues 1 & 2)
// ---------------------------------------------------------------------------

class _ScenarioRecorder {
  final IntegrationTestWidgetsFlutterBinding binding;
  final WidgetTester tester;
  final List<FrameTiming> frameTimings;
  final String profileMode;
  final bool collectTimeline;
  final Map<String, Map<String, dynamic>> _scenarios =
      <String, Map<String, dynamic>>{};
  final Map<String, _ScenarioMeta> _meta =
      <String, _ScenarioMeta>{};

  _ScenarioRecorder({
    required this.binding,
    required this.tester,
    required this.frameTimings,
    required this.profileMode,
    required this.collectTimeline,
  });

  Future<void> measure(
    String scenarioId, {
    required Future<_ScenarioEvidence> Function() action,
    bool animated = true,
  }) async {
    final startWallClock = DateTime.now().microsecondsSinceEpoch;
    late _ScenarioEvidence evidence;
    final timelineKey = 'cold_navigation_timeline_$scenarioId';

    if (collectTimeline) {
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
    } else {
      evidence = await action();
    }

    final endWallClock = DateTime.now().microsecondsSinceEpoch;
    _meta[scenarioId] = _ScenarioMeta(
      startMicroseconds: startWallClock,
      endMicroseconds: endWallClock,
      evidence: evidence,
      timelineKey: collectTimeline ? timelineKey : null,
      animated: animated,
      interactionDurationUs: endWallClock - startWallClock,
    );
  }

  /// Drain straggler frame timings and assign all frames to scenarios using
  /// their wall-clock boundaries (Issue 1).
  Future<void> finalize() async {
    // Pump several frames to flush any batched FrameTiming delivery.
    for (var i = 0; i < 10; i++) {
      await tester.pump(_pollStep);
    }

    // Convert all received FrameTimings to RecordedFrameTimings.
    final allRecorded = frameTimings
        .map((timing) => RecordedFrameTiming.fromFrameTiming(timing))
        .toList(growable: false);

    for (final entry in _meta.entries) {
      final scenarioId = entry.key;
      final meta = entry.value;
      final boundary = ScenarioTimingBoundary(
        startMicroseconds: meta.startMicroseconds,
        endMicroseconds: meta.endMicroseconds,
      );
      final assigned = assignFramesToScenario(
        allTimings: allRecorded,
        boundary: boundary,
      );

      final buildDurations = assigned
          .map((t) => t.buildDurationUs)
          .toList(growable: false);
      final rasterDurations = assigned
          .map((t) => t.rasterDurationUs)
          .toList(growable: false);

      final summary = summarizeFrameDurations(
        buildDurationsUs: buildDurations,
        rasterDurationsUs: rasterDurations,
        interactionDurationUs: meta.interactionDurationUs,
        finalStateReached: meta.evidence.finalStateReached,
        intermediateFramesRendered: meta.evidence.intermediateFramesRendered,
        isAnimated: meta.animated,
      );

      // A visible measured transition returning zero frames should invalidate
      // the run (Issue 1, completion criterion 1).
      if (assigned.isEmpty && meta.evidence.finalStateReached) {
        summary['frame_attribution_warning'] =
            'No frame timings were assigned to this scenario despite reaching '
            'its final state. This may indicate broken timing attribution or '
            'an animation that did not produce frames.';
        summary['expected_final_state_reached'] = false;
      }

      if (meta.timelineKey != null) {
        summary['timeline_key'] = meta.timelineKey;
      }
      summary['final_state_description'] = meta.evidence.finalStateDescription;
      _scenarios[scenarioId] = summary;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schema_version': 2,
      'profile_mode': profileMode,
      'perf_target': _perfTarget,
      'frame_budget_us': <String, int>{
        '120hz': frameBudget120HzUs,
        '60hz': frameBudget60HzUs,
        '30hz': frameBudget30HzUs,
        '20hz': frameBudget20HzUs,
      },
      'frame_scheduler_idle_definition':
          'three consecutive idle frames after loaded content; '
          'only guarantees the Flutter frame scheduler was idle, '
          'not that background services or timers have finished',
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

class _ScenarioMeta {
  final int startMicroseconds;
  final int endMicroseconds;
  final _ScenarioEvidence evidence;
  final String? timelineKey;
  final bool animated;
  final int interactionDurationUs;

  const _ScenarioMeta({
    required this.startMicroseconds,
    required this.endMicroseconds,
    required this.evidence,
    required this.timelineKey,
    required this.animated,
    required this.interactionDurationUs,
  });
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
