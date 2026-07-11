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
      final collectTimeline = _profileMode != 'ranking';
      final recorder = _ScenarioRecorder(
        binding: binding,
        tester: tester,
        profileMode: _profileMode,
        collectTimeline: collectTimeline,
      );
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
            await _runCombinedJourney(tester, recorder, fixture);
          default:
            if (_profileMode == 'combined') {
              await _runCombinedJourney(tester, recorder, fixture);
            } else {
              await _runDiagnosticScenarios(tester, recorder, fixture);
            }
        }
      } catch (error, stack) {
        harnessFailure = error;
        harnessFailureStack = stack;
        rethrow;
      } finally {
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

  await recorder.measure(
    'schedule_rapid_back_swipe_burst',
    action: () async {
      final expectedWeeks = <DateTime>[
        fixture.databaseCachedWeekStart,
        fixture.intermediateWeekStart,
        fixture.tallWeekStart,
        fixture.currentWeekStart,
      ];
      final progressions = <String, bool>{};
      var finalStateReached = true;
      for (var index = 0; index < expectedWeeks.length; index++) {
        final evidence = await _flingScheduleBackward(
          tester,
          description: 'rapid Schedule back swipe ${index + 1}',
          expectedWeekStart: expectedWeeks[index],
          settleAfter: false,
          waitForSelectedWeekState: false,
        );
        finalStateReached = finalStateReached && evidence.finalStateReached;
        progressions['rapid_back_swipe_${index + 1}'] =
            evidence.intermediateFramesRendered;
      }
      await _waitForScheduleWeekState(tester, fixture.currentWeekStart);
      await _settleFrameSchedulerIdle(tester);
      return _ScenarioEvidence(
        finalStateReached: finalStateReached,
        intermediateFramesRendered: progressions.values.every(
          (progressed) => progressed,
        ),
        finalStateDescription:
            'four rapid populated Schedule swipes completed while week '
            'selection work overlapped',
        animationChecks: progressions,
      );
    },
  );

  await _settleFrameSchedulerIdle(tester);
  await recorder.measure(
    'drawer_cold_open_over_populated_schedule',
    action: () =>
        _openDrawerWithProgression(tester, description: 'cold drawer open'),
  );
  await recorder.measure(
    'drawer_cold_close_over_populated_schedule',
    action: () =>
        _closeDrawerWithProgression(tester, description: 'cold drawer close'),
  );
  await _settleFrameSchedulerIdle(tester);
  await recorder.measure(
    'drawer_settled_open_over_populated_schedule',
    action: () =>
        _openDrawerWithProgression(tester, description: 'settled drawer open'),
  );
  await recorder.measure(
    'drawer_settled_close_over_populated_schedule',
    action: () => _closeDrawerWithProgression(
      tester,
      description: 'settled drawer close',
    ),
  );

  await _openDrawerForSetup(tester);
  await recorder.measure(
    'drawer_close_to_canteen_and_populated_content',
    action: () async {
      final drawer = await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_canteen',
        destination: find.byType(CanteenPage),
        destinationDescription: 'Canteen',
      );
      final content = await _waitForCanteenContentWithProgression(
        tester,
        settle: false,
      );
      return _combineEvidence(
        drawer,
        content,
        description: 'drawer close, Canteen construction, and cached content',
      );
    },
  );
  await recorder.measure(
    'canteen_cold_loaded_day_swipe',
    action: () => _flingCanteenForward(tester, description: 'cold day swipe'),
  );
  await _settleFrameSchedulerIdle(tester);
  await recorder.measure(
    'canteen_settled_varied_meal_content_transition',
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
    'drawer_close_to_dates_and_populated_content',
    action: () async {
      final drawer = await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_date_management',
        destination: find.byType(DateManagementPage),
        destinationDescription: 'Dates',
      );
      final content = await _waitForDateRowsWithProgression(
        tester,
        settle: false,
      );
      return _combineEvidence(
        drawer,
        content,
        description: 'drawer close, Dates construction, and cached content',
      );
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
    'drawer_close_to_dualis_and_populated_content',
    action: () async {
      final drawer = await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_dualis',
        destination: find.byType(DualisPage),
        destinationDescription: 'Dualis',
      );
      final content = await _waitForDualisContentWithProgression(
        tester,
        settle: false,
      );
      return _combineEvidence(
        drawer,
        content,
        description: 'drawer close, Dualis restore, and populated modules',
      );
    },
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
  ColdNavigationFixture fixture,
) async {
  await recorder.measure(
    'combined_aggressive_real_world_journey',
    action: () async {
      unawaited(app.main());
      await _waitForLoadedSchedule(tester);
      await _waitForWeeklyScheduleInitialization(tester);

      final scheduleForward = await _flingScheduleForward(
        tester,
        description: 'combined fast Schedule forward swipe',
        expectedWeekStart: fixture.tallWeekStart,
        settleAfter: false,
        waitForSelectedWeekState: false,
      );
      final scheduleBack = await _flingScheduleBackward(
        tester,
        description: 'combined fast Schedule backward swipe',
        expectedWeekStart: fixture.currentWeekStart,
        settleAfter: false,
        waitForSelectedWeekState: false,
      );
      final scheduleForwardAgain = await _flingScheduleForward(
        tester,
        description: 'combined second fast Schedule forward swipe',
        expectedWeekStart: fixture.tallWeekStart,
        settleAfter: false,
        waitForSelectedWeekState: false,
      );
      final scheduleForwardThird = await _flingScheduleForward(
        tester,
        description: 'combined third fast Schedule forward swipe',
        expectedWeekStart: fixture.intermediateWeekStart,
        settleAfter: false,
        waitForSelectedWeekState: false,
      );
      await _waitForScheduleWeekState(tester, fixture.intermediateWeekStart);
      await _settleFrameSchedulerIdle(tester);

      await _openDrawerForSetup(tester);
      final canteenDrawer = await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_canteen',
        destination: find.byType(CanteenPage),
        destinationDescription: 'Canteen',
      );
      final canteenContent = await _waitForCanteenContentWithProgression(
        tester,
      );
      final canteenForward = await _flingCanteenForward(
        tester,
        description: 'combined fast Canteen forward swipe',
      );
      final canteenBack = await _flingCanteenBackward(
        tester,
        description: 'combined fast Canteen backward swipe',
      );

      await _openDrawerForSetup(tester);
      final datesDrawer = await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_date_management',
        destination: find.byType(DateManagementPage),
        destinationDescription: 'Dates',
      );
      final datesContent = await _waitForDateRowsWithProgression(tester);
      final datesScroll = await _flingScrollFirstDescendant(
        tester,
        find.byType(DateManagementPage),
      );

      await _openDrawerForSetup(tester);
      final dualisDrawer = await _selectDrawerDestination(
        tester,
        keyName: 'drawer_item_dualis',
        destination: find.byType(DualisPage),
        destinationDescription: 'Dualis',
      );
      final dualisContent = await _waitForDualisContentWithProgression(tester);
      final dualisScroll = await _flingScrollFirstDescendant(
        tester,
        find.byType(DualisPage),
      );
      final dualisTab = await _switchDualisTab(tester);

      final evidence = <_ScenarioEvidence>[
        scheduleForward,
        scheduleBack,
        scheduleForwardAgain,
        scheduleForwardThird,
        canteenDrawer,
        canteenContent,
        canteenForward,
        canteenBack,
        datesDrawer,
        datesContent,
        datesScroll,
        dualisDrawer,
        dualisContent,
        dualisScroll,
        dualisTab,
      ];
      final requiredProgressions = <String, bool>{
        'schedule_forward_progression':
            scheduleForward.intermediateFramesRendered,
        'schedule_backward_progression':
            scheduleBack.intermediateFramesRendered,
        'schedule_second_forward_progression':
            scheduleForwardAgain.intermediateFramesRendered,
        'schedule_third_forward_progression':
            scheduleForwardThird.intermediateFramesRendered,
        'canteen_drawer_progression': canteenDrawer.intermediateFramesRendered,
        'canteen_forward_progression':
            canteenForward.intermediateFramesRendered,
        'canteen_backward_progression': canteenBack.intermediateFramesRendered,
        'dates_drawer_progression': datesDrawer.intermediateFramesRendered,
        'dates_scroll_progression': datesScroll.intermediateFramesRendered,
        'dualis_drawer_progression': dualisDrawer.intermediateFramesRendered,
        'dualis_scroll_progression': dualisScroll.intermediateFramesRendered,
      };

      return _ScenarioEvidence(
        finalStateReached: evidence.every((item) => item.finalStateReached),
        intermediateFramesRendered: requiredProgressions.values.every(
          (progressed) => progressed,
        ),
        finalStateDescription:
            'Fast loaded interactions completed across Schedule, Canteen, '
            'Dates, and Dualis',
        animationChecks: requiredProgressions,
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
  bool waitForSelectedWeekState = true,
}) async {
  final evidence = await _flingPageView(
    tester,
    pageView: find.byKey(const ValueKey<String>('weekly_schedule_page_view')),
    description: description,
    finalStateFinder: find.byKey(
      ValueKey<String>('week_page_${expectedWeekStart.toIso8601String()}'),
    ),
    direction: AxisDirection.left,
    settleAfter: false,
  );
  if (waitForSelectedWeekState) {
    await _waitForScheduleWeekState(tester, expectedWeekStart);
  }
  if (settleAfter) {
    await _settleFrameSchedulerIdle(tester);
  }
  return evidence;
}

