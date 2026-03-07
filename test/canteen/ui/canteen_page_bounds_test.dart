import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/service/canteen_scraper.dart';
import 'package:dualmate/canteen/ui/canteen_page.dart';
import 'package:dualmate/canteen/ui/viewmodels/canteen_view_model.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('limits page count to only days with content', (tester) async {
    final now = DateTime.now();
    final today = _normalizeToWeekday(now);
    final weekStart = toStartOfDay(toMonday(today));
    final menus = _buildWeekMenusWithSingleDayMeal(weekStart, today);

    final provider = _FakeCanteenProvider({weekStart: menus});
    final viewModel = CanteenViewModel(provider);
    addTearDown(viewModel.dispose);
    await viewModel.loadWeek(weekStart);

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await _pumpFor(tester, const Duration(milliseconds: 700));

    final pageView = tester.widget<PageView>(find.byType(PageView));
    final delegate = pageView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 1);
  });

  testWidgets('shows horizontal stretching overscroll indicator',
      (tester) async {
    final now = DateTime.now();
    final today = _normalizeToWeekday(now);
    final weekStart = toStartOfDay(toMonday(today));
    final menus = _buildWeekMenusWithSingleDayMeal(weekStart, today);

    final provider = _FakeCanteenProvider({weekStart: menus});
    final viewModel = CanteenViewModel(provider);
    addTearDown(viewModel.dispose);
    await viewModel.loadWeek(weekStart);

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await _pumpFor(tester, const Duration(milliseconds: 700));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is StretchingOverscrollIndicator &&
            widget.axisDirection == AxisDirection.right,
      ),
      findsWidgets,
    );
  });

  testWidgets('disables implicit page prebuild on canteen pager',
      (tester) async {
    final now = DateTime.now();
    final today = _normalizeToWeekday(now);
    final weekStart = toStartOfDay(toMonday(today));
    final menus = _buildWeekMenusWithSingleDayMeal(weekStart, today);

    final provider = _FakeCanteenProvider({weekStart: menus});
    final viewModel = CanteenViewModel(provider);
    addTearDown(viewModel.dispose);
    await viewModel.loadWeek(weekStart);

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await _pumpFor(tester, const Duration(milliseconds: 700));

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.allowImplicitScrolling, isFalse);
  });

  testWidgets('does not allow paging to empty days before/after content',
      (tester) async {
    final now = DateTime.now();
    final today = _normalizeToWeekday(now);
    final weekStart = toStartOfDay(toMonday(today));
    final menus = _buildWeekMenusWithSingleDayMeal(weekStart, today);

    final provider = _FakeCanteenProvider({weekStart: menus});
    final viewModel = CanteenViewModel(provider);
    addTearDown(viewModel.dispose);
    await viewModel.loadWeek(weekStart);

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await _pumpFor(tester, const Duration(milliseconds: 700));

    expect(find.text(_mealNameFor(today)), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text(_mealNameFor(today)), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text(_mealNameFor(today)), findsOneWidget);
  });

  testWidgets('delays next week warmup until first-load settles',
      (tester) async {
    final now = DateTime.now();
    final today = _normalizeToWeekday(now);
    final weekStart = toStartOfDay(toMonday(today));
    final nextWeekStart = toStartOfDay(weekStart.add(const Duration(days: 7)));
    final menusByWeek = <DateTime, List<DailyMenu>>{
      weekStart: _buildWeekMenusWithSingleDayMeal(weekStart, today),
      nextWeekStart:
          _buildWeekMenusWithSingleDayMeal(nextWeekStart, nextWeekStart),
    };

    final provider = _FakeCanteenProvider(
      menusByWeek,
      cacheOnlyKnownWeeks: true,
    );
    final viewModel = CanteenViewModel(provider);
    addTearDown(viewModel.dispose);
    await viewModel.loadWeek(weekStart);

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await _pumpFor(tester, const Duration(milliseconds: 900));

    var pageView = tester.widget<PageView>(find.byType(PageView));
    var delegate = pageView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 1);

    await _pumpFor(tester, const Duration(milliseconds: 900));

    pageView = tester.widget<PageView>(find.byType(PageView));
    delegate = pageView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 2);
  });

  test('defers page sync while pager is transitioning or scrolling', () {
    expect(
      shouldDeferCanteenPageSync(
        hasClients: false,
        attachedPositions: 0,
        isScrolling: false,
        hasPendingPageDelta: false,
      ),
      isTrue,
    );
    expect(
      shouldDeferCanteenPageSync(
        hasClients: true,
        attachedPositions: 2,
        isScrolling: false,
        hasPendingPageDelta: false,
      ),
      isTrue,
    );
    expect(
      shouldDeferCanteenPageSync(
        hasClients: true,
        attachedPositions: 1,
        isScrolling: true,
        hasPendingPageDelta: false,
      ),
      isTrue,
    );
    expect(
      shouldDeferCanteenPageSync(
        hasClients: true,
        attachedPositions: 1,
        isScrolling: false,
        hasPendingPageDelta: true,
      ),
      isTrue,
    );
    expect(
      shouldDeferCanteenPageSync(
        hasClients: true,
        attachedPositions: 1,
        isScrolling: false,
        hasPendingPageDelta: false,
      ),
      isFalse,
    );
  });

  test('treats an uncommitted page move as pending', () {
    expect(
      hasPendingCommittedCanteenPage(
        committedPage: 0,
        currentPage: null,
      ),
      isFalse,
    );
    expect(
      hasPendingCommittedCanteenPage(
        committedPage: 0,
        currentPage: 0.2,
      ),
      isTrue,
    );
    expect(
      hasPendingCommittedCanteenPage(
        committedPage: 0,
        currentPage: 0.6,
      ),
      isTrue,
    );
    expect(
      hasPendingCommittedCanteenPage(
        committedPage: 1,
        currentPage: 1.0,
      ),
      isFalse,
    );
  });

  test('prefers the active page over the base-date fallback on first sync', () {
    final monday = DateTime(2026, 2, 9);
    final tuesday = monday.add(const Duration(days: 1));
    final wednesday = monday.add(const Duration(days: 2));

    expect(
      resolveCanteenPageSyncTarget(
        baseDate: monday,
        visibleDays: <DateTime>[monday, tuesday],
        selectedDate: null,
        currentPage: 1,
      ),
      tuesday,
    );

    expect(
      resolveCanteenPageSyncTarget(
        baseDate: monday,
        visibleDays: <DateTime>[monday, tuesday],
        selectedDate: monday,
        currentPage: 1,
      ),
      tuesday,
    );

    expect(
      resolveCanteenPageSyncTarget(
        baseDate: monday,
        visibleDays: <DateTime>[monday, tuesday, wednesday],
        selectedDate: wednesday,
        currentPage: 0,
      ),
      wednesday,
    );
  });
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 16);
  final iterations = (total.inMilliseconds / step.inMilliseconds).ceil();
  for (var i = 0; i < iterations; i++) {
    await tester.pump(step);
  }
}

