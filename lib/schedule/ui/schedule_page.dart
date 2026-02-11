import 'dart:async';

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:dualmate/schedule/ui/dailyschedule/daily_schedule_page.dart';
import 'package:dualmate/schedule/ui/viewmodels/daily_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_view_model.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_empty_state.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_empty_state_placeholder.dart';
import 'package:dualmate/schedule/ui/widgets/select_source_dialog.dart';
import 'package:dualmate/ui/banner_widget.dart';
import 'package:dualmate/ui/pager_widget.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';
import 'package:provider/provider.dart';

class SchedulePage extends StatefulWidget {
  static WeeklyScheduleViewModel? _sharedWeeklyScheduleViewModel;
  static DailyScheduleViewModel? _sharedDailyScheduleViewModel;

  static void resetSharedState() {
    _sharedWeeklyScheduleViewModel?.dispose();
    _sharedWeeklyScheduleViewModel = null;
    _sharedDailyScheduleViewModel?.dispose();
    _sharedDailyScheduleViewModel = null;
  }

  @override
  _SchedulePageState createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  WeeklyScheduleViewModel get weeklyScheduleViewModel {
    SchedulePage._sharedWeeklyScheduleViewModel ??= WeeklyScheduleViewModel(
      KiwiContainer().resolve(),
      KiwiContainer().resolve(),
    );
    return SchedulePage._sharedWeeklyScheduleViewModel!;
  }

  DailyScheduleViewModel get dailyScheduleViewModel {
    SchedulePage._sharedDailyScheduleViewModel ??= DailyScheduleViewModel(
      KiwiContainer().resolve(),
    );
    return SchedulePage._sharedDailyScheduleViewModel!;
  }

  final ValueNotifier<int?> _forcedPage = ValueNotifier<int?>(null);
  bool _didWarmUp = false;

  @override
  void initState() {
    super.initState();
    WidgetNavigationPayloadStore.instance.addListener(_handleWidgetPayload);
    _handleWidgetPayload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PerformanceTelemetry.instance.markNavEvent(name: "schedule.entry");
    });
    _didWarmUp = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scheduleViewModel =
          Provider.of<ScheduleViewModel>(context, listen: false);
      scheduleViewModel.initialize();
      unawaited(weeklyScheduleViewModel.initialize());
    });
  }

  @override
  void dispose() {
    WidgetNavigationPayloadStore.instance.removeListener(_handleWidgetPayload);
    _forcedPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WeeklyScheduleViewModel>.value(
          value: weeklyScheduleViewModel,
        ),
        ChangeNotifierProvider<DailyScheduleViewModel>.value(
          value: dailyScheduleViewModel,
        ),
      ],
      child: Builder(
        builder: (context) {
          final viewModel = Provider.of<ScheduleViewModel>(context);
          final weeklyViewModel = Provider.of<WeeklyScheduleViewModel>(context);
          final hasCachedSchedule = weeklyViewModel.weekSchedule != null;

          if (!viewModel.didSetupProperly && !hasCachedSchedule) {
            if (viewModel.isInitializingScheduleSource ||
                !viewModel.didAttemptSetup) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: ScheduleEmptyStatePlaceholder(),
              );
            }
            return ScheduleEmptyState();
          } else {
            if (!_didWarmUp) {
              return ScheduleEmptyStatePlaceholder();
            }
            final pager = PagerWidget(
              forcedPage: _forcedPage,
              pages: <PageDefinition>[
                PageDefinition(
                  icon: Icon(Icons.view_week),
                  text: L.of(context).pageWeekOverviewTitle,
                  builder: (_) => WeeklySchedulePage(),
                ),
                PageDefinition(
                  icon: Icon(Icons.view_day),
                  text: L.of(context).pageDayOverviewTitle,
                  builder: (_) => DailySchedulePage(),
                ),
              ],
            );

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
                      buttonText:
                          L.of(context).scheduleEmptyStateSetUrl.toUpperCase(),
                    ),
                  ),
                  Expanded(child: pager),
                ],
              );
            }

            return pager;
          }
        },
      ),
    );
  }

  void _handleWidgetPayload() {
    if (WidgetNavigationPayloadStore.instance.peekSchedulePayload() == null) {
      return;
    }
    _forcedPage.value = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }
}
