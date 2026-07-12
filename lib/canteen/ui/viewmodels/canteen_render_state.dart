import 'package:dualmate/canteen/model/canteen_filter.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/common/util/date_utils.dart';

/// Immutable render data for one canteen day.
///
/// The lists are snapshotted when a week is applied so widget builds can reuse
/// the same object until that day's source data actually changes.
class CanteenDayRenderState {
  static const List<Meal> _emptyMeals = <Meal>[];

  final DateTime date;
  final List<Meal> meals;
  final bool hasWeekData;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const CanteenDayRenderState({
    required this.date,
    required this.meals,
    required this.hasWeekData,
    required this.isLoading,
    required this.error,
    required this.lastUpdated,
  });

  factory CanteenDayRenderState.empty(DateTime date) {
    return CanteenDayRenderState(
      date: toStartOfDay(date),
      meals: _emptyMeals,
      hasWeekData: false,
      isLoading: false,
      error: null,
      lastUpdated: null,
    );
  }

  CanteenDayRenderState copyWith({
    List<Meal>? meals,
    bool? hasWeekData,
    bool? isLoading,
    Object? error = _notSpecified,
    Object? lastUpdated = _notSpecified,
  }) {
    return CanteenDayRenderState(
      date: date,
      meals: meals ?? this.meals,
      hasWeekData: hasWeekData ?? this.hasWeekData,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _notSpecified) ? this.error : error as String?,
      lastUpdated: identical(lastUpdated, _notSpecified)
          ? this.lastUpdated
          : lastUpdated as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CanteenDayRenderState &&
        other.date == date &&
        identical(other.meals, meals) &&
        other.hasWeekData == hasWeekData &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode => Object.hash(
    date,
    identityHashCode(meals),
    hasWeekData,
    isLoading,
    error,
    lastUpdated,
  );
}

const Object _notSpecified = Object();

/// Immutable render snapshot for one loaded week.
class CanteenWeekRenderState {
  final DateTime weekStart;
  final List<DailyMenu> menus;
  final List<CanteenDayRenderState> days;
  final List<DateTime> contentDays;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final Map<DateTime, CanteenDayRenderState> _daysByDate;

  CanteenWeekRenderState({
    required this.weekStart,
    required List<DailyMenu> menus,
    required List<CanteenDayRenderState> days,
    required List<DateTime> contentDays,
    required this.isLoading,
    required this.error,
    required this.lastUpdated,
  }) : menus = List<DailyMenu>.unmodifiable(menus),
       days = List<CanteenDayRenderState>.unmodifiable(days),
       contentDays = List<DateTime>.unmodifiable(contentDays),
       _daysByDate = Map<DateTime, CanteenDayRenderState>.unmodifiable(
         <DateTime, CanteenDayRenderState>{
           for (final day in days) day.date: day,
         },
       );

  factory CanteenWeekRenderState.empty(
    DateTime weekStart, {
    bool isLoading = false,
  }) {
    final normalizedWeekStart = toStartOfDay(toMonday(weekStart));
    final days = List<CanteenDayRenderState>.generate(5, (index) {
      return CanteenDayRenderState(
        date: normalizedWeekStart.add(Duration(days: index)),
        meals: const <Meal>[],
        hasWeekData: false,
        isLoading: isLoading,
        error: null,
        lastUpdated: null,
      );
    }, growable: false);
    return CanteenWeekRenderState(
      weekStart: normalizedWeekStart,
      menus: [
        for (final day in days) DailyMenu(date: day.date, meals: day.meals),
      ],
      days: days,
      contentDays: const <DateTime>[],
      isLoading: isLoading,
      error: null,
      lastUpdated: null,
    );
  }