Future<_ScenarioEvidence> _flingScheduleBackward(
  WidgetTester tester, {
  required String description,
  required DateTime expectedWeekStart,
  bool settleAfter = true,
  bool waitForSelectedWeekState = true,
}) async {
  final evidence = await _flingPageView(
    tester,
    pageView: find.byKey(const ValueKey<String>('weekly_schedule_page_view')),
    description: description,
    finalStateFinder: find.byKey(
      ValueKey<String>('week_page_${expectedWeekStart.toIso8601String()}'),
    ),
    direction: AxisDirection.right,
    settleAfter: false,
  );
  if (waitForSelectedWeekState) {
    await _waitForScheduleWeekState(tester, expectedWeekStart);
  }
  if (settleAfter) {
    await _settleFrameSchedulerIdle(tester);
  }
  return evidence;
}

Future<_ScenarioEvidence> _flingScheduleForwardWithHeightSampling(
  WidgetTester tester, {
  required String description,
  required DateTime expectedWeekStart,
}) async {
  final pageView = find.byKey(
    const ValueKey<String>('weekly_schedule_page_view'),
  );
  await _waitFor(tester, pageView, description: '$description page view');

  final targetFinder = find.byKey(
    ValueKey<String>('week_page_${expectedWeekStart.toIso8601String()}'),
  );
  final hourAxis = find.byKey(const ValueKey<String>('weekly_fixed_hour_axis'));
  final viewportSamples = <double>[];

  void sampleViewport() {
    final commonHourLabel = find.descendant(
      of: hourAxis,
      matching: find.text('9:00'),
    );
    if (commonHourLabel.evaluate().isNotEmpty) {
      viewportSamples.add(tester.getTopLeft(commonHourLabel.first).dy);
    }
  }

  sampleViewport();
  final evidence = await _flingPageView(
    tester,
    pageView: pageView,
    description: description,
    finalStateFinder: targetFinder,
    direction: AxisDirection.left,
    onIntermediateFrame: sampleViewport,
  );
  sampleViewport();

  final weeklyPage = find.byType(WeeklySchedulePage);
  await _pumpUntilWithCallback(
    tester,
    condition: () {
      final context = tester.element(weeklyPage.first);
      final model = Provider.of<WeeklyScheduleViewModel>(
        context,
        listen: false,
      );
      return _isSameCalendarDay(model.currentDateStart, expectedWeekStart);
    },
    description: '$description selected week state',
    timeout: const Duration(seconds: 4),
    onPump: sampleViewport,
  );
  await _pumpUntilWithCallback(
    tester,
    condition: () => !tester.binding.hasScheduledFrame,
    description: '$description hour viewport animation completion',
    onPump: sampleViewport,
  );
  sampleViewport();

  final progressed = _verifyProgressiveChange(viewportSamples);
  return _ScenarioEvidence(
    finalStateReached: evidence.finalStateReached,
    intermediateFramesRendered:
        evidence.intermediateFramesRendered && progressed,
    finalStateDescription: progressed
        ? evidence.finalStateDescription
        : '$description: hour viewport did not animate progressively '
              '(9:00 label positions: $viewportSamples)',
    animationChecks: <String, bool>{
      ...evidence.animationChecks,
      'hour_viewport_progression': progressed,
    },
  );
}

