import 'package:dualmate/canteen/ui/viewmodels/canteen_view_model.dart';
import 'package:dualmate/canteen/ui/widgets/filter_dropdown.dart';
import 'package:dualmate/canteen/ui/widgets/meal_card.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/util/widget_navigation_payload.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';

class CanteenPage extends StatefulWidget {
  @override
  _CanteenPageState createState() => _CanteenPageState();
}

class _CanteenPageState extends State<CanteenPage> {
  static const int _basePage = 10000;

  late CanteenViewModel viewModel;
  late PageController pageController;
  late ValueNotifier<int> pageNotifier;
  late DateTime baseDate;
  bool _isApplyingWidgetPayload = false;

  @override
  void initState() {
    super.initState();
    viewModel = Provider.of<CanteenViewModel>(context, listen: false);
    viewModel.initialize();
    baseDate = _normalizeToWeekday(DateTime.now());
    pageController = PageController(initialPage: _basePage);
    pageNotifier = ValueNotifier<int>(_basePage);
    WidgetNavigationPayloadStore.instance.addListener(_handleWidgetPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PerformanceTelemetry.instance.markNavEvent(name: "canteen.entry");
      _loadWeekForDate(baseDate);
      _applyWidgetPayload();
    });
  }

  @override
  void dispose() {
    WidgetNavigationPayloadStore.instance.removeListener(_handleWidgetPayload);
    pageController.dispose();
    pageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    viewModel = Provider.of<CanteenViewModel>(context, listen: false);
    var dateFormat = DateFormat.yMMMMEEEEd(L.of(context).locale.toString());

    return PropertyChangeProvider<CanteenViewModel, String>(
      value: viewModel,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: pageNotifier,
                    builder: (context, page, _) {
                      var date = _dateForPage(page);
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
                PageView.builder(
                  controller: pageController,
                  allowImplicitScrolling: true,
                  onPageChanged: (index) {
                    pageNotifier.value = index;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      PerformanceTelemetry.instance
                          .markNavEvent(name: "canteen.pageChanged");
                      _loadWeekForDate(_dateForPage(index));
                    });
                  },
                  itemBuilder: (context, index) {
                    var date = _dateForPage(index);
                    return _CanteenDayView(date: date);
                  },
                ),
                ValueListenableBuilder<int>(
                  valueListenable: pageNotifier,
                  builder: (context, page, _) {
                    var date = _dateForPage(page);
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
                              pageController.animateToPage(
                                _basePage,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
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

  DateTime _dateForPage(int page) {
    var offset = page - _basePage;
    var baseWeekStart = _toMonday(baseDate);
    var baseIndex = baseDate.weekday - 1;
    var totalIndex = baseIndex + offset;
    var weekOffset = _floorDiv(totalIndex, 5);
    var dayIndex = totalIndex - (weekOffset * 5);
    var date = baseWeekStart.add(Duration(days: weekOffset * 7 + dayIndex));
    return _normalizeToWeekday(date);
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

  int _pageForDate(DateTime date) {
    final normalized = _normalizeToWeekday(date);
    final baseWeekStart = _toMonday(baseDate);
    final targetWeekStart = _toMonday(normalized);
    final weekOffset = targetWeekStart.difference(baseWeekStart).inDays ~/ 7;
    final baseIndex = baseDate.weekday - 1;
    final dayIndex = normalized.weekday - 1;
    final totalIndex = weekOffset * 5 + dayIndex;
    return _basePage + (totalIndex - baseIndex);
  }

  DateTime _toMonday(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  int _floorDiv(int value, int divisor) {
    if (value >= 0) return value ~/ divisor;
    return -(((-value + divisor - 1) ~/ divisor));
  }

  void _loadWeekForDate(DateTime date) {
    viewModel.ensureWeekLoaded(viewModel.weekStartFor(date));
  }

  void _handleWidgetPayload() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyWidgetPayload();
    });
  }

  void _applyWidgetPayload() {
    if (_isApplyingWidgetPayload) return;
    final payload = WidgetNavigationPayloadStore.instance.peekCanteenPayload();
    if (payload == null || payload.dayStart == null) return;

    final targetDate = _normalizeToWeekday(payload.dayStart!);
    print("Widget canteen target date: $targetDate");
    final targetPage = _pageForDate(targetDate);

    if (!pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyWidgetPayload();
      });
      return;
    }

    _isApplyingWidgetPayload = true;
    WidgetNavigationPayloadStore.instance.takeCanteenPayload();
    pageController.jumpToPage(targetPage);
    pageNotifier.value = targetPage;
    _loadWeekForDate(targetDate);
    _isApplyingWidgetPayload = false;
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

        if ((!hasWeekData || isLoading) && meals.isEmpty) {
          return const _MealLoadingList();
        }

        if (meals.isEmpty) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: SizedBox(
              key: ValueKey("canteen_empty_${showError}"),
              child: _buildEmptyState(
                context,
                showError: showError,
                lastUpdated: lastUpdated,
              ),
            ),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: SizedBox(
            key: ValueKey("canteen_ready_${meals.length}"),
            child: RefreshIndicator(
              onRefresh: () => model.loadWeek(weekStart),
              child: ListView.builder(
                key: PageStorageKey("canteen_${widget.date.toIso8601String()}"),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: meals.length,
                addAutomaticKeepAlives: false,
                cacheExtent: MediaQuery.of(context).size.height * 2.5,
                itemBuilder: (context, index) {
                  var meal = meals[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MealCard(meal: meal),
                  );
                },
              ),
            ),
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
    assert(L.of(context).lastUpdatedLabel.contains("%0"));
    return L.of(context).lastUpdatedLabel.replaceFirst("%0", formatted);
  }
}

class _MealLoadingList extends StatefulWidget {
  const _MealLoadingList();

  @override
  State<_MealLoadingList> createState() => _MealLoadingListState();
}

class _MealLoadingListState extends State<_MealLoadingList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var isDark = Theme.of(context).brightness == Brightness.dark;
    var baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE6E6E8);
    var highlightColor =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF2F2F2);

    return FadeTransition(
      opacity: _opacity,
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