Widget _wrapWithApp(CanteenViewModel viewModel) {
  return ChangeNotifierProvider<CanteenViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: Scaffold(
        body: CanteenPage(),
      ),
    ),
  );
}

List<DailyMenu> _buildWeekMenusWithSingleDayMeal(
  DateTime weekStart,
  DateTime mealDay,
) {
  return _buildWeekMenusWithMealDays(weekStart, {mealDay});
}

List<DailyMenu> _buildWeekMenusWithMealDays(
  DateTime weekStart,
  Set<DateTime> mealDays,
) {
  final normalizedMealDays = mealDays.map(toStartOfDay).toSet();
  final dailyMenus = <DailyMenu>[];

  for (var i = 0; i < 5; i++) {
    final day = toStartOfDay(weekStart.add(Duration(days: i)));
    dailyMenus.add(
      DailyMenu(
        date: day,
        meals: normalizedMealDays.contains(day) ? [_mealForDay(day)] : <Meal>[],
      ),
    );
  }

  return dailyMenus;
}

Meal _mealForDay(DateTime day) {
  return Meal(
    date: day,
    name: _mealNameFor(day),
    category: 'Wahlessen 1',
    price: 3.9,
    notes: const <String>[],
    mealTypes: const [],
  );
}

String _mealNameFor(DateTime day) {
  return 'Meal_${day.year}_${day.month}_${day.day}';
}

