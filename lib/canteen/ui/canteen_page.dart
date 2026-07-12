import 'dart:async';
import 'dart:math' as math;

import 'package:dualmate/canteen/ui/canteen_page_sync_coordinator.dart';
import 'package:dualmate/canteen/ui/viewmodels/canteen_render_state.dart';
import 'package:dualmate/canteen/ui/viewmodels/canteen_view_model.dart';
import 'package:dualmate/canteen/ui/widgets/filter_dropdown.dart';
import 'package:dualmate/canteen/ui/widgets/meal_card.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';

const double kMealListCacheExtent = 240;

ValueKey<String> canteenDayViewKey(DateTime date) {
  return ValueKey<String>(
    'canteen_day_${toStartOfDay(date).toIso8601String()}',
  );
}

String canteenPageContentModeKey(List<DateTime> visibleDays) {
  return 'canteen_page_content';
}

int? findCanteenDayIndexByKey(Key key, List<DateTime> visibleDays) {
  if (key is! ValueKey<String>) {
    return null;
  }

  for (var index = 0; index < visibleDays.length; index++) {
    if (canteenDayViewKey(visibleDays[index]) == key) {
      return index;
    }
  }

  return null;
}

class _CanteenHeader extends StatelessWidget {
  final DateFormat dateFormat;
  final ValueListenable<DateTime> selectedDate;

