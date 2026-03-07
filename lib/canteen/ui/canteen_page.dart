import 'package:dualmate/canteen/ui/viewmodels/canteen_view_model.dart';
import 'package:dualmate/canteen/ui/widgets/filter_dropdown.dart';
import 'package:dualmate/canteen/ui/widgets/meal_card.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';

bool shouldDeferCanteenPageSync({
  required bool hasClients,
  required int attachedPositions,
  required bool isScrolling,
  required bool hasPendingPageDelta,
}) {
  if (!hasClients) {
    return true;
  }

  if (attachedPositions != 1) {
    return true;
  }

  if (hasPendingPageDelta) {
    return true;
  }

  return isScrolling;
}

DateTime resolveCanteenPageSyncTarget({
  required DateTime baseDate,
  required List<DateTime> visibleDays,
  DateTime? selectedDate,
  double? currentPage,
}) {
  if (visibleDays.isNotEmpty && currentPage != null) {
    final roundedPage = currentPage.round().clamp(0, visibleDays.length - 1);
    final controllerTarget = visibleDays[roundedPage];
    final selectedIsFallback =
        selectedDate == null || isAtSameDay(selectedDate, baseDate);
    if (selectedIsFallback && !isAtSameDay(controllerTarget, baseDate)) {
      return controllerTarget;
    }
  }

  return selectedDate ?? baseDate;
}

bool hasPendingCommittedCanteenPage({
  required int committedPage,
  double? currentPage,
}) {
  if (currentPage == null) {
    return false;
  }

  return (currentPage - committedPage).abs() > 0.01;
}

ValueKey<String> canteenDayViewKey(DateTime date) {
  return ValueKey<String>(
    'canteen_day_${toStartOfDay(date).toIso8601String()}',
  );
}

String canteenPageContentModeKey(List<DateTime> visibleDays) {
  return visibleDays.isEmpty
      ? 'canteen_page_content_single'
      : 'canteen_page_content_paged';
}

class CanteenPage extends StatefulWidget {
  @override
  _CanteenPageState createState() => _CanteenPageState();
}

class _CanteenPageState extends State<CanteenPage> {
  static const Duration _initialLoadDelay = Duration(milliseconds: 220);
  static const Duration _initialAdjacentPrefetchDelay =
      Duration(milliseconds: 1200);
  static const double _mealListCacheExtent = 240;
  static final Map<String, DateFormat> _headerDateFormats =
      <String, DateFormat>{};

  late CanteenViewModel viewModel;
  late PageController pageController;
  late ValueNotifier<int> pageNotifier;
  late DateTime baseDate;
  Timer? _initialAdjacentPrefetchTimer;
  Timer? _deferredPageSyncTimer;
  bool _pageSyncPending = false;
  bool _pageScrollListenerAttached = false;
  DateTime? _selectedDate;
  DateTime? _lastInteractionWeekStart;
  bool _isApplyingWidgetPayload = false;