DateTime _normalizeToWeekday(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  if (normalized.weekday == DateTime.saturday) {
    return normalized.add(const Duration(days: 2));
  }
  if (normalized.weekday == DateTime.sunday) {
    return normalized.add(const Duration(days: 1));
  }
  return normalized;
}

class _FakeCanteenProvider extends CanteenProvider {
  final Map<DateTime, List<DailyMenu>> _menusByWeek;
  final List<CanteenMenuUpdatedCallback> _callbacks = [];
  final bool cacheOnlyKnownWeeks;
  final Set<DateTime> _cachedWeeks = <DateTime>{};

  _FakeCanteenProvider(
    this._menusByWeek, {
    this.cacheOnlyKnownWeeks = false,
  }) : super(CanteenMealRepository(_FakeDatabaseAccess()), CanteenScraper());

  @override
  void addMenuUpdatedCallback(CanteenMenuUpdatedCallback callback) {
    _callbacks.add(callback);
  }

  @override
  void removeMenuUpdatedCallback(CanteenMenuUpdatedCallback callback) {
    _callbacks.remove(callback);
  }

  @override
  Future<List<DailyMenu>> getCachedWeek(DateTime date) async {
    final weekStart = toStartOfDay(toMonday(date));
    if (cacheOnlyKnownWeeks && !_cachedWeeks.contains(weekStart)) {
      return _emptyWeek(weekStart);
    }
    return _menusForWeek(date);
  }

  @override
  Future<DateTime?> lastUpdatedForWeek(DateTime date) async {
    return null;
  }

  @override
  Future<List<DailyMenu>> refreshWeek(
    DateTime date, [
    CancellationToken? cancellationToken,
  ]) async {
    final weekStart = toStartOfDay(toMonday(date));
    final weekEnd = weekStart.add(const Duration(days: 5));
    final menus = _menusForWeek(date);
    _cachedWeeks.add(weekStart);

    for (final callback in _callbacks) {
      await callback(menus, weekStart, weekEnd);
    }

    return menus;
  }

  @override
  Future<List<DailyMenu>> refreshWeekIfStale(
    DateTime date, {
    Duration staleAfter = const Duration(hours: 2),
    CancellationToken? cancellationToken,
    bool prefetchNextWeek = true,
  }) async {
    return refreshWeek(date, cancellationToken);
  }

  List<DailyMenu> _menusForWeek(DateTime date) {
    final weekStart = toStartOfDay(toMonday(date));
    return _menusByWeek[weekStart] ?? _emptyWeek(weekStart);
  }

  List<DailyMenu> _emptyWeek(DateTime weekStart) {
    return List.generate(5, (index) {
      final date = toStartOfDay(weekStart.add(Duration(days: index)));
      return DailyMenu(date: date, meals: <Meal>[]);
    });
  }
}

class _FakeDatabaseAccess extends DatabaseAccess {
  @override
  Future<List<Map<String, dynamic>>> queryRows(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<dynamic>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset}) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
      String sql, List<dynamic> parameters) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<void> insertBatch(
      String table, List<Map<String, dynamic>> rows) async {
    return;
  }

  @override
  Future<int> deleteWhere(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    return 0;
  }
}
