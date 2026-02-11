import 'dart:async';
import 'dart:math' as math;

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/widgets/error_display.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/schedule_entry_detail_bottom_sheet.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class WeeklySchedulePage extends StatefulWidget {
  const WeeklySchedulePage({super.key});

  @override
  State<WeeklySchedulePage> createState() => _WeeklySchedulePageState();
}

class _WeeklySchedulePageState extends State<WeeklySchedulePage>
    with WidgetsBindingObserver {
  static const int _centerPageIndex = 1;
  static const int _ringPageCount = 3;

  final Set<String> _prefetchRequestedKeys = <String>{};
  late final PageController _weekPageController;
  late WeeklyScheduleViewModel viewModel;

  bool _isApplyingWidgetPayload = false;
  bool _isRebalancingPage = false;
  bool _pagerInitialized = false;
  DateTime? _centerWeekStart;
  int _weekOpenRequestId = 0;

  @override
  void initState() {
    super.initState();
    _weekPageController = PageController(initialPage: _centerPageIndex);
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
    _weekPageController.dispose();
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
                L.of(context).scheduleQueryFailedOpenInBrowser.toUpperCase(),
              ),
              onPressed: () {
                final url = viewModel.scheduleUrl;
                if (url != null && url.isNotEmpty) {
                  launchUrl(Uri.parse(url));
                }
              },
            )
          ],
        ),
        duration: const Duration(seconds: 15),
      ),
    );
  }

  void _previousWeek() {
    unawaited(_animateToRingPage(_centerPageIndex - 1));
  }

  void _nextWeek() {
    unawaited(_animateToRingPage(_centerPageIndex + 1));
  }

  void _goToToday() {
    final todayWeekStart = _normalizeWeekStart(viewModel.now);
    final currentWeekStart = _resolveCurrentWeekStart();

    if (isAtSameDay(todayWeekStart, currentWeekStart)) {
      return;
    }

    final previousWeekStart = toPreviousWeek(currentWeekStart);
    final nextWeekStart = toNextWeek(currentWeekStart);

    if (isAtSameDay(todayWeekStart, previousWeekStart)) {
      _previousWeek();
      return;
    }

    if (isAtSameDay(todayWeekStart, nextWeekStart)) {
      _nextWeek();
      return;
    }

    setState(() {
      _centerWeekStart = todayWeekStart;
    });
    _recenterPager();
    unawaited(_openVisibleWeek(todayWeekStart));
  }

  Future<void> _animateToRingPage(int pageIndex) async {
    if (!_weekPageController.hasClients) return;
    await _weekPageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
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
    _ensurePagerInitialized();

    viewModel.ensureUpdateNowTimerRunning();
    viewModel.setQueryFailedCallback(_showQueryFailedSnackBar);

    return PropertyChangeProvider<WeeklyScheduleViewModel, String>(
      value: viewModel,
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
                        properties: const ['weekSchedule', 'now'],
                        builder: (
                          BuildContext context,
                          WeeklyScheduleViewModel? model,
                          Set<String>? properties,
                        ) {
                          if (model == null) return const SizedBox.shrink();
                          if (!_isApplyingWidgetPayload &&
                              !_isRebalancingPage) {
                            _centerWeekStart =
                                _normalizeWeekStart(model.currentDateStart);
                          }
                          return _buildWeeklyPager(context, model);
                        },
                      ),
                    ),
                    PropertyChangeConsumer<WeeklyScheduleViewModel, String>(
                      properties: const ['isUpdating'],
                      builder: (
                        BuildContext context,
                        WeeklyScheduleViewModel? model,
                        Set<String>? properties,
                      ) {
                        if (model == null) return const SizedBox.shrink();
                        return model.isUpdating
                            ? const LinearProgressIndicator()
                            : const SizedBox.shrink();
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
    );
  }

  Widget _buildWeeklyPager(
    BuildContext context,
    WeeklyScheduleViewModel model,
  ) {
    final centerWeekStart = _resolveCurrentWeekStart();

    return PageView.builder(
      key: const ValueKey<String>('weekly_schedule_page_view'),
      controller: _weekPageController,
      itemCount: _ringPageCount,
      physics: const PageScrollPhysics(),
      allowImplicitScrolling: true,
      dragStartBehavior: DragStartBehavior.start,
      onPageChanged: (pageIndex) {
        unawaited(_onWeekPageChanged(pageIndex));
      },
      itemBuilder: (context, pageIndex) {
        final weekStart = _weekStartForPage(pageIndex, centerWeekStart);
        final pageData = _buildPageData(weekStart, model);

        return RepaintBoundary(
          key: ValueKey<String>('week_page_${weekStart.toIso8601String()}'),
          child: ScheduleWidget(
            schedule: pageData.schedule,
            displayStart: pageData.displayStart,
            displayEnd: pageData.displayEnd,
            onScheduleEntryTap: (entry) {
              _onScheduleEntryTap(context, entry);
            },
            now: model.now,
            displayEndHour: pageData.displayEndHour,
            displayStartHour: pageData.displayStartHour,
          ),
        );
      },
    );
  }

  Future<void> _onWeekPageChanged(int pageIndex) async {
    if (_isRebalancingPage || pageIndex == _centerPageIndex) {
      return;
    }

    final currentWeek = _resolveCurrentWeekStart();
    final nextCenterWeek = pageIndex < _centerPageIndex
        ? toPreviousWeek(currentWeek)
        : toNextWeek(currentWeek);

    setState(() {
      _centerWeekStart = nextCenterWeek;
    });
    _recenterPager();
    await _openVisibleWeek(nextCenterWeek);
  }

  Future<void> _openVisibleWeek(DateTime weekStart) async {
    final requestId = ++_weekOpenRequestId;
    await viewModel.openWeekContaining(weekStart);
    if (!mounted || requestId != _weekOpenRequestId) return;

    setState(() {
      _centerWeekStart = _normalizeWeekStart(viewModel.currentDateStart);
    });
    unawaited(_prefetchRingWeeks(_centerWeekStart!));
  }

  Future<void> _prefetchRingWeeks(DateTime centerWeekStart) async {
    final previousStart = toPreviousWeek(centerWeekStart);
    final nextStart = toNextWeek(centerWeekStart);

    await Future.wait([
      viewModel.prefetchWeek(previousStart, toNextWeek(previousStart)),
      viewModel.prefetchWeek(nextStart, toNextWeek(nextStart)),
    ]);

    if (!mounted) return;
    setState(() {});
  }

  _WeekPageData _buildPageData(
    DateTime weekStart,
    WeeklyScheduleViewModel model,
  ) {
    final weekEnd = toNextWeek(weekStart);
    final cachedSchedule = model.getCachedWeek(weekStart, weekEnd);
    if (cachedSchedule == null) {
      _requestPrefetchWeek(weekStart, weekEnd, model);
    }

    final displayRange = WeeklyScheduleViewModel.resolveWeeklyDisplayRange(
        weekStart, cachedSchedule);

    return _WeekPageData(
      schedule: cachedSchedule ?? Schedule(),
      displayStart: displayRange.start,
      displayEnd: displayRange.end,
      displayStartHour:
          _resolveDisplayStartHour(cachedSchedule, weekStart, weekEnd),
      displayEndHour:
          _resolveDisplayEndHour(cachedSchedule, weekStart, weekEnd),
    );
  }

  void _requestPrefetchWeek(
    DateTime start,
    DateTime end,
    WeeklyScheduleViewModel model,
  ) {
    final key = _windowKey(start, end);
    if (_prefetchRequestedKeys.contains(key)) {
      return;
    }

    _prefetchRequestedKeys.add(key);
    unawaited(
      model.prefetchWeek(start, end).then((_) {
        if (!mounted) return;
        setState(() {});
      }),
    );
  }

  int _resolveDisplayStartHour(
    Schedule? schedule,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    if (schedule == null || schedule.entries.isEmpty) {
      if (viewModel.currentDateStart == weekStart &&
          viewModel.currentDateEnd == weekEnd) {
        return viewModel.displayStartHour;
      }
      return 7;
    }

    final startHour = schedule.getStartTime()?.hour ?? 7;
    return math.min(7, startHour);
  }

  int _resolveDisplayEndHour(
    Schedule? schedule,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    if (schedule == null || schedule.entries.isEmpty) {
      if (viewModel.currentDateStart == weekStart &&
          viewModel.currentDateEnd == weekEnd) {
        return viewModel.displayEndHour;
      }
      return 17;
    }

    final endHour = schedule.getEndTime()?.hour ?? 16;
    return math.max(endHour + 1, 17);
  }

  void _ensurePagerInitialized() {
    if (_pagerInitialized) return;

    _pagerInitialized = true;
    _centerWeekStart = _resolveCurrentWeekStart();
    unawaited(_prefetchRingWeeks(_centerWeekStart!));
  }

  DateTime _resolveCurrentWeekStart() {
    if (_centerWeekStart != null) {
      return _centerWeekStart!;
    }

    try {
      return _normalizeWeekStart(viewModel.currentDateStart);
    } catch (_) {
      return _normalizeWeekStart(viewModel.now);
    }
  }

  DateTime _normalizeWeekStart(DateTime date) {
    return toStartOfDay(toDayOfWeek(date, DateTime.monday));
  }

  DateTime _weekStartForPage(int pageIndex, DateTime centerWeekStart) {
    if (pageIndex == _centerPageIndex - 1) {
      return toPreviousWeek(centerWeekStart);
    }
    if (pageIndex == _centerPageIndex + 1) {
      return toNextWeek(centerWeekStart);
    }
    return centerWeekStart;
  }

  void _recenterPager() {
    if (!_weekPageController.hasClients) return;

    _isRebalancingPage = true;
    _weekPageController.jumpToPage(_centerPageIndex);
    _isRebalancingPage = false;
  }

  String _windowKey(DateTime start, DateTime end) {
    return '${start.toIso8601String()}_${end.toIso8601String()}';
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
      final targetWeekStart = _normalizeWeekStart(targetDate);

      print('Widget schedule target date: $targetDate');
      await viewModel.openWeekContainingFromWidget(targetDate);
      if (!mounted) return;

      setState(() {
        _centerWeekStart = targetWeekStart;
      });
      _recenterPager();
      unawaited(_prefetchRingWeeks(targetWeekStart));

      if (payload.hasEntry) {
        final entry = viewModel.resolveEntryFromPayload(payload);
        if (entry != null) {
          print('Widget schedule entry resolved: ${entry.title}');
          _onScheduleEntryTap(context, entry);
        } else {
          print('Widget schedule entry not resolved');
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
    final weekRange =
        '${dayFormatter.format(weekStart)} - ${dayFormatter.format(weekEnd)}';

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
      properties: const ['updateFailed'],
      builder: (
        BuildContext context,
        WeeklyScheduleViewModel? model,
        Set<String>? properties,
      ) =>
          ErrorDisplay(
        show: model?.updateFailed ?? false,
      ),
    );
  }
}

class _WeekPageData {
  final Schedule schedule;
  final DateTime displayStart;
  final DateTime displayEnd;
  final int displayStartHour;
  final int displayEndHour;

  _WeekPageData({
    required this.schedule,
    required this.displayStart,
    required this.displayEnd,
    required this.displayStartHour,
    required this.displayEndHour,
  });
}