  const _CanteenHeader({required this.dateFormat, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return PropertyChangeConsumer<CanteenViewModel, String>(
      properties: const ['selectedLocation'],
      builder: (context, model, _) {
        if (model == null) return const SizedBox();
        final location = model.selectedLocation;
        final subtitle = location.subtitle;
        final locationText = subtitle == null || subtitle.isEmpty
            ? location.name
            : '${location.name} - $subtitle';
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<DateTime>(
                valueListenable: selectedDate,
                builder: (context, date, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = Tween<Offset>(
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
                      key: ValueKey<String>(date.toIso8601String()),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                locationText,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CanteenFilterBar extends StatelessWidget {
  const _CanteenFilterBar();

  @override
  Widget build(BuildContext context) {
    return PropertyChangeConsumer<CanteenViewModel, String>(
      properties: const ['filter'],
      builder: (context, model, _) {
        if (model == null) return const SizedBox();
        return Padding(
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
                  child: FilterDropdown(
                    filter: model.filter,
                    onChanged: model.setFilter,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CanteenPage extends StatefulWidget {
  @override
  _CanteenPageState createState() => _CanteenPageState();
}

class _CanteenPageState extends State<CanteenPage> {
  static const Duration _initialLoadDelay = Duration(milliseconds: 220);
  static final Map<String, DateFormat> _headerDateFormats =
      <String, DateFormat>{};

  late CanteenViewModel viewModel;
  late PageController pageController;
  late ValueNotifier<int> pageNotifier;
  late ValueNotifier<DateTime> _selectedDateNotifier;
  late CanteenPageSyncCoordinator _pageSyncCoordinator;
  late DateTime baseDate;
  DateTime? _selectedDate;
  DateTime? _lastInteractionWeekStart;
  bool _isApplyingWidgetPayload = false;
  bool _pageSyncRetryScheduled = false;

  @override
  void initState() {
    super.initState();
    viewModel = Provider.of<CanteenViewModel>(context, listen: false);
    viewModel.initialize();
    baseDate = _normalizeToWeekday(DateTime.now());
    _lastInteractionWeekStart = viewModel.weekStartFor(baseDate);
    pageController = PageController(initialPage: 0);
    pageNotifier = ValueNotifier<int>(0);
    _selectedDateNotifier = ValueNotifier<DateTime>(baseDate);
    _pageSyncCoordinator = CanteenPageSyncCoordinator(
      pageController: pageController,
      pageNotifier: pageNotifier,
      isMounted: () => mounted,
      onRetryPendingSync: _retryPendingPageSync,
    );
    WidgetNavigationPayloadStore.instance.addListener(_handleWidgetPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PerformanceTelemetry.instance.markNavEvent(name: "canteen.entry");
      Future.delayed(_initialLoadDelay, () {
        if (!mounted) return;
        viewModel.primeVisibleWeek(baseDate);
        viewModel.prefetchAdjacentWeeks(baseDate);
        _applyWidgetPayload();
      });
    });
  }

  @override
  void dispose() {
    _pageSyncCoordinator.dispose();
    WidgetNavigationPayloadStore.instance.removeListener(_handleWidgetPayload);
    pageController.dispose();
    pageNotifier.dispose();
    _selectedDateNotifier.dispose();
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
      child: Column(
        children: [
          _CanteenHeader(
            dateFormat: dateFormat,
            selectedDate: _selectedDateNotifier,
          ),
          const _CanteenFilterBar(),
          Expanded(
            child: Stack(
              children: [
                PropertyChangeConsumer<CanteenViewModel, String>(
                  properties: const [
                    CanteenViewModel.weekStateProperty,
                    'selectedLocation',
                  ],
                  builder: (context, model, _) {
                    if (model == null) return const SizedBox();
                    final visibleDays = model.visibleContentDays;
                    _syncPageForVisibleDays(model, visibleDays);
                    if (WidgetNavigationPayloadStore.instance
                                .peekCanteenPayload() !=
                            null &&
                        !_isApplyingWidgetPayload) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _applyWidgetPayload(visibleDays: visibleDays);
                      });
                    }
                    return _buildPageContent(model, visibleDays);
                  },
                ),
                ValueListenableBuilder<DateTime>(
                  valueListenable: _selectedDateNotifier,
                  builder: (context, date, _) {
                    final showButton = !_isBaseDate(date);
                    return Positioned(
                      right: 16,
                      bottom: 16,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: showButton ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !showButton,
                          child: FloatingActionButton.extended(
                            heroTag: 'canteenBackToToday',
                            onPressed: () {
                              final targetDay = viewModel
                                  .nearestVisibleContentDay(baseDate);
                              if (targetDay == null) return;
                              _goToVisibleDay(
                                targetDay,
                                viewModel.visibleContentDays,
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

  Widget _buildPageContent(CanteenViewModel model, List<DateTime> visibleDays) {
    final pageDates = visibleDays.isEmpty
        ? <DateTime>[_selectedDate ?? baseDate]
        : visibleDays;

    return StretchingOverscrollIndicator(
      axisDirection: AxisDirection.right,
      child: PageView.builder(
        key: const ValueKey<String>('canteen_page_view'),
        controller: pageController,
        allowImplicitScrolling: true,
        findChildIndexCallback: (key) {
          return findCanteenDayIndexByKey(key, pageDates);
        },
        itemCount: pageDates.length,
        onPageChanged: (index) {
          final nextDate = pageDates[index];
          pageNotifier.value = index;
          _setSelectedDate(nextDate);
          PerformanceTelemetry.instance.markNavEvent(
            name: "canteen.pageChanged",
          );

          final nextWeekStart = viewModel.weekStartFor(nextDate);
          if (_lastInteractionWeekStart != nextWeekStart) {
            _lastInteractionWeekStart = nextWeekStart;
            viewModel.refreshVisibleWeekIfStale(nextDate);
            viewModel.prefetchAdjacentWeeksDebounced(nextDate);
          }
        },
        itemBuilder: (context, index) {
          final date = pageDates[index];
          return _CanteenDayView(key: canteenDayViewKey(date), date: date);
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

  void _applyWidgetPayload({List<DateTime>? visibleDays}) {
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
    final targetDay =
        _nearestDay(targetDate, targetWeekVisibleDays) ??
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
    List<DateTime> visibleDays, {
    bool allowRangeRetry = true,
  }) {
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

    final targetIndex = visibleDays.indexWhere(
      (day) => isAtSameDay(day, syncedDate),
    );
    if (targetIndex < 0) return;

    _setSelectedDate(syncedDate);
    if (pageNotifier.value == targetIndex) return;
    if (_pageTargetExceedsMountedPageRange(targetIndex)) {
      _pageSyncCoordinator.markPending();
      if (allowRangeRetry) {
        _schedulePageSyncRetry();
      }
      return;
    }
    if (_pageSyncCoordinator.shouldDeferSync()) {
      _pageSyncCoordinator.markPending();
      return;
    }

    _pageSyncCoordinator.clearPending();
    pageController.jumpToPage(targetIndex);
    pageNotifier.value = targetIndex;
  }

  void _retryPendingPageSync() {
    final model = Provider.of<CanteenViewModel>(context, listen: false);
    _syncPageForVisibleDays(model, model.visibleContentDays);
  }

  bool _pageTargetExceedsMountedPageRange(int targetIndex) {
    if (!pageController.hasClients ||
        pageController.positions.length != 1 ||
        !pageController.position.hasViewportDimension) {
      return false;
    }
    final viewportDimension = pageController.position.viewportDimension;
    if (viewportDimension == 0) return false;
    final maxPage = pageController.position.maxScrollExtent / viewportDimension;
    return targetIndex.toDouble() > maxPage + 0.01;
  }

  void _schedulePageSyncRetry() {
    if (_pageSyncRetryScheduled) return;
    _pageSyncRetryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageSyncRetryScheduled = false;
      if (!mounted) return;
      final model = Provider.of<CanteenViewModel>(context, listen: false);
      _syncPageForVisibleDays(
        model,
        model.visibleContentDays,
        allowRangeRetry: false,
      );
    });
  }

  void _goToVisibleDay(
    DateTime targetDay,
    List<DateTime> visibleDays, {
    bool animate = false,
  }) {
    final targetIndex = visibleDays.indexWhere(
      (day) => isAtSameDay(day, targetDay),
    );
    if (targetIndex < 0) return;
    _setSelectedDate(targetDay);

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

  void _setSelectedDate(DateTime date) {
    final normalizedDate = toStartOfDay(date);
    _selectedDate = normalizedDate;
    if (_selectedDateNotifier.value != normalizedDate) {
      _selectedDateNotifier.value = normalizedDate;
    }
  }

  List<DateTime> _contentDaysForWeek(DateTime weekStart) {
    return viewModel.contentDaysForWeek(weekStart);
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

class _CanteenDayView extends StatelessWidget {
  final DateTime date;

  const _CanteenDayView({Key? key, required this.date}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<CanteenViewModel, CanteenDayContentState>(
      selector: (context, model) => model.dayContentStateFor(date),
      builder: (context, selection, _) {
        return _CanteenDayContent(selection: selection, date: date);
      },
    );
  }
}

class _CanteenDayContent extends StatefulWidget {
  final DateTime date;
  final CanteenDayContentState selection;

  const _CanteenDayContent({required this.date, required this.selection});

  @override
  State<_CanteenDayContent> createState() => _CanteenDayContentState();
}

class _CanteenDayContentState extends State<_CanteenDayContent>
    with SingleTickerProviderStateMixin {
  static const Duration _transitionDuration = Duration(milliseconds: 320);

  late final AnimationController _transitionController;
  late final Animation<double> _transitionAnimation;
  CanteenDayContentState? _previousSelection;
  bool _tickerEnabled = false;
  bool _transitionPending = false;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: _transitionDuration,
      value: 1,
    )..addStatusListener(_handleTransitionStatus);
    _transitionAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled == tickerEnabled) return;

    _tickerEnabled = tickerEnabled;
    if (!tickerEnabled && _transitionController.isAnimating) {
      _transitionController
        ..stop()
        ..value = 0;
      _transitionPending = _previousSelection != null;
      return;
    }

    if (tickerEnabled && _transitionPending) {
      _transitionPending = false;
      _transitionController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant _CanteenDayContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection == widget.selection) return;

    _previousSelection = oldWidget.selection;
    if (_tickerEnabled) {
      _transitionPending = false;
      _transitionController.forward(from: 0);
    } else {
      _transitionPending = true;
      _transitionController
        ..stop()
        ..value = 0;
    }
  }

  void _handleTransitionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _previousSelection == null) {
      return;
    }
    setState(() {
      _previousSelection = null;
      _transitionPending = false;
    });
  }

  @override
  void dispose() {
    _transitionController
      ..removeStatusListener(_handleTransitionStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    final previousSelection = _previousSelection;
    final itemCount = previousSelection == null
        ? _itemCount(selection)
        : math.max(_itemCount(previousSelection), _itemCount(selection));
    final list = ListView.builder(
      key: PageStorageKey<String>('canteen_${widget.date.toIso8601String()}'),
      padding: _hasMeals(selection) || _isLoading(selection)
          ? const EdgeInsets.fromLTRB(16, 8, 16, 16)
          : EdgeInsets.zero,
      itemCount: itemCount,
      addAutomaticKeepAlives: false,
      // ignore: deprecated_member_use
      cacheExtent: kMealListCacheExtent,
      physics: _hasMeals(selection)
          ? null
          : const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final previousChild =
            previousSelection != null && index < _itemCount(previousSelection)
            ? _buildItem(context, previousSelection, index)
            : null;
        final currentChild = index < _itemCount(selection)
            ? _buildItem(context, selection, index)
            : null;

        if (previousChild == null) {
          return currentChild!;
        }
        return _AnimatedDayItem(
          key: ValueKey<String>(
            'canteen_day_item_${widget.date.toIso8601String()}_$index',
          ),
          animation: _transitionAnimation,
          oldChild: previousChild,
          newChild: currentChild,
        );
      },
    );

    if (_hasMeals(selection)) {
      final weekStart = toStartOfDay(toMonday(widget.date));
      return RefreshIndicator(
        onRefresh: () => Provider.of<CanteenViewModel>(
          context,
          listen: false,
        ).loadWeek(weekStart),
        child: list,
      );
    }
    if (_isLoading(selection)) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.75, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity, child: child);
        },
        child: list,
      );
    }
    return list;
  }

  int _itemCount(CanteenDayContentState selection) {
    if (_isLoading(selection)) return 6;
    if (selection.meals.isEmpty) return 1;
    return selection.meals.length;
  }

  bool _hasMeals(CanteenDayContentState selection) {
    return selection.meals.isNotEmpty;
  }

  bool _isLoading(CanteenDayContentState selection) {
    return (!selection.day.hasWeekData || selection.day.isLoading) &&
        selection.meals.isEmpty;
  }

  Widget _buildItem(
    BuildContext context,
    CanteenDayContentState selection,
    int index,
  ) {
    late final Widget child;
    if (_isLoading(selection)) {
      child = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _MealSkeletonCard(
          baseColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFE6E6E8),
          shimmerColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFF2F2F2),
        ),
      );
    } else if (selection.meals.isEmpty) {
      child = _buildEmptyState(
        context,
        showError: selection.day.error != null,
        lastUpdated: selection.day.lastUpdated,
      );
    } else {
      child = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: MealCard(meal: selection.meals[index]),
      );
    }

    if (index != 0) return child;
    return KeyedSubtree(
      key: ValueKey<String>('canteen_state_${_stateKey(selection)}'),
      child: child,
    );
  }

  String _stateKey(CanteenDayContentState selection) {
    final dayKey = toStartOfDay(widget.date).millisecondsSinceEpoch;
    if (_isLoading(selection)) return 'loading_$dayKey';
    if (selection.meals.isEmpty) {
      return 'empty_${selection.day.error != null ? 'error' : 'plain'}_$dayKey';
    }
    return 'ready_${selection.meals.length}_$dayKey';
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required bool showError,
    required DateTime? lastUpdated,
  }) {
    final lastUpdatedText = _formatLastUpdated(context, lastUpdated);
    return Padding(
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
          Opacity(opacity: 0.9, child: Image.asset("assets/empty_state.png")),
        ],
      ),
    );
  }

  String? _formatLastUpdated(BuildContext context, DateTime? lastUpdated) {
    if (lastUpdated == null) return null;
    final formatted = DateFormat.yMMMd(
      L.of(context).locale.toString(),
    ).add_Hm().format(lastUpdated);
    final template = L.of(context).lastUpdatedLabel;
    assert(template.contains("%0"));
    if (!template.contains("%0")) {
      return formatted;
    }
    return template.replaceFirst("%0", formatted);
  }
}

class _AnimatedDayItem extends StatelessWidget {
  final Animation<double> animation;
  final Widget oldChild;
  final Widget? newChild;

  const _AnimatedDayItem({
    super.key,
    required this.animation,
    required this.oldChild,
    required this.newChild,
  });

  @override
  Widget build(BuildContext context) {
    final outgoingPosition = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.06),
    ).animate(animation);
    final incomingPosition = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(animation);

    return ClipRect(
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          FadeTransition(
            opacity: ReverseAnimation(animation),
            child: SlideTransition(position: outgoingPosition, child: oldChild),
          ),
          if (newChild != null)
            FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: incomingPosition,
                child: newChild,
              ),
            ),
        ],
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
            Container(height: 16, width: 200, color: shimmerColor),
            const SizedBox(height: 8),
            Container(height: 12, width: 120, color: shimmerColor),
            const SizedBox(height: 16),
            Container(height: 10, width: 240, color: shimmerColor),
          ],
        ),
      ),
    );
  }
}
