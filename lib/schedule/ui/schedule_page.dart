import 'dart:async';

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_view_model.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_empty_state.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_empty_state_placeholder.dart';
import 'package:dualmate/schedule/ui/widgets/select_source_dialog.dart';
import 'package:dualmate/ui/banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:kiwi/kiwi.dart';
import 'package:provider/provider.dart';

class SchedulePage extends StatefulWidget {
  static WeeklyScheduleViewModel? _sharedWeeklyScheduleViewModel;

  static void resetSharedState() {
    _sharedWeeklyScheduleViewModel?.dispose();
    _sharedWeeklyScheduleViewModel = null;
  }

  @override
  _SchedulePageState createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  static const int _scheduleNavigationIndex = 0;
  static const Duration _weeklyInitDelay = Duration(milliseconds: 520);
  static const Duration _filterWarmDelay = Duration(milliseconds: 1200);

  WeeklyScheduleViewModel get weeklyScheduleViewModel {
    SchedulePage._sharedWeeklyScheduleViewModel ??= WeeklyScheduleViewModel(
      KiwiContainer().resolve(),
      KiwiContainer().resolve(),
    );
    return SchedulePage._sharedWeeklyScheduleViewModel!;
  }

  Timer? _weeklyInitTimer;
  Timer? _filterWarmTimer;
  ValueNotifier<int>? _currentEntryIndex;
  bool _scheduleSourceInitialized = false;
  bool _weeklyInitializationStarted = false;
  bool _filterWarmupStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PerformanceTelemetry.instance.markNavEvent(name: "schedule.entry");
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncDeferredWorkWithVisibility();
    });
  }

  @override
  void dispose() {
    _currentEntryIndex?.removeListener(_handleNavigationIndexChanged);
    _weeklyInitTimer?.cancel();
    _filterWarmTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WeeklyScheduleViewModel>.value(
      value: weeklyScheduleViewModel,
      child: Builder(
        builder: (context) {
          final viewModel = Provider.of<ScheduleViewModel>(context);
          final weeklyViewModel = Provider.of<WeeklyScheduleViewModel>(context);
          final hasCachedSchedule = weeklyViewModel.weekSchedule != null;
          final hasScheduleLoadFailure =
              weeklyViewModel.updateFailed || weeklyViewModel.initializeFailed;

          if (!viewModel.didSetupProperly && !hasCachedSchedule) {
            if (viewModel.isInitializingScheduleSource ||
                !viewModel.didAttemptSetup) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: ScheduleEmptyStatePlaceholder(),
              );
            }
            return ScheduleEmptyState();
          }

          if (!hasCachedSchedule && !hasScheduleLoadFailure) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: ScheduleEmptyStatePlaceholder(),
            );
          }

          const weeklyPage = WeeklySchedulePage();

          if (!viewModel.didSetupProperly &&
              viewModel.didAttemptSetup &&
              !viewModel.isInitializingScheduleSource) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                  child: BannerWidget(
                    message: L.of(context).scheduleEmptyStateBannerMessage,
                    onButtonTap: () async {
                      await SelectSourceDialog(
                        KiwiContainer().resolve(),
                        KiwiContainer().resolve(),
                      ).show(context);
                    },
                    buttonText: L
                        .of(context)
                        .scheduleEmptyStateSetUrl
                        .toUpperCase(),
                  ),
                ),
                Expanded(child: weeklyPage),
              ],
            );
          }

          return weeklyPage;
        },
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ValueNotifier<int>? nextEntryIndex;
    try {
      nextEntryIndex = Provider.of<ValueNotifier<int>>(context, listen: false);
    } on ProviderNotFoundException {
      nextEntryIndex = null;
    }

    if (_currentEntryIndex == nextEntryIndex) {
      return;
    }

    _currentEntryIndex?.removeListener(_handleNavigationIndexChanged);
    _currentEntryIndex = nextEntryIndex;
    _currentEntryIndex?.addListener(_handleNavigationIndexChanged);
    _syncDeferredWorkWithVisibility();
  }

  Future<void> _warmFilterPageState() async {
    try {
      final scheduleViewModel = Provider.of<ScheduleViewModel>(
        context,
        listen: false,
      );
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (mounted &&
          scheduleViewModel.isInitializingScheduleSource &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
      if (!mounted) return;
      await FilterViewModel.preloadStates(
        KiwiContainer().resolve<ScheduleEntryRepository>(),
        KiwiContainer().resolve<ScheduleFilterRepository>(),
      );
    } on ProviderNotFoundException {
      rethrow;
    } on FlutterError catch (error, trace) {
      debugPrint('Failed to warm filter state: $error');
      debugPrint('$trace');
    } catch (error, trace) {
      debugPrint('Unexpected error while warming filter state: $error');
      debugPrint('$trace');
      rethrow;
    }
  }

  void _handleNavigationIndexChanged() {
    _syncDeferredWorkWithVisibility();
  }

  void _syncDeferredWorkWithVisibility() {
    if (!mounted) return;
    if (!_isScheduleSectionVisible) {
      _weeklyInitTimer?.cancel();
      _weeklyInitTimer = null;
      _filterWarmTimer?.cancel();
      _filterWarmTimer = null;
      return;
    }

    _initializeScheduleSourceIfNeeded();
    _scheduleDeferredWeeklyInitialization();
    _scheduleDeferredFilterWarmup();
  }

  bool get _isScheduleSectionVisible {
    final currentEntryIndex = _currentEntryIndex;
    if (currentEntryIndex == null) {
      return true;
    }
    return currentEntryIndex.value == _scheduleNavigationIndex;
  }

  void _initializeScheduleSourceIfNeeded() {
    if (_scheduleSourceInitialized) return;
    _scheduleSourceInitialized = true;
    final scheduleViewModel = Provider.of<ScheduleViewModel>(
      context,
      listen: false,
    );
    scheduleViewModel.initialize();
  }

  void _scheduleDeferredWeeklyInitialization() {
    if (_weeklyInitializationStarted || _weeklyInitTimer != null) {
      return;
    }
    _weeklyInitTimer = Timer(_weeklyInitDelay, () {
      if (!mounted) return;
      if (!_isScheduleSectionVisible) {
        _weeklyInitTimer = null;
        return;
      }
      _weeklyInitializationStarted = true;
      _weeklyInitTimer = null;
      SchedulerBinding.instance.scheduleTask<void>(
        () async {
          if (!mounted || !_isScheduleSectionVisible) return;
          await weeklyScheduleViewModel.initialize();
        },
        Priority.idle,
        debugLabel: 'schedule.weeklyInit',
      );
    });
  }

  void _scheduleDeferredFilterWarmup() {
    if (_filterWarmupStarted || _filterWarmTimer != null) {
      return;
    }
    _filterWarmTimer = Timer(_filterWarmDelay, () {
      if (!mounted) return;
      if (!_isScheduleSectionVisible) {
        _filterWarmTimer = null;
        return;
      }
      _filterWarmupStarted = true;
      _filterWarmTimer = null;
      SchedulerBinding.instance.scheduleTask<void>(
        () {
          if (!mounted || !_isScheduleSectionVisible) return;
          unawaited(_warmFilterPageState());
        },
        Priority.idle,
        debugLabel: 'schedule.filterWarmup',
      );
    });
  }
}