Future<_ScenarioEvidence> _flingCanteenForward(
  WidgetTester tester, {
  required String description,
}) {
  return _flingCanteenDay(
    tester,
    description: description,
    preferForward: true,
  );
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
  void Function()? onIntermediateFrame,
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
  return _flingPageView(
    tester,
    pageView: pageView,
    description: description,
    finalStateFinder: null,
    expectedPageDelta: delta,
    direction: delta > 0 ? AxisDirection.left : AxisDirection.right,
    onIntermediateFrame: onIntermediateFrame,
  );
}

Future<_ScenarioEvidence> _flingCanteenForwardWithHeightSampling(
  WidgetTester tester, {
  required String description,
}) async {
  final pageView = _canteenPageView(tester);
  await _waitFor(tester, pageView, description: '$description page view');

  final visibleContentSamples = <double>[];
  void sampleVisibleContent() {
    visibleContentSamples.add(_visibleMealCardArea(tester, pageView));
  }

  sampleVisibleContent();
  final evidence = await _flingCanteenDay(
    tester,
    description: description,
    preferForward: true,
    onIntermediateFrame: sampleVisibleContent,
  );
  sampleVisibleContent();

  final progressed = _verifyProgressiveChange(visibleContentSamples);
  return _ScenarioEvidence(
    finalStateReached: evidence.finalStateReached,
    intermediateFramesRendered:
        evidence.intermediateFramesRendered && progressed,
    finalStateDescription: progressed
        ? '$description rendered progressively changing visible meal content'
        : '$description did not show a progressive meal-content transition '
              '(visible areas: $visibleContentSamples)',
    animationChecks: <String, bool>{
      ...evidence.animationChecks,
      'meal_content_progression': progressed,
    },
  );
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
  final pagePositionSamples = <double>[];

  void sampleProgress() {
    final page = _currentPagePosition(tester, pageView);
    if (page != null) pagePositionSamples.add(page);
    onIntermediateFrame?.call();
  }

  sampleProgress();
  final pageRect = tester.getRect(pageView.first);
  final startX = direction == AxisDirection.left
      ? pageRect.center.dx + pageRect.width * 0.35
      : pageRect.center.dx - pageRect.width * 0.35;
  final totalOffset = direction == AxisDirection.left
      ? -pageRect.width * 0.72
      : pageRect.width * 0.72;
  final gesture = await tester.startGesture(Offset(startX, pageRect.center.dy));
  const moveSteps = 8;
  const eventStep = Duration(milliseconds: 8);
  for (var step = 1; step <= moveSteps; step++) {
    await gesture.moveTo(
      Offset(startX + totalOffset * step / moveSteps, pageRect.center.dy),
      timeStamp: eventStep * step,
    );
    await tester.pump(eventStep);
    sampleProgress();
  }
  await gesture.up(timeStamp: eventStep * (moveSteps + 1));
  await tester.pump(const Duration(milliseconds: 8));
  sampleProgress();

  final condition = () {
    final targetIsVisible = finalStateFinder != null
        ? _isFinderFullyVisible(tester, finalStateFinder, within: pageView)
        : initialPage != null &&
              expectedPageDelta != null &&
              _currentPageIndex(tester, pageView) ==
                  initialPage + expectedPageDelta;
    return targetIsVisible && !tester.binding.hasScheduledFrame;
  };

  try {
    await _pumpUntilWithCallback(
      tester,
      condition: condition,
      description: '$description animation completion',
      onPump: sampleProgress,
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

  if (settleAfter) {
    await _settleFrameSchedulerIdle(tester);
  }
  sampleProgress();

  final progressed = _verifyProgressiveChange(pagePositionSamples);
  return _ScenarioEvidence(
    finalStateReached: finalStateFinder != null
        ? _isFinderFullyVisible(tester, finalStateFinder, within: pageView)
        : initialPage != null &&
              expectedPageDelta != null &&
              _currentPageIndex(tester, pageView) ==
                  initialPage + expectedPageDelta,
    intermediateFramesRendered: progressed,
    finalStateDescription: progressed
        ? '$description reached the expected populated page'
        : '$description page-position samples: $pagePositionSamples',
    animationChecks: <String, bool>{'page_position_progression': progressed},
  );
}

Future<void> _waitForScheduleWeekState(
  WidgetTester tester,
  DateTime expectedWeekStart,
) async {
  final weeklyPage = find.byType(WeeklySchedulePage);
  await _waitFor(tester, weeklyPage, description: 'weekly schedule page');
  await _pumpUntil(
    tester,
    condition: () {
      final context = tester.element(weeklyPage.first);
      final model = Provider.of<WeeklyScheduleViewModel>(
        context,
        listen: false,
      );
      return _isSameCalendarDay(model.currentDateStart, expectedWeekStart);
    },
    description:
        'Schedule view model to select ${expectedWeekStart.toIso8601String()}',
    timeout: const Duration(seconds: 4),
  );
}

bool _isSameCalendarDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
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
  Finder? selectedScrollable;
  for (var index = 0; index < scrollable.evaluate().length; index++) {
    final candidateFinder = scrollable.at(index);
    final candidate = tester.state<ScrollableState>(candidateFinder);
    if (candidate.position.maxScrollExtent > candidate.position.pixels) {
      state = candidate;
      selectedScrollable = candidateFinder;
      break;
    }
  }
  if (state == null || selectedScrollable == null) {
    return const _ScenarioEvidence(
      finalStateReached: false,
      intermediateFramesRendered: false,
      finalStateDescription: 'no populated scrollable had forward extent',
    );
  }
  final before = state.position.pixels;

  // Issue 4: Use a real fling gesture instead of programmatic animateTo.
  final scrollRect = tester.getRect(selectedScrollable);
  await tester.flingFrom(
    scrollRect.center,
    const Offset(0, -900),
    4000,
    frameInterval: const Duration(milliseconds: 8),
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
    animationChecks: <String, bool>{
      'scroll_position_progression': intermediate,
    },
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

  final drawerLeftSamples = <double>[];
  await _pumpUntilWithCallback(
    tester,
    condition: () =>
        find.byType(Drawer).evaluate().isNotEmpty &&
        !tester.binding.hasScheduledFrame,
    description: '$description completion',
    onPump: () => _sampleDrawerLeft(tester, drawerLeftSamples),
  );
  _sampleDrawerLeft(tester, drawerLeftSamples);

  final progressed = _verifyProgressiveChange(drawerLeftSamples);
  return _ScenarioEvidence(
    finalStateReached: find.byType(Drawer).evaluate().isNotEmpty,
    intermediateFramesRendered: progressed,
    finalStateDescription: progressed
        ? '$description drawer translated progressively into view'
        : '$description drawer position samples: $drawerLeftSamples',
    animationChecks: <String, bool>{'drawer_translation': progressed},
  );
}

Future<_ScenarioEvidence> _closeDrawerWithProgression(
  WidgetTester tester, {
  required String description,
}) async {
  final drawer = find.byType(Drawer);
  await _waitFor(tester, drawer, description: '$description open drawer');
  final drawerLeftSamples = <double>[];
  _sampleDrawerLeft(tester, drawerLeftSamples);

  final screenRect = tester.getRect(find.byType(Scaffold).first);
  await tester.tapAt(Offset(screenRect.right - 8, screenRect.center.dy));
  await tester.pump(_pollStep);
  await _pumpUntilWithCallback(
    tester,
    condition: () =>
        find.byType(Drawer).evaluate().isEmpty &&
        !tester.binding.hasScheduledFrame,
    description: '$description completion',
    onPump: () => _sampleDrawerLeft(tester, drawerLeftSamples),
  );

  final progressed = _verifyProgressiveChange(drawerLeftSamples);
  return _ScenarioEvidence(
    finalStateReached: find.byType(Drawer).evaluate().isEmpty,
    intermediateFramesRendered: progressed,
    finalStateDescription: progressed
        ? '$description drawer translated progressively out of view'
        : '$description drawer position samples: $drawerLeftSamples',
    animationChecks: <String, bool>{'drawer_translation': progressed},
  );
}

void _sampleDrawerLeft(WidgetTester tester, List<double> samples) {
  final drawer = find.byType(Drawer);
  if (drawer.evaluate().isNotEmpty) {
    samples.add(tester.getTopLeft(drawer.first).dx);
  }
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

  final loading = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('canteen_state_loading_');
  }, description: 'Canteen loading state');
  final ready = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('canteen_state_ready_');
  }, description: 'Canteen ready state');
  var sawLoading = false;
  var sawReady = false;
  var sawOverlap = false;

  void sample() {
    final hasLoading = loading.evaluate().isNotEmpty;
    final hasReady = ready.evaluate().isNotEmpty;
    sawLoading = sawLoading || hasLoading;
    sawReady = sawReady || hasReady;
    sawOverlap = sawOverlap || (hasLoading && hasReady);
  }

  sample();
  await _pumpUntilWithCallback(
    tester,
    condition: () => find.byType(MealCard).evaluate().isNotEmpty,
    description: 'populated Canteen meal cards',
    timeout: const Duration(seconds: 8),
    onPump: sample,
  );
  await _pumpUntilWithCallback(
    tester,
    condition: () => !tester.binding.hasScheduledFrame,
    description: 'Canteen loading-to-content transition completion',
    onPump: sample,
  );
  sample();

  if (settle) await _settleFrameSchedulerIdle(tester);

  return _ScenarioEvidence(
    finalStateReached: find.byType(MealCard).evaluate().isNotEmpty,
    intermediateFramesRendered: sawOverlap,
    finalStateDescription:
        'cached Canteen meals are visible; loading=$sawLoading, '
        'ready=$sawReady, overlap=$sawOverlap',
    animationChecks: sawLoading
        ? <String, bool>{'canteen_loading_to_ready': sawOverlap}
        : const <String, bool>{},
  );
}

