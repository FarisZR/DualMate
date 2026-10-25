import 'dart:async';

import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_view_model.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:dualmate/schedule/ui/widgets/class_reminder_paused_notice.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_empty_state.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_empty_state_placeholder.dart';
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

  static Future<void> prepareForActivation() {
    SchedulePage._sharedWeeklyScheduleViewModel ??= WeeklyScheduleViewModel(
      KiwiContainer().resolve(),
      KiwiContainer().resolve(),
    );
    return SchedulePage._sharedWeeklyScheduleViewModel!.prepareCachedSchedule();
  }

  @override
  _SchedulePageState createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  static const int _scheduleNavigationIndex = 0;
  static const Duration _weeklyInitDelay = Duration(milliseconds: 520);

  WeeklyScheduleViewModel get weeklyScheduleViewModel {
    SchedulePage._sharedWeeklyScheduleViewModel ??= WeeklyScheduleViewModel(
      KiwiContainer().resolve(),
      KiwiContainer().resolve(),
    );
    return SchedulePage._sharedWeeklyScheduleViewModel!;
  }

  Timer? _weeklyInitTimer;
  ValueNotifier<int>? _currentEntryIndex;
  bool _scheduleSourceInitialized = false;
  bool _weeklyInitializationStarted = false;
  bool _deferredWorkSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PerformanceTelemetry.instance.markNavEvent(name: "schedule.entry");
    });
    _scheduleDeferredWorkSync();
  }

  @override
  void dispose() {
    _currentEntryIndex?.removeListener(_handleNavigationIndexChanged);
    _weeklyInitTimer?.cancel();
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

          if (!viewModel.didSetupProperly) {
            final setupPending =
                viewModel.isInitializingScheduleSource ||
                !viewModel.didAttemptSetup;
            if (!setupPending) return ScheduleEmptyState();
            if (!hasCachedSchedule) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: ScheduleEmptyStatePlaceholder(),
              );
            }
          }

          if (!hasCachedSchedule && !hasScheduleLoadFailure) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: ScheduleEmptyStatePlaceholder(),
            );
          }

          const weeklyPage = WeeklySchedulePage();

          return _withReminderState(weeklyPage);
        },
      ),
    );
  }

  Widget _withReminderState(Widget child) {
    final container = KiwiContainer();
    if (!container.isRegistered<ClassReminderController>()) return child;
    final controller = container.resolve<ClassReminderController>();
    return ClassReminderPauseAwareContent(controller: controller, child: child);
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
    _scheduleDeferredWorkSync();
  }

  void _handleNavigationIndexChanged() {
    _scheduleDeferredWorkSync();
  }

  void _scheduleDeferredWorkSync() {
    if (_deferredWorkSyncScheduled) return;
    _deferredWorkSyncScheduled = true;
    // Fixture setup can notify provider listeners synchronously. Dependency
    // changes also run during construction, so start only after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deferredWorkSyncScheduled = false;
      if (mounted) _syncDeferredWorkWithVisibility();
    });
  }

  void _syncDeferredWorkWithVisibility() {
    if (!mounted) return;
    if (!_isScheduleSectionVisible) {
      _weeklyInitTimer?.cancel();
      _weeklyInitTimer = null;
      return;
    }

    _initializeScheduleSourceIfNeeded();
    _scheduleDeferredWeeklyInitialization();
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
      _weeklyInitTimer = null;
      SchedulerBinding.instance.scheduleTask<void>(
        () async {
          if (!mounted || !_isScheduleSectionVisible) return;
          _weeklyInitializationStarted = true;
          await weeklyScheduleViewModel.initialize();
        },
        Priority.idle,
        debugLabel: 'schedule.weeklyInit',
      );
    });
  }
}

class ClassReminderPauseAwareContent extends StatelessWidget {
  final ClassReminderController controller;
  final Widget child;

  const ClassReminderPauseAwareContent({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, schedule) {
        final remindersPaused = controller.remindersPaused;
        final showMissedReminder =
            !remindersPaused && controller.hasLikelyMissedReminder;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: remindersPaused ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !remindersPaused,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: remindersPaused ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ClassReminderPausedNotice(
                        onFixPermissions:
                            controller.openReliablePermissionSettings,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: showMissedReminder ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !showMissedReminder,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: showMissedReminder ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ClassReminderLikelyMissedNotice(
                        onOpenBatterySettings:
                            controller.openBatterySettingsForMissedReminder,
                        onDismiss: controller.dismissLikelyMissedReminder,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: schedule!),
          ],
        );
      },
    );
  }
}
