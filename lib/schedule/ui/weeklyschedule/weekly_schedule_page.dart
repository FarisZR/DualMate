import 'dart:async';

import 'package:animations/animations.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/widgets/error_display.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/schedule_entry_detail_bottom_sheet.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_widget.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:flutter/material.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class WeeklySchedulePage extends StatefulWidget {
  @override
  _WeeklySchedulePageState createState() => _WeeklySchedulePageState();
}

class _WeeklySchedulePageState extends State<WeeklySchedulePage>
    with WidgetsBindingObserver {
  late WeeklyScheduleViewModel viewModel;
  double _dragDelta = 0;
  bool _isApplyingWidgetPayload = false;

  _WeeklySchedulePageState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetNavigationPayloadStore.instance.addListener(_handleWidgetPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleWidgetPayload();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetNavigationPayloadStore.instance.removeListener(_handleWidgetPayload);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final model = Provider.of<WeeklyScheduleViewModel>(context, listen: false);
    unawaited(model.refreshWidgetRangeInBackground());
  }

  void _showQueryFailedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(L.of(context).scheduleQueryFailedMessage),
            TextButton(
              child: Text(
                  L.of(context).scheduleQueryFailedOpenInBrowser.toUpperCase()),
              onPressed: () {
                var url = viewModel.scheduleUrl;
                if (url != null && url.isNotEmpty) {
                  launchUrl(Uri.parse(url));
                }
              },
            )
          ],
        ),
        duration: Duration(seconds: 15),
      ),
    );
  }

  void _previousWeek() async {
    await viewModel.previousWeek();
  }

  void _nextWeek() async {
    await viewModel.nextWeek();
  }

  void _goToToday() async {
    await viewModel.goToToday();
  }

  void _onScheduleEntryTap(BuildContext context, ScheduleEntry entry) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      builder: (context) => ScheduleEntryDetailBottomSheet(
        scheduleEntry: entry,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    viewModel = Provider.of<WeeklyScheduleViewModel>(context);
    viewModel.ensureUpdateNowTimerRunning();

    viewModel.setQueryFailedCallback(_showQueryFailedSnackBar);

    return PropertyChangeProvider<WeeklyScheduleViewModel, String>(
      value: viewModel,
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          _dragDelta = 0;
        },
        onHorizontalDragUpdate: (details) {
          _dragDelta += details.delta.dx;
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.velocity.pixelsPerSecond.dx;
          const velocityThreshold = 180;
          const distanceThreshold = 12;

          if (velocity.abs() > velocityThreshold ||
              _dragDelta.abs() > distanceThreshold) {
            if (velocity > 0 || _dragDelta > 0) {
              _previousWeek();
            } else {
              _nextWeek();
            }
          }
          _dragDelta = 0;
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildNavigationButtonBar(),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: PropertyChangeConsumer<WeeklyScheduleViewModel,
                            String>(
                          properties: const ["weekSchedule", "now"],
                          builder: (BuildContext context,
                              WeeklyScheduleViewModel? model,
                              Set<String>? properties) {
                            if (model == null) return Container();
                            return PageTransitionSwitcher(
                              reverse: !model.didUpdateScheduleIntoFuture,
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (Widget child,
                                      Animation<double> animation,
                                      Animation<double> secondaryAnimation) =>
                                  SharedAxisTransition(
                                child: child,
                                animation: animation,
                                secondaryAnimation: secondaryAnimation,
                                transitionType:
                                    SharedAxisTransitionType.horizontal,
                              ),
                              child: ScheduleWidget(
                                key: ValueKey(
                                  model.currentDateStart.toIso8601String(),
                                ),
                                schedule: model.weekSchedule ?? Schedule(),
                                displayStart: model.clippedDateStart ??
                                    model.currentDateStart,
                                displayEnd: model.clippedDateEnd ??
                                    model.currentDateEnd,
                                onScheduleEntryTap: (entry) {
                                  _onScheduleEntryTap(context, entry);
                                },
                                now: model.now,
                                displayEndHour: model.displayEndHour,
                                displayStartHour: model.displayStartHour,
                              ),
                            );
                          },
                        ),
                      ),
                      PropertyChangeConsumer<WeeklyScheduleViewModel, String>(
                        properties: const ["isUpdating"],
                        builder: (BuildContext context,
                            WeeklyScheduleViewModel? model,
                            Set<String>? properties) {
                          if (model == null) return Container();
                          return model.isUpdating
                              ? const LinearProgressIndicator()
                              : Container();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            buildErrorDisplay(context)
          ],
        ),
      ),
    );
  }

  void _handleWidgetPayload() {
    if (WidgetNavigationPayloadStore.instance.peekSchedulePayload() == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyWidgetPayload();
    });
  }

  Future<void> _applyWidgetPayload() async {
    if (_isApplyingWidgetPayload) return;
    final payload = WidgetNavigationPayloadStore.instance.takeSchedulePayload();
    if (payload == null) return;
    _isApplyingWidgetPayload = true;

    try {
      final targetDate = payload.start ?? payload.dayStart ?? DateTime.now();
      print("Widget schedule target date: $targetDate");
      await viewModel.openWeekContainingFromWidget(targetDate);
      if (!mounted) return;

      if (payload.hasEntry) {
        final entry = viewModel.resolveEntryFromPayload(payload);
        if (entry != null) {
          print("Widget schedule entry resolved: ${entry.title}");
          _onScheduleEntryTap(context, entry);
        } else {
          print("Widget schedule entry not resolved");
        }
      }
    } finally {
      _isApplyingWidgetPayload = false;
    }
  }

  Row _buildNavigationButtonBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        IconButton(
          icon: Icon(Icons.chevron_left),
          onPressed: _previousWeek,
        ),
        IconButton(
          icon: Icon(Icons.today),
          onPressed: _goToToday,
        ),
        IconButton(
          icon: Icon(Icons.chevron_right),
          onPressed: _nextWeek,
        ),
      ],
    );
  }

  Widget buildErrorDisplay(BuildContext context) {
    return PropertyChangeConsumer<WeeklyScheduleViewModel, String>(
      properties: const [
        "updateFailed",
      ],
      builder: (BuildContext context, WeeklyScheduleViewModel? model,
              Set<String>? properties) =>
          ErrorDisplay(
        show: model?.updateFailed ?? false,
      ),
    );
  }
}