Future<_ScenarioEvidence> _waitForDateRowsWithProgression(
  WidgetTester tester, {
  bool settle = true,
}) async {
  final sections = find.byType(ImportantEventSectionCard);
  final loading = find.byType(LinearProgressIndicator);
  var sawLoading = false;
  var sawRows = false;
  var sawOverlap = false;

  void sample() {
    final hasLoading = loading.evaluate().isNotEmpty;
    final hasRows = sections.evaluate().isNotEmpty;
    sawLoading = sawLoading || hasLoading;
    sawRows = sawRows || hasRows;
    sawOverlap = sawOverlap || (hasLoading && hasRows);
  }

  sample();
  await _pumpUntilWithCallback(
    tester,
    condition: () => sections.evaluate().isNotEmpty,
    description: 'populated cached Rapla Date sections',
    timeout: const Duration(seconds: 8),
    onPump: sample,
  );
  await _pumpUntilWithCallback(
    tester,
    condition: () => !tester.binding.hasScheduledFrame,
    description: 'Dates loading indicator transition completion',
    onPump: sample,
  );
  sample();

  if (settle) await _settleFrameSchedulerIdle(tester);

  return _ScenarioEvidence(
    finalStateReached: sections.evaluate().isNotEmpty,
    intermediateFramesRendered: sawOverlap,
    finalStateDescription:
        'cached Rapla Dates are visible; loading=$sawLoading, '
        'rows=$sawRows, overlap=$sawOverlap',
    animationChecks: sawLoading
        ? <String, bool>{'dates_loading_to_rows': sawOverlap}
        : const <String, bool>{},
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
  final pager = find.byKey(const ValueKey<String>('dualis_logged_in_pager'));
  final modulesLoading = find.byKey(
    const ValueKey<String>('dualis_modules_loading'),
  );
  final modulesReady = find.byKey(targetKey);
  var sawRestoring = false;
  var sawSessionOverlap = false;
  var sawModuleOverlap = false;

  void sample() {
    final hasRestoring = restoring.evaluate().isNotEmpty;
    final hasPager = pager.evaluate().isNotEmpty;
    final hasModulesLoading = modulesLoading.evaluate().isNotEmpty;
    final hasModulesReady = modulesReady.evaluate().isNotEmpty;
    sawRestoring = sawRestoring || hasRestoring;
    sawSessionOverlap = sawSessionOverlap || (hasRestoring && hasPager);
    sawModuleOverlap =
        sawModuleOverlap || (hasModulesLoading && hasModulesReady);
  }

  sample();
  await _pumpUntilWithCallback(
    tester,
    condition: () => modulesReady.evaluate().isNotEmpty,
    description: 'populated Dualis demo modules',
    timeout: const Duration(seconds: 8),
    onPump: sample,
  );
  await _pumpUntilWithCallback(
    tester,
    condition: () => !tester.binding.hasScheduledFrame,
    description: 'Dualis loading-to-content transition completion',
    onPump: sample,
  );
  sample();

  if (settle) await _settleFrameSchedulerIdle(tester);

  return _ScenarioEvidence(
    finalStateReached: modulesReady.evaluate().isNotEmpty,
    intermediateFramesRendered: sawSessionOverlap || sawModuleOverlap,
    finalStateDescription:
        'Dualis modules are visible; restoring=$sawRestoring, '
        'sessionOverlap=$sawSessionOverlap, moduleOverlap=$sawModuleOverlap',
    animationChecks: <String, bool>{
      if (sawRestoring) 'dualis_session_restore': sawSessionOverlap,
      if (modulesLoading.evaluate().isNotEmpty || sawModuleOverlap)
        'dualis_modules_loading_to_ready': sawModuleOverlap,
    },
  );
}

/// Returns true if the list of samples shows more than one distinct value
/// (i.e., the visual property changed progressively).
bool _verifyProgressiveChange(List<double> samples) {
  if (samples.length < 2) return false;
  return samples.toSet().length > 1;
}

_ScenarioEvidence _combineEvidence(
  _ScenarioEvidence first,
  _ScenarioEvidence second, {
  required String description,
}) {
  return _ScenarioEvidence(
    finalStateReached: first.finalStateReached && second.finalStateReached,
    intermediateFramesRendered:
        first.intermediateFramesRendered || second.intermediateFramesRendered,
    finalStateDescription:
        '$description. ${first.finalStateDescription}; '
        '${second.finalStateDescription}',
    animationChecks: <String, bool>{
      ...first.animationChecks,
      ...second.animationChecks,
    },
  );
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

  final drawerLeftSamples = <double>[];
  _sampleDrawerLeft(tester, drawerLeftSamples);
  await tester.tap(item, warnIfMissed: false);
  await tester.pump(_pollStep);
  await _pumpUntilWithCallback(
    tester,
    condition: () =>
        find.byType(Drawer).evaluate().isEmpty &&
        destination.evaluate().isNotEmpty,
    description: 'drawer close and $destinationDescription construction',
    onPump: () => _sampleDrawerLeft(tester, drawerLeftSamples),
  );

  final progressed = _verifyProgressiveChange(drawerLeftSamples);
  return _ScenarioEvidence(
    finalStateReached:
        find.byType(Drawer).evaluate().isEmpty &&
        destination.evaluate().isNotEmpty,
    intermediateFramesRendered: progressed,
    finalStateDescription: progressed
        ? 'drawer translated closed while $destinationDescription appeared'
        : 'drawer position samples while opening $destinationDescription: '
              '$drawerLeftSamples',
    animationChecks: <String, bool>{'drawer_translation': progressed},
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

double _visibleMealCardArea(WidgetTester tester, Finder pageView) {
  if (pageView.evaluate().isEmpty) return 0;
  final viewport = tester.getRect(pageView.first);
  var visibleArea = 0.0;
  final cards = find.descendant(of: pageView, matching: find.byType(MealCard));
  for (final element in cards.evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox || !renderObject.hasSize) continue;
    final cardRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final visible = cardRect.intersect(viewport);
    if (!visible.isEmpty) {
      visibleArea += visible.width * visible.height;
    }
  }
  return visibleArea.roundToDouble();
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

double? _currentPagePosition(WidgetTester tester, Finder pageView) {
  if (pageView.evaluate().isEmpty) return null;
  final controller = tester.widget<PageView>(pageView.first).controller;
  if (controller == null || controller.positions.length != 1) return null;
  return controller.page ?? controller.initialPage.toDouble();
}

int? _currentPageIndex(WidgetTester tester, Finder pageView) {
  return _currentPagePosition(tester, pageView)?.round();
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
  static const Duration _initialTimingFlush = Duration(seconds: 2);
  static const Duration _timingPollInterval = Duration(milliseconds: 100);
  static const Duration _timingQuietPeriod = Duration(milliseconds: 1100);
  static const Duration _timingDeliveryTimeout = Duration(seconds: 5);

  final IntegrationTestWidgetsFlutterBinding binding;
  final WidgetTester tester;
  final String profileMode;
  final bool collectTimeline;
  final Map<String, Map<String, dynamic>> _scenarios =
      <String, Map<String, dynamic>>{};
  bool _timingsPrimed = false;

  _ScenarioRecorder({
    required this.binding,
    required this.tester,
    required this.profileMode,
    required this.collectTimeline,
  });

  Future<void> measure(
    String scenarioId, {
    required Future<_ScenarioEvidence> Function() action,
    bool animated = true,
  }) async {
    // The engine may deliver old FrameTiming batches up to roughly one second
    // late. Flush them before the first scenario, then fully drain every
    // scenario before registering the next callback.
    if (!_timingsPrimed) {
      await Future<void>.delayed(_initialTimingFlush);
      _timingsPrimed = true;
    }

    final frameTimings = <FrameTiming>[];
    final timingCallback = frameTimings.addAll;
    binding.addTimingsCallback(timingCallback);

    late _ScenarioEvidence evidence;
    final timelineKey = 'cold_navigation_timeline_$scenarioId';
    final stopwatch = Stopwatch()..start();
    try {
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
    } finally {
      stopwatch.stop();
      await _waitForTimingDelivery(frameTimings);
      binding.removeTimingsCallback(timingCallback);
    }

    final recorded = recordFrameTimings(frameTimings);
    final summary = summarizeFrameDurations(
      buildDurationsUs: recorded.map((timing) => timing.buildDurationUs),
      rasterDurationsUs: recorded.map((timing) => timing.rasterDurationUs),
      interactionDurationUs: stopwatch.elapsedMicroseconds,
      finalStateReached: evidence.finalStateReached,
      intermediateFramesRendered: evidence.intermediateFramesRendered,
      isAnimated: animated,
    );

    if (recorded.isEmpty && evidence.finalStateReached) {
      summary['frame_attribution_warning'] =
          'No frame timings were delivered for this visible scenario.';
      summary['expected_final_state_reached'] = false;
    }
    if (collectTimeline) {
      summary['timeline_key'] = timelineKey;
    }
    summary['final_state_description'] = evidence.finalStateDescription;
    summary['animation_checks'] = evidence.animationChecks;
    summary['frame_numbers'] = recorded
        .map((timing) => timing.frameNumber)
        .toList(growable: false);
    _scenarios[scenarioId] = summary;
  }

  Future<void> _waitForTimingDelivery(List<FrameTiming> timings) async {
    final deadline = DateTime.now().add(_timingDeliveryTimeout);
    var previousCount = timings.length;
    var lastChange = DateTime.now();

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_timingPollInterval);
      final now = DateTime.now();
      if (timings.length != previousCount) {
        previousCount = timings.length;
        lastChange = now;
      }
      if (timings.isNotEmpty &&
          now.difference(lastChange) >= _timingQuietPeriod) {
        return;
      }
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schema_version': 3,
      'profile_mode': profileMode,
      'perf_target': _perfTarget,
      'frame_budget_us': <String, int>{
        '120hz': frameBudget120HzUs,
        '60hz': frameBudget60HzUs,
        '30hz': frameBudget30HzUs,
        '20hz': frameBudget20HzUs,
      },
      'frame_attribution':
          'per-scenario timings callbacks with delayed-batch draining',
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

class _ScenarioEvidence {
  final bool finalStateReached;
  final bool intermediateFramesRendered;
  final String finalStateDescription;
  final Map<String, bool> animationChecks;

  const _ScenarioEvidence({
    required this.finalStateReached,
    required this.intermediateFramesRendered,
    required this.finalStateDescription,
    this.animationChecks = const <String, bool>{},
  });
}