  factory CanteenWeekRenderState.fromMenus(
    DateTime weekStart,
    List<DailyMenu> sourceMenus, {
    CanteenWeekRenderState? previous,
    bool isLoading = false,
    String? error,
    DateTime? lastUpdated,
  }) {
    final normalizedWeekStart = toStartOfDay(toMonday(weekStart));
    final sourceByDate = <DateTime, List<Meal>>{};
    for (final menu in sourceMenus) {
      final day = toStartOfDay(menu.date);
      sourceByDate[day] = List<Meal>.unmodifiable(menu.meals);
    }

    final days = <CanteenDayRenderState>[];
    final menus = <DailyMenu>[];
    final contentDays = <DateTime>[];
    for (var index = 0; index < 5; index++) {
      final date = normalizedWeekStart.add(Duration(days: index));
      final sourceMeals = sourceByDate[date] ?? const <Meal>[];
      final previousDay = previous?.dayFor(date);
      final meals =
          previousDay != null && _sameMeals(previousDay.meals, sourceMeals)
          ? previousDay.meals
          : sourceMeals;
      final day = CanteenDayRenderState(
        date: date,
        meals: meals,
        hasWeekData: true,
        isLoading: isLoading,
        error: error,
        lastUpdated: lastUpdated,
      );
      days.add(day);
      menus.add(DailyMenu(date: date, meals: meals));
      if (meals.isNotEmpty) contentDays.add(date);
    }

    return CanteenWeekRenderState(
      weekStart: normalizedWeekStart,
      menus: menus,
      days: days,
      contentDays: contentDays,
      isLoading: isLoading,
      error: error,
      lastUpdated: lastUpdated,
    );
  }

  CanteenDayRenderState? dayFor(DateTime date) {
    return _daysByDate[toStartOfDay(date)];
  }

  CanteenWeekRenderState copyWith({
    List<DailyMenu>? menus,
    List<CanteenDayRenderState>? days,
    List<DateTime>? contentDays,
    bool? isLoading,
    Object? error = _notSpecified,
    Object? lastUpdated = _notSpecified,
  }) {
    assert(
      (menus == null) == (days == null),
      'menus and days must be supplied together so their entries correspond.',
    );
    assert(
      menus == null || menus.length == days!.length,
      'menus and days must contain corresponding entries.',
    );
    final nextIsLoading = isLoading ?? this.isLoading;
    final nextError = identical(error, _notSpecified)
        ? this.error
        : error as String?;
    final nextLastUpdated = identical(lastUpdated, _notSpecified)
        ? this.lastUpdated
        : lastUpdated as DateTime?;
    final nextDays =
        days ??
        (nextIsLoading == this.isLoading &&
                nextError == this.error &&
                nextLastUpdated == this.lastUpdated
            ? this.days
            : this.days
                  .map(
                    (day) => day.copyWith(
                      isLoading: nextIsLoading,
                      error: nextError,
                      lastUpdated: nextLastUpdated,
                    ),
                  )
                  .toList(growable: false));
    return CanteenWeekRenderState(
      weekStart: weekStart,
      menus: menus ?? this.menus,
      days: nextDays,
      contentDays: contentDays ?? this.contentDays,
      isLoading: nextIsLoading,
      error: nextError,
      lastUpdated: nextLastUpdated,
    );
  }
}

bool _sameMeals(List<Meal> first, List<Meal> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (!identical(first[index], second[index])) return false;
  }
  return true;
}

/// The exact selection a day widget needs from the view model.
class CanteenDayContentState {
  final CanteenDayRenderState day;
  final CanteenFilter filter;
  final List<Meal> meals;

  const CanteenDayContentState({
    required this.day,
    required this.filter,
    required this.meals,
  });

  @override
  bool operator ==(Object other) {
    if (other is! CanteenDayContentState ||
        other.filter != filter ||
        !identical(other.meals, meals)) {
      return false;
    }

    final otherDay = other.day;
    final hasVisibleMeals = meals.isNotEmpty;
    return otherDay.date == day.date &&
        otherDay.hasWeekData == day.hasWeekData &&
        (hasVisibleMeals || otherDay.isLoading == day.isLoading) &&
        (hasVisibleMeals || otherDay.error == day.error) &&
        (hasVisibleMeals || otherDay.lastUpdated == day.lastUpdated);
  }

  @override
  int get hashCode => Object.hash(
    day.date,
    day.hasWeekData,
    meals.isNotEmpty ? null : day.isLoading,
    meals.isNotEmpty ? null : day.error,
    meals.isNotEmpty ? null : day.lastUpdated,
    filter,
    identityHashCode(meals),
  );
}