  @override
  void initState() {
    super.initState();
    viewModel = Provider.of<CanteenViewModel>(context, listen: false);
    viewModel.initialize();
    baseDate = _normalizeToWeekday(DateTime.now());
    pageController = PageController(initialPage: 0);
    pageNotifier = ValueNotifier<int>(0);
    WidgetNavigationPayloadStore.instance.addListener(_handleWidgetPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PerformanceTelemetry.instance.markNavEvent(name: "canteen.entry");
      _scheduleInitialAdjacentPrefetch();
      Future.delayed(_initialLoadDelay, () {
        if (!mounted) return;
        SchedulerBinding.instance.scheduleTask<void>(
          () {
            if (!mounted) return;
            _applyWidgetPayload();
          },
          Priority.idle,
          debugLabel: 'canteen.initialLoad',
        );
      });
    });
  }

  @override
  void dispose() {
    _initialAdjacentPrefetchTimer?.cancel();
    _deferredPageSyncTimer?.cancel();
    _detachPageScrollListener();
    WidgetNavigationPayloadStore.instance.removeListener(_handleWidgetPayload);
    pageController.dispose();
    pageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    viewModel = Provider.of<CanteenViewModel>(context, listen: false);
    final locale = L.of(context).locale.toString();
    final dateFormat = _headerDateFormats.putIfAbsent(
      locale,
      () => DateFormat.yMMMMEEEEd(locale),
    );

    return PropertyChangeProvider<CanteenViewModel, String>(
      value: viewModel,
      child: PropertyChangeConsumer<CanteenViewModel, String>(
        properties: const ["weeklyMenus", "loadingWeeks", "weekErrors"],
        builder: (
          BuildContext context,
          CanteenViewModel? model,
          Set<String>? properties,
        ) {
          if (model == null) return const SizedBox();
          final visibleDays = model.visibleContentDays;
          _syncPageForVisibleDays(model, visibleDays);
          if (WidgetNavigationPayloadStore.instance.peekCanteenPayload() !=
                  null &&
              !_isApplyingWidgetPayload) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _applyWidgetPayload(visibleDays: visibleDays);
            });
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<int>(
                        valueListenable: pageNotifier,
                        builder: (context, page, _) {
                          final date =
                              _displayDateForPage(page, visibleDays, model);
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              var offsetAnimation = Tween<Offset>(
                                begin: const Offset(0, 0.15),
                                end: Offset.zero,
                              ).animate(animation);

                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: offsetAnimation,
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              dateFormat.format(date),
                              key: ValueKey(date.toIso8601String()),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Text(
                      L.of(context).filterTitle,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: PropertyChangeConsumer<CanteenViewModel, String>(
                          properties: const ["filter"],
                          builder: (
                            BuildContext context,
                            CanteenViewModel? model,
                            Set<String>? properties,
                          ) {
                            if (model == null) return const SizedBox();
                            return FilterDropdown(
                              filter: model.filter,
                              onChanged: model.setFilter,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final offsetAnimation = Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation);

                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<String>(
                          canteenPageContentModeKey(visibleDays),
                        ),
                        child: _buildPageContent(model, visibleDays),
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: pageNotifier,
                      builder: (context, page, _) {
                        final date =
                            _displayDateForPage(page, visibleDays, model);
                        var showButton = !_isBaseDate(date);

                        return Positioned(
                          right: 16,
                          bottom: 16,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: showButton ? 1 : 0,
                            child: IgnorePointer(
                              ignoring: !showButton,
                              child: FloatingActionButton.extended(
                                heroTag: "canteenBackToToday",
                                onPressed: () {
                                  final targetDay =
                                      model.nearestVisibleContentDay(baseDate);
                                  if (targetDay == null) return;
                                  _goToVisibleDay(
                                    targetDay,
                                    visibleDays,
                                    animate: true,
                                  );
                                },
                                icon: const Icon(Icons.today),
                                label: Text(L.of(context).canteenBackToToday),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime _normalizeToWeekday(DateTime date) {
    var normalized = DateTime(date.year, date.month, date.day);
    if (normalized.weekday == DateTime.saturday) {
      return normalized.add(const Duration(days: 2));
    }
    if (normalized.weekday == DateTime.sunday) {
      return normalized.add(const Duration(days: 1));
    }
    return normalized;
  }

  DateTime _displayDateForPage(
    int page,
    List<DateTime> visibleDays,
    CanteenViewModel model,
  ) {
    if (visibleDays.isNotEmpty) {
      final boundedPage = page.clamp(0, visibleDays.length - 1);
      return visibleDays[boundedPage];
    }

    return _selectedDate ??
        model.nearestVisibleContentDay(baseDate) ??
        baseDate;
  }

  Widget _buildPageContent(
    CanteenViewModel model,
    List<DateTime> visibleDays,
  ) {
    if (visibleDays.isEmpty) {
      final date = _selectedDate ?? baseDate;
      return _CanteenDayView(
        key: canteenDayViewKey(date),
        date: date,
      );
    }

    return StretchingOverscrollIndicator(
      axisDirection: AxisDirection.right,
      child: PageView.builder(
        controller: pageController,
        allowImplicitScrolling: false,
        itemCount: visibleDays.length,
        onPageChanged: (index) {
          final nextDate = visibleDays[index];
          pageNotifier.value = index;
          _selectedDate = nextDate;
          PerformanceTelemetry.instance
              .markNavEvent(name: "canteen.pageChanged");

          final nextWeekStart = viewModel.weekStartFor(nextDate);
          if (_lastInteractionWeekStart != nextWeekStart) {
            _lastInteractionWeekStart = nextWeekStart;
            viewModel.refreshVisibleWeekIfStale(nextDate);
            viewModel.prefetchAdjacentWeeksDebounced(nextDate);
          }
        },
        itemBuilder: (context, index) {
          final date = visibleDays[index];
          return _CanteenDayView(
            key: canteenDayViewKey(date),
            date: date,
          );
        },
      ),
    );
  }

  void _handleWidgetPayload() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyWidgetPayload();
    });
  }

  void _scheduleInitialAdjacentPrefetch() {
    _initialAdjacentPrefetchTimer?.cancel();
    _initialAdjacentPrefetchTimer = Timer(_initialAdjacentPrefetchDelay, () {
      if (!mounted || viewModel.isDisposed) return;
      SchedulerBinding.instance.scheduleTask<void>(
        () {
          if (!mounted || viewModel.isDisposed) return;
          viewModel.prefetchAdjacentWeeks(baseDate);
        },
        Priority.idle,
        debugLabel: 'canteen.initialAdjacentPrefetch',
      );
    });
  }

  void _applyWidgetPayload({
    List<DateTime>? visibleDays,
  }) {
    if (_isApplyingWidgetPayload) return;
    final payload = WidgetNavigationPayloadStore.instance.peekCanteenPayload();
    if (payload == null || payload.dayStart == null) return;

    final targetDate = _normalizeToWeekday(payload.dayStart!);
    final targetWeekStart = viewModel.weekStartFor(targetDate);
    viewModel.primeVisibleWeek(targetDate);
    viewModel.prefetchAdjacentWeeksDebounced(targetDate);

    final hasTargetWeekData = viewModel.hasWeekData(targetWeekStart);
    final isTargetWeekLoading = viewModel.isLoadingWeek(targetWeekStart);
    if (!hasTargetWeekData || isTargetWeekLoading) return;

    if (!pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyWidgetPayload();
      });
      return;
    }

    final targetWeekVisibleDays = _contentDaysForWeek(targetWeekStart);
    final currentVisibleDays = visibleDays ?? viewModel.visibleContentDays;
    final targetDay = _nearestDay(targetDate, targetWeekVisibleDays) ??
        viewModel.nearestVisibleContentDay(
          targetDate,
          precomputedDays: currentVisibleDays,
        );
    if (targetDay == null) {
      WidgetNavigationPayloadStore.instance.takeCanteenPayload();
      return;
    }

    _isApplyingWidgetPayload = true;
    _goToVisibleDay(targetDay, currentVisibleDays);
    WidgetNavigationPayloadStore.instance.takeCanteenPayload();
    _isApplyingWidgetPayload = false;
  }

  void _syncPageForVisibleDays(
    CanteenViewModel model,
    List<DateTime> visibleDays,
  ) {
    if (visibleDays.isEmpty) return;

    final currentPage =
        pageController.hasClients && pageController.positions.length == 1
            ? pageController.page
            : null;
    final currentTarget = resolveCanteenPageSyncTarget(
      baseDate: baseDate,
      visibleDays: visibleDays,
      selectedDate: _selectedDate,
      currentPage: currentPage,
    );
    final syncedDate = model.nearestVisibleContentDay(
      currentTarget,
      precomputedDays: visibleDays,
    );
    if (syncedDate == null) return;

    final targetIndex =
        visibleDays.indexWhere((day) => isAtSameDay(day, syncedDate));
    if (targetIndex < 0) return;

    _selectedDate = syncedDate;
    if (pageNotifier.value == targetIndex) return;
    if (_shouldDeferPageSync()) {
      _pageSyncPending = true;
      return;
    }

    _pageSyncPending = false;
    pageController.jumpToPage(targetIndex);
    pageNotifier.value = targetIndex;
  }

  bool _shouldDeferPageSync() {
    final hasClients = pageController.hasClients;
    final attachedPositions = pageController.positions.length;
    final currentPage =
        hasClients && attachedPositions == 1 ? pageController.page : null;
    final hasPendingPageDelta = hasPendingCommittedCanteenPage(
      committedPage: pageNotifier.value,
      currentPage: currentPage,
    );
    final isScrolling = hasClients && attachedPositions == 1
        ? pageController.position.isScrollingNotifier.value
        : false;

    if (!hasClients || attachedPositions != 1) {
      _scheduleDeferredPageSyncRetry();
      return true;
    }

    _attachPageScrollListener();

    if (shouldDeferCanteenPageSync(
      hasClients: hasClients,
      attachedPositions: attachedPositions,
      isScrolling: isScrolling,
      hasPendingPageDelta: hasPendingPageDelta,
    )) {
      if (hasPendingPageDelta) {
        _scheduleDeferredPageSyncRetry();
      }
      return true;
    }

    return false;
  }

  void _scheduleDeferredPageSyncRetry() {
    _deferredPageSyncTimer?.cancel();
    _deferredPageSyncTimer = Timer(const Duration(milliseconds: 360), () {
      if (!mounted) {
        return;
      }

      _retryPendingPageSync();
    });
  }

  void _retryPendingPageSync() {
    if (!_pageSyncPending || !mounted) {
      return;
    }

    final model = Provider.of<CanteenViewModel>(context, listen: false);
    _syncPageForVisibleDays(model, model.visibleContentDays);
  }

  void _attachPageScrollListener() {
    if (_pageScrollListenerAttached || !pageController.hasClients) {
      return;
    }

    if (pageController.positions.length != 1) {
      return;
    }

    pageController.position.isScrollingNotifier
        .addListener(_handlePageScrollStateChanged);
    _pageScrollListenerAttached = true;
  }

  void _detachPageScrollListener() {
    if (!_pageScrollListenerAttached || !pageController.hasClients) {
      _pageScrollListenerAttached = false;
      return;
    }

    if (pageController.positions.length == 1) {
      pageController.position.isScrollingNotifier
          .removeListener(_handlePageScrollStateChanged);
    }

    _pageScrollListenerAttached = false;
  }

  void _handlePageScrollStateChanged() {
    if (!mounted || !pageController.hasClients) {
      return;
    }

    if (pageController.positions.length != 1) {
      _detachPageScrollListener();
      _scheduleDeferredPageSyncRetry();
      return;
    }

    if (pageController.position.isScrollingNotifier.value) {
      return;
    }

    _retryPendingPageSync();
  }

  void _goToVisibleDay(
    DateTime targetDay,
    List<DateTime> visibleDays, {
    bool animate = false,
  }) {
    final targetIndex =
        visibleDays.indexWhere((day) => isAtSameDay(day, targetDay));
    if (targetIndex < 0) return;
    _selectedDate = targetDay;

    if (!pageController.hasClients) return;
    if (animate) {
      pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      pageController.jumpToPage(targetIndex);
    }

    pageNotifier.value = targetIndex;
  }

  List<DateTime> _contentDaysForWeek(DateTime weekStart) {
    final days = <DateTime>[];

    for (final menu in viewModel.weeklyMenusFor(weekStart)) {
      if (menu.meals.isEmpty) continue;
      days.add(toStartOfDay(menu.date));
    }

    days.sort((a, b) => a.compareTo(b));
    return days;
  }

  DateTime? _nearestDay(DateTime targetDate, List<DateTime> days) {
    if (days.isEmpty) return null;
    final normalizedTarget = toStartOfDay(targetDate);
    var nearest = days.first;
    var minDistance = nearest.difference(normalizedTarget).inDays.abs();

    for (final day in days.skip(1)) {
      final distance = day.difference(normalizedTarget).inDays.abs();
      if (distance < minDistance) {
        nearest = day;
        minDistance = distance;
      }
    }

    return nearest;
  }

  bool _isBaseDate(DateTime date) {
    return date.year == baseDate.year &&
        date.month == baseDate.month &&
        date.day == baseDate.day;
  }
}

class _CanteenDayView extends StatefulWidget {
  final DateTime date;

  const _CanteenDayView({
    Key? key,
    required this.date,
  }) : super(key: key);

  @override
  State<_CanteenDayView> createState() => _CanteenDayViewState();
}

class _CanteenDayViewState extends State<_CanteenDayView> {
  @override
  Widget build(BuildContext context) {
    return PropertyChangeConsumer<CanteenViewModel, String>(
      properties: const [
        "weeklyMenus",
        "loadingWeeks",
        "weekErrors",
        "filter",
      ],
      builder: (
        BuildContext context,
        CanteenViewModel? model,
        Set<String>? properties,
      ) {
        if (model == null) return const SizedBox();

        var weekStart = model.weekStartFor(widget.date);
        var meals = model.mealsForDay(weekStart, widget.date);
        var isLoading = model.isLoadingWeek(weekStart);
        var showError = model.errorForWeek(weekStart) != null;
        var hasWeekData = model.hasWeekData(weekStart);
        var lastUpdated = model.lastUpdatedForWeek(weekStart);

        late final String stateKey;
        late final Widget stateChild;
        final dayKey = toStartOfDay(widget.date).millisecondsSinceEpoch;

        if ((!hasWeekData || isLoading) && meals.isEmpty) {
          stateKey = 'loading_$dayKey';
          stateChild = const _MealLoadingList();
        } else if (meals.isEmpty) {
          stateKey = 'empty_${showError ? 'error' : 'plain'}_$dayKey';
          stateChild = _buildEmptyState(
            context,
            showError: showError,
            lastUpdated: lastUpdated,
          );
        } else {
          stateKey = 'ready_${meals.length}_$dayKey';
          stateChild = RefreshIndicator(
            onRefresh: () => model.loadWeek(weekStart),
            child: ListView.builder(
              key: PageStorageKey("canteen_${widget.date.toIso8601String()}"),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: meals.length,
              addAutomaticKeepAlives: false,
              cacheExtent: _CanteenPageState._mealListCacheExtent,
              itemBuilder: (context, index) {
                var meal = meals[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MealCard(meal: meal),
                );
              },
            ),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: offsetAnimation,
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<String>('canteen_state_$stateKey'),
            child: stateChild,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required bool showError,
    DateTime? lastUpdated,
  }) {
    final lastUpdatedText = _formatLastUpdated(context, lastUpdated);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
        child: Column(
          children: [
            Text(
              showError
                  ? L.of(context).canteenLoadError
                  : L.of(context).canteenNoMenuToday,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (lastUpdatedText != null) ...[
              const SizedBox(height: 8),
              Text(
                lastUpdatedText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (showError) ...[
              const SizedBox(height: 12),
              Text(
                L.of(context).canteenNoMenuToday,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            Opacity(
              opacity: 0.9,
              child: Image.asset("assets/empty_state.png"),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatLastUpdated(BuildContext context, DateTime? lastUpdated) {
    if (lastUpdated == null) return null;
    final formatted = DateFormat.yMMMd(L.of(context).locale.toString())
        .add_Hm()
        .format(lastUpdated);
    final template = L.of(context).lastUpdatedLabel;
    assert(template.contains("%0"));
    if (!template.contains("%0")) {
      return formatted;
    }
    return template.replaceFirst("%0", formatted);
  }
}

class _MealLoadingList extends StatelessWidget {
  const _MealLoadingList();

  @override
  Widget build(BuildContext context) {
    var isDark = Theme.of(context).brightness == Brightness.dark;
    var baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE6E6E8);
    var highlightColor =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF2F2F2);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.75, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, opacity, child) {
        return Opacity(opacity: opacity, child: child);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: 6,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MealSkeletonCard(
              baseColor: baseColor,
              shimmerColor: highlightColor,
            ),
          );
        },
      ),
    );
  }
}

class _MealSkeletonCard extends StatelessWidget {
  final Color baseColor;
  final Color shimmerColor;

  const _MealSkeletonCard({
    required this.baseColor,
    required this.shimmerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: baseColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 16,
              width: 200,
              color: shimmerColor,
            ),
            const SizedBox(height: 8),
            Container(
              height: 12,
              width: 120,
              color: shimmerColor,
            ),
            const SizedBox(height: 16),
            Container(
              height: 10,
              width: 240,
              color: shimmerColor,
            ),
          ],
        ),
      ),
    );
  }
}
