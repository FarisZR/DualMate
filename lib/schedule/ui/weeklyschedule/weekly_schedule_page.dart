import 'dart:async';

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
import 'package:intl/intl.dart';

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
                _buildNavigationHeader(context),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: PropertyChangeConsumer<WeeklyScheduleViewModel,
                            String>(
                          properties: const ["weekSchedule", "now"],
                          builder: (BuildContext context,
                              WeeklyScheduleViewModel? model,
                              Set<String>? properties) {
                            if (model == null) return Container();
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 120),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeOut,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.01, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                );
                              },
                              child: RepaintBoundary(
                                key: ValueKey(
                                  model.currentDateStart.toIso8601String(),
                                ),
                                child: ScheduleWidget(
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

  Widget _buildNavigationHeader(BuildContext context) {
    final locale = L.of(context).locale.toString();
    final monthFormatter = DateFormat.yMMMM(locale);
    final dayFormatter = DateFormat('d MMM', locale);
    final weekStart = viewModel.currentDateStart;
    final weekEnd = viewModel.currentDateEnd.subtract(const Duration(days: 1));
    final weekRange = '${dayFormatter.format(weekStart)} - '
        '${dayFormatter.format(weekEnd)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthFormatter.format(weekStart),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    weekRange,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.75),
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              visualDensity: VisualDensity.compact,
              onPressed: _previousWeek,
            ),
            IconButton(
              icon: const Icon(Icons.today_outlined),
              visualDensity: VisualDensity.compact,
              onPressed: _goToToday,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
              onPressed: _nextWeek,
            ),
          ],
        ),
      ),
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
