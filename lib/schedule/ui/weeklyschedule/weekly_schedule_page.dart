import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show lerpDouble;

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
  static const int _initialPageIndex = 10000;
  static const int _daysPerWeek = 7;
  static const double _defaultWideAxisWidth = 54.0;
  static const Duration _currentWeekButtonFadeDuration =
      Duration(milliseconds: 180);

  late final PageController _weekPageController;
  late WeeklyScheduleViewModel viewModel;

  bool _isApplyingWidgetPayload = false;
  bool _pagerInitialized = false;
  bool _didBindViewModel = false;
  bool _isPagerScrolling = false;
  late DateTime _anchorWeekStart;
  int _currentPageIndex = _initialPageIndex;
  int _weekOpenRequestId = 0;
  _HourViewport? _lockedViewport;

  @override
  void initState() {
    super.initState();
    _weekPageController = PageController(initialPage: _initialPageIndex);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didBindViewModel) return;

    viewModel = Provider.of<WeeklyScheduleViewModel>(context, listen: false);
    viewModel.ensureUpdateNowTimerRunning();
    viewModel.setQueryFailedCallback(_showQueryFailedSnackBar);
    _ensurePagerInitialized();
    _didBindViewModel = true;
  }

  void _previousWeek() {
    unawaited(_animateToPage(_currentPageIndex - 1));
  }

  void _nextWeek() {
    unawaited(_animateToPage(_currentPageIndex + 1));
  }

  void _goToToday() {
    if (!_pagerInitialized) {
      _ensurePagerInitialized();
    }

    final todayWeekStart = _normalizeWeekStart(viewModel.now);
    final targetPage = _pageIndexForWeek(todayWeekStart);
    final pageDelta = (targetPage - _currentPageIndex).abs();

    if (targetPage == _currentPageIndex) {
      unawaited(_openVisibleWeek(todayWeekStart));
      return;
    }

    if (pageDelta <= 4) {
      unawaited(_animateToPage(targetPage));
      return;
    }

    if (_weekPageController.hasClients) {
      _weekPageController.jumpToPage(targetPage);
    }
    _currentPageIndex = targetPage;
    unawaited(_openVisibleWeek(todayWeekStart));
  }

  bool get _showCurrentWeekButton {
    if (!_pagerInitialized) {
      return false;
    }
    final currentWeekStart = _normalizeWeekStart(viewModel.currentDateStart);
    final todayWeekStart = _normalizeWeekStart(viewModel.now);
    return !isAtSameDay(currentWeekStart, todayWeekStart);
  }

  Future<void> _animateToPage(int pageIndex) async {
    if (!_weekPageController.hasClients) return;
    await _weekPageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
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
                          return _buildAnimatedScheduleViewport(context, model);
                        },
                      ),
                    ),
                    PropertyChangeConsumer<WeeklyScheduleViewModel, String>(
                      properties: const ['isUpdating', 'weekSchedule'],
                      builder: (
                        BuildContext context,
                        WeeklyScheduleViewModel? model,
                        Set<String>? properties,
                      ) {
                        if (model == null) return const SizedBox.shrink();
                        return _TopLoadingIndicator(
                          isUpdating: model.isUpdating,
                          showWithoutDelay: model.visibleWeekNeedsInitialFetch,
                        );
                      },
                    ),
                    Positioned(
                      right: 20,
                      bottom: 16,
                      child: _buildCurrentWeekButton(context),
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

  Widget _buildAnimatedScheduleViewport(
    BuildContext context,
    WeeklyScheduleViewModel model,
  ) {
    final modelViewport = _resolveTargetViewport(model);
    _lockedViewport ??= modelViewport;
    if (!_isPagerScrolling) {
      _lockedViewport = modelViewport;
    }
    final targetViewport = _isPagerScrolling ? _lockedViewport! : modelViewport;
    final displayedDays = _resolveDisplayedDays(model);

    return LayoutBuilder(
      builder: (context, constraints) {
        final axisMetrics = _resolveAxisLayoutMetrics(
          constraints.maxWidth,
          displayedDays,
        );

        return TweenAnimationBuilder<_HourViewport>(
          tween: _HourViewportTween(end: targetViewport),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, viewport, child) {
            return Row(
              children: [
                SizedBox(
                  key: const ValueKey<String>('weekly_fixed_hour_axis'),
                  width: axisMetrics.axisWidth,
                  child: _FixedHourAxis(
                    dayLabelsHeight: axisMetrics.dayLabelsHeight,
                    startHour: viewport.startHour,
                    endHour: viewport.endHour,
                    compactPhone: axisMetrics.compactPhone,
                  ),
                ),
                Expanded(
                  child: _buildWeeklyPager(
                    context,
                    model,
                    viewport,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWeeklyPager(
    BuildContext context,
    WeeklyScheduleViewModel model,
    _HourViewport viewport,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _setPagerScrolling(true);
        }
        if (notification is ScrollEndNotification) {
          _setPagerScrolling(false);
          unawaited(_commitVisibleWeekFromPager());
        }
        return false;
      },
      child: PageView.builder(
        key: const ValueKey<String>('weekly_schedule_page_view'),
        controller: _weekPageController,
        physics: const PageScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        allowImplicitScrolling: false,
        dragStartBehavior: DragStartBehavior.start,
        onPageChanged: (pageIndex) {
          _currentPageIndex = pageIndex;
        },
        itemBuilder: (context, pageIndex) {
          final weekStart = _weekStartForPage(pageIndex);
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
              displayStartHour: viewport.startHour,
              displayEndHour: viewport.endHour,
              showTimeLabels: false,
            ),
          );
        },
      ),
    );
  }

  Future<void> _commitVisibleWeekFromPager() async {
    if (_isApplyingWidgetPayload) return;
    final page = _weekPageController.hasClients
        ? (_weekPageController.page ?? _currentPageIndex.toDouble()).round()
        : _currentPageIndex;
    _currentPageIndex = page;

    final targetWeekStart = _weekStartForPage(page);
    if (isAtSameDay(
        targetWeekStart, _normalizeWeekStart(viewModel.currentDateStart))) {
      return;
    }

    await _openVisibleWeek(targetWeekStart);
  }

  void _setPagerScrolling(bool value) {
    if (_isPagerScrolling == value) {
      return;
    }
    if (!mounted) {
      _isPagerScrolling = value;
      return;
    }
    setState(() {
      _isPagerScrolling = value;
    });
  }

  Future<void> _openVisibleWeek(DateTime weekStart) async {
    final requestId = ++_weekOpenRequestId;
    await viewModel.openWeekContaining(weekStart);
    if (!mounted || requestId != _weekOpenRequestId) return;

    unawaited(_prefetchAdjacentWeeks(
        _normalizeWeekStart(viewModel.currentDateStart)));
  }

  Future<void> _prefetchAdjacentWeeks(DateTime centerWeekStart) async {
    final previousStart = toPreviousWeek(centerWeekStart);
    final nextStart = toNextWeek(centerWeekStart);

    try {
      await Future.wait([
        viewModel.prefetchWeek(previousStart, toNextWeek(previousStart)),
        viewModel.prefetchWeek(nextStart, toNextWeek(nextStart)),
      ]);
    } catch (error, trace) {
      developer.log(
        'Weekly prefetch failed',
        name: 'weekly_schedule_page',
        error: error,
        stackTrace: trace,
      );
    }
  }

  _WeekPageData _buildPageData(
    DateTime weekStart,
    WeeklyScheduleViewModel model,
  ) {
    final weekEnd = toNextWeek(weekStart);
    final cachedSchedule = model.getCachedWeek(weekStart, weekEnd);

    final displayRange = WeeklyScheduleViewModel.resolveWeeklyDisplayRange(
      weekStart,
      cachedSchedule,
    );

    return _WeekPageData(
      schedule: cachedSchedule ?? Schedule(),
      displayStart: displayRange.start,
      displayEnd: displayRange.end,
    );
  }

  void _ensurePagerInitialized() {
    if (_pagerInitialized) return;

    _pagerInitialized = true;
    try {
      _anchorWeekStart = _normalizeWeekStart(viewModel.currentDateStart);
    } catch (error, trace) {
      developer.log(
        'Weekly pager init fallback to current date',
        name: 'weekly_schedule_page',
        error: error,
        stackTrace: trace,
      );
      _anchorWeekStart = _normalizeWeekStart(viewModel.now);
    }
    _currentPageIndex = _pageIndexForWeek(_anchorWeekStart);

    if (_weekPageController.hasClients) {
      _weekPageController.jumpToPage(_currentPageIndex);
    }
  }

  DateTime _normalizeWeekStart(DateTime date) {
    return toStartOfDay(toDayOfWeek(date, DateTime.monday));
  }

  _HourViewport _resolveTargetViewport(WeeklyScheduleViewModel model) {
    final startHour =
        (model.displayStartHour > 0 ? model.displayStartHour : 7).toDouble();
    final endHourRaw =
        (model.displayEndHour > 0 ? model.displayEndHour : 17).toDouble();
    final endHour = endHourRaw <= startHour + 1 ? startHour + 1 : endHourRaw;
    return _HourViewport(
      startHour: startHour,
      endHour: endHour,
    );
  }

  int _resolveDisplayedDays(WeeklyScheduleViewModel model) {
    final displayStart =
        toStartOfDay(model.clippedDateStart ?? model.currentDateStart);
    final displayEnd =
        toStartOfDay(model.clippedDateEnd ?? model.currentDateEnd);
    var days = displayEnd.difference(displayStart).inDays + 1;
    if (days > 7) {
      days = 7;
    } else if (days < 5) {
      days = 5;
    }
    return days;
  }

  _AxisLayoutMetrics _resolveAxisLayoutMetrics(double totalWidth, int days) {
    final pagerWidth =
        (totalWidth - _defaultWideAxisWidth).clamp(0.0, double.infinity);
    final compactPhone = ScheduleWidget.isCompactLayout(
      width: pagerWidth,
      days: days,
      showTimeLabels: false,
    );

    if (compactPhone) {
      return const _AxisLayoutMetrics(
        axisWidth: 46,
        dayLabelsHeight: 52,
        compactPhone: true,
      );
    }

    return const _AxisLayoutMetrics(
      axisWidth: 54,
      dayLabelsHeight: 72,
      compactPhone: false,
    );
  }

  int _pageIndexForWeek(DateTime weekStart) {
    final normalizedWeekStartUtc = _normalizeWeekStart(weekStart).toUtc();
    final anchorWeekStartUtc = _anchorWeekStart.toUtc();
    final dayDelta =
        normalizedWeekStartUtc.difference(anchorWeekStartUtc).inDays;
    return _initialPageIndex + (dayDelta ~/ _daysPerWeek);
  }

  DateTime _weekStartForPage(int pageIndex) {
    final weekOffset = pageIndex - _initialPageIndex;
    return addDays(_anchorWeekStart, weekOffset * _daysPerWeek);
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
    _ensurePagerInitialized();
    _isApplyingWidgetPayload = true;

    try {
      final targetDate = payload.start ?? payload.dayStart ?? DateTime.now();
      final targetWeekStart = _normalizeWeekStart(targetDate);

      developer.log(
        'Widget schedule target date: $targetDate',
        name: 'weekly_schedule_page',
      );
      await viewModel.openWeekContainingFromWidget(targetDate);
      if (!mounted) return;

      final targetPage = _pageIndexForWeek(targetWeekStart);
      _currentPageIndex = targetPage;
      if (_weekPageController.hasClients) {
        _weekPageController.jumpToPage(targetPage);
      }
      await _prefetchAdjacentWeeks(targetWeekStart);

      if (payload.hasEntry) {
        final entry = viewModel.resolveEntryFromPayload(payload);
        if (entry != null) {
          developer.log(
            'Widget schedule entry resolved: ${entry.title}',
            name: 'weekly_schedule_page',
          );
          _onScheduleEntryTap(context, entry);
        } else {
          developer.log(
            'Widget schedule entry not resolved',
            name: 'weekly_schedule_page',
          );
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
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
              onPressed: _nextWeek,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentWeekButton(BuildContext context) {
    final label = L.of(context).scheduleBackToCurrentWeek;

    return AnimatedSwitcher(
      duration: _currentWeekButtonFadeDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
        );
      },
      child: !_showCurrentWeekButton
          ? const SizedBox.shrink()
          : Tooltip(
              message: label,
              child: FloatingActionButton.small(
                key: const ValueKey<String>('weekly_current_week_button'),
                heroTag: null,
                tooltip: label,
                onPressed: _goToToday,
                child: const Icon(Icons.arrow_back_rounded),
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

  _WeekPageData({
    required this.schedule,
    required this.displayStart,
    required this.displayEnd,
  });
}

class _HourViewport {
  final double startHour;
  final double endHour;

  const _HourViewport({
    required this.startHour,
    required this.endHour,
  });
}

class _TopLoadingIndicator extends StatefulWidget {
  static const Duration _showDelay = Duration(milliseconds: 220);
  static const Duration _minimumVisibleDuration = Duration(milliseconds: 180);

  final bool isUpdating;
  final bool showWithoutDelay;

  const _TopLoadingIndicator({
    required this.isUpdating,
    required this.showWithoutDelay,
  });

  @override
  State<_TopLoadingIndicator> createState() => _TopLoadingIndicatorState();
}

class _TopLoadingIndicatorState extends State<_TopLoadingIndicator> {
  Timer? _showTimer;
  bool _showIndicator = false;
  DateTime? _shownAt;

  @override
  void initState() {
    super.initState();
    _syncFromState();
  }

  @override
  void didUpdateWidget(covariant _TopLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isUpdating == widget.isUpdating &&
        oldWidget.showWithoutDelay == widget.showWithoutDelay) {
      return;
    }
    _syncFromState();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  void _syncFromState() {
    if (widget.isUpdating) {
      if (widget.showWithoutDelay) {
        _showTimer?.cancel();
        _showTimer = null;
        if (_showIndicator) {
          return;
        }
        setState(() {
          _showIndicator = true;
          _shownAt = DateTime.now();
        });
        return;
      }

      if (_showIndicator || _showTimer != null) {
        return;
      }
      _showTimer = Timer(_TopLoadingIndicator._showDelay, () {
        if (!mounted || !widget.isUpdating) {
          _showTimer = null;
          return;
        }
        setState(() {
          _showIndicator = true;
          _shownAt = DateTime.now();
          _showTimer = null;
        });
      });
      return;
    }

    _showTimer?.cancel();
    _showTimer = null;
    if (!_showIndicator) {
      return;
    }

    final shownAt = _shownAt;
    if (shownAt != null) {
      final elapsed = DateTime.now().difference(shownAt);
      final remaining = _TopLoadingIndicator._minimumVisibleDuration - elapsed;
      if (remaining > Duration.zero) {
        _showTimer = Timer(remaining, () {
          if (!mounted || widget.isUpdating) {
            _showTimer = null;
            return;
          }
          setState(() {
            _showIndicator = false;
            _shownAt = null;
            _showTimer = null;
          });
        });
        return;
      }
    }

    setState(() {
      _showIndicator = false;
      _shownAt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _showIndicator
          ? const SizedBox(
              key: ValueKey<String>('weekly_schedule_loading_line'),
              child: LinearProgressIndicator(),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _HourViewportTween extends Tween<_HourViewport> {
  _HourViewportTween({_HourViewport? begin, required _HourViewport end})
      : super(begin: begin, end: end);

  @override
  _HourViewport lerp(double t) {
    final beginValue = begin ?? end!;
    final endValue = end!;

    return _HourViewport(
      startHour: lerpDouble(beginValue.startHour, endValue.startHour, t) ??
          endValue.startHour,
      endHour: lerpDouble(beginValue.endHour, endValue.endHour, t) ??
          endValue.endHour,
    );
  }
}

class _AxisLayoutMetrics {
  final double axisWidth;
  final double dayLabelsHeight;
  final bool compactPhone;

  const _AxisLayoutMetrics({
    required this.axisWidth,
    required this.dayLabelsHeight,
    required this.compactPhone,
  });
}

class _FixedHourAxis extends StatelessWidget {
  final double dayLabelsHeight;
  final double startHour;
  final double endHour;
  final bool compactPhone;

  const _FixedHourAxis({
    required this.dayLabelsHeight,
    required this.startHour,
    required this.endHour,
    required this.compactPhone,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleHours = (endHour - startHour).clamp(1.0, 24.0);
        final usableHeight = (constraints.maxHeight - dayLabelsHeight)
            .clamp(1.0, double.infinity);
        final hourHeight = usableHeight / visibleHours;
        final firstHour = startHour.floor();
        final lastHour = endHour.ceil();
        final textColor = Theme.of(context)
            .textTheme
            .bodyMedium
            ?.color
            ?.withValues(alpha: 0.92);

        return Stack(
          fit: StackFit.expand,
          children: [
            for (var hour = firstHour; hour < lastHour; hour++)
              Positioned(
                top: hourHeight * (hour - startHour) + dayLabelsHeight,
                left: 0,
                right: 0,
                child: Padding(
                  padding: compactPhone
                      ? const EdgeInsets.fromLTRB(2, 2, 2, 6)
                      : const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Text(
                    '$hour:00',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: textColor,
                        ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
