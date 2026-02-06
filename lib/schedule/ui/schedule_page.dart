import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/ui/dailyschedule/daily_schedule_page.dart';
import 'package:dualmate/schedule/ui/viewmodels/daily_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_view_model.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_empty_state.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_empty_state_placeholder.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:dualmate/ui/pager_widget.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';
import 'package:provider/provider.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';

class SchedulePage extends StatefulWidget {
  @override
  _SchedulePageState createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final WeeklyScheduleViewModel weeklyScheduleViewModel =
      WeeklyScheduleViewModel(
    KiwiContainer().resolve(),
    KiwiContainer().resolve(),
  );

  final DailyScheduleViewModel dailyScheduleViewModel = DailyScheduleViewModel(
    KiwiContainer().resolve(),
  );

  final ValueNotifier<int?> _forcedPage = ValueNotifier<int?>(null);
  bool _didWarmUp = false;

  @override
  void initState() {
    super.initState();
    WidgetNavigationPayloadStore.instance.addListener(_handleWidgetPayload);
    _handleWidgetPayload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _didWarmUp = true;
      });
    });
  }

  @override
  void dispose() {
    WidgetNavigationPayloadStore.instance.removeListener(_handleWidgetPayload);
    _forcedPage.dispose();
    weeklyScheduleViewModel.dispose();
    dailyScheduleViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_didWarmUp) {
      weeklyScheduleViewModel.initialize();
    }
    ScheduleViewModel viewModel = Provider.of<ScheduleViewModel>(context);

    if (viewModel.isInitializingScheduleSource) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: ScheduleEmptyStatePlaceholder(),
      );
    }
    if (!viewModel.didSetupProperly) {
      return ScheduleEmptyState();
    } else {
      if (!_didWarmUp) {
        return ScheduleEmptyStatePlaceholder();
      }
      return PagerWidget(
        forcedPage: _forcedPage,
        pages: <PageDefinition>[
          PageDefinition(
            icon: Icon(Icons.view_week),
            text: L.of(context).pageWeekOverviewTitle,
            builder: (_) =>
                ChangeNotifierProvider<WeeklyScheduleViewModel>.value(
              value: weeklyScheduleViewModel,
              child: WeeklySchedulePage(),
            ),
          ),
          PageDefinition(
            icon: Icon(Icons.view_day),
            text: L.of(context).pageDayOverviewTitle,
            builder: (_) =>
                ChangeNotifierProvider<DailyScheduleViewModel>.value(
              value: dailyScheduleViewModel,
              child: DailySchedulePage(),
            ),
          ),
        ],
      );
    }
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
    PerformanceTelemetry.instance.markNavEvent(name: "schedule.entry");
  }
}
