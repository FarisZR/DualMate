import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('does not prefetch adjacent weeks before user interaction', (
    tester,
  ) async {
    final provider = _TrackingScheduleProvider(<ScheduleEntry>[]);
    final sourceProvider = _FakeScheduleSourceProvider();
    final viewModel = _SpyWeeklyScheduleViewModel(
      provider,
      sourceProvider,
      nowProvider: () => DateTime(2026, 2, 10, 10),
    );
    await viewModel.updateSchedule(
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 16),
      force: true,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(viewModel.prefetchRequests, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets('animates hour viewport transitions instead of hard jumps', (
    tester,
  ) async {
    final viewModel = _buildViewModel(
      now: DateTime(2026, 2, 10, 10),
      entries: <ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), 'CURRENT_WEEK'),
      ],
    );
    await viewModel.updateSchedule(
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 16),
      force: true,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    final hourLabel = find.text('9:00').first;
    final before = tester.getTopLeft(hourLabel).dy;

    viewModel.displayEndHour = 21;
    viewModel.notifyListeners('weekSchedule');

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final during = tester.getTopLeft(hourLabel).dy;

    await tester.pumpAndSettle();
    final after = tester.getTopLeft(hourLabel).dy;

    expect(after, lessThan(before - 0.5));
    expect(during, lessThan(before - 0.5));
    expect(during, greaterThan(after + 0.5));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets('dragging weekly pager updates page progress before release', (
    tester,
  ) async {
    final viewModel = _buildViewModel(
      now: DateTime(2026, 2, 10, 10),
      entries: <ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), 'CURRENT_WEEK'),
        _entry(DateTime(2026, 2, 16), 'NEXT_WEEK'),
      ],
    );
    await viewModel.updateSchedule(
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 16),
      force: true,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    final pagerFinder = find.byKey(
      const ValueKey<String>('weekly_schedule_page_view'),
    );
    expect(pagerFinder, findsOneWidget);

    final pageView = tester.widget<PageView>(pagerFinder);
    final controller = pageView.controller!;
    expect(pageView.allowImplicitScrolling, isFalse);
    expect(controller.page, closeTo(10000.0, 0.001));
    expect(
      find.byKey(const ValueKey<String>('weekly_fixed_hour_axis')),
      findsOneWidget,
    );
    final fixedAxisHourLabel = find.text('7:00').first;
    final fixedAxisPositionBeforeDrag = tester.getTopLeft(fixedAxisHourLabel);

    final gesture = await tester.startGesture(tester.getCenter(pagerFinder));
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();

    final draggedPage = controller.page ?? 10000.0;
    expect(draggedPage, greaterThan(10000.05));
    expect(draggedPage, lessThan(10001.0));
    final fixedAxisPositionAfterDrag = tester.getTopLeft(fixedAxisHourLabel);
    expect(
      fixedAxisPositionAfterDrag.dx,
      closeTo(fixedAxisPositionBeforeDrag.dx, 0.001),
    );

    await gesture.up();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets('swipe and chevron commit week changes through pager flow', (
    tester,
  ) async {
    final viewModel = _buildViewModel(
      now: DateTime(2026, 2, 10, 10),
      entries: <ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), 'CURRENT_WEEK'),
        _entry(DateTime(2026, 2, 16), 'NEXT_WEEK'),
      ],
    );
    await viewModel.updateSchedule(
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 16),
      force: true,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    final pagerFinder = find.byKey(
      const ValueKey<String>('weekly_schedule_page_view'),
    );

    await tester.fling(pagerFinder, const Offset(-420, 0), 1400);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 80));

    expect(viewModel.currentDateStart, DateTime(2026, 2, 16));
    expect(find.text('NEXT_WEEK'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 80));

    expect(viewModel.currentDateStart, DateTime(2026, 2, 9));
    expect(find.text('CURRENT_WEEK'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets(
      'current week button stays hidden on current week and appears away', (
    tester,
  ) async {
    final viewModel = _buildViewModel(
      now: DateTime(2026, 2, 10, 10),
      entries: <ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), 'CURRENT_WEEK'),
        _entry(DateTime(2026, 2, 16), 'NEXT_WEEK'),
      ],
    );
    await viewModel.updateSchedule(
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 16),
      force: true,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    final currentWeekButton = find.byKey(
      const ValueKey<String>('weekly_current_week_button'),
    );
    expect(currentWeekButton, findsNothing);

    final pagerFinder = find.byKey(
      const ValueKey<String>('weekly_schedule_page_view'),
    );
    await tester.fling(pagerFinder, const Offset(-420, 0), 1400);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 80));

    expect(viewModel.currentDateStart, DateTime(2026, 2, 16));
    expect(currentWeekButton, findsOneWidget);
    expect(
      find.descendant(
        of: currentWeekButton,
        matching: find.byIcon(Icons.arrow_back_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: currentWeekButton,
        matching: find.byIcon(Icons.arrow_forward_rounded),
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets('current week button points right when browsing past weeks', (
    tester,
  ) async {
    final viewModel = _buildViewModel(
      now: DateTime(2026, 2, 10, 10),
      entries: <ScheduleEntry>[
        _entry(DateTime(2026, 2, 2), 'PAST_WEEK'),
        _entry(DateTime(2026, 2, 9), 'CURRENT_WEEK'),
      ],
    );
    await viewModel.updateSchedule(
      DateTime(2026, 2, 2),
      DateTime(2026, 2, 16),
      force: true,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    expect(viewModel.currentDateStart, DateTime(2026, 2, 2));
    expect(
      find.byKey(const ValueKey<String>('weekly_current_week_button')),
      findsOneWidget,
    );
    final currentWeekButton = find.byKey(
      const ValueKey<String>('weekly_current_week_button'),
    );
    expect(
      find.descendant(
        of: currentWeekButton,
        matching: find.byIcon(Icons.arrow_forward_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: currentWeekButton,
        matching: find.byIcon(Icons.arrow_back_rounded),
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets('current week button returns to today week from distant page', (
    tester,
  ) async {
    final viewModel = _buildViewModel(
      now: DateTime(2026, 2, 10, 10),
      entries: <ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), 'CURRENT_WEEK'),
        _entry(DateTime(2026, 2, 23), 'FAR_WEEK'),
      ],
    );
    await viewModel.updateSchedule(
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 16),
      force: true,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    await tester.fling(
      find.byKey(const ValueKey<String>('weekly_schedule_page_view')),
      const Offset(-900, 0),
      1800,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 80));

    expect(viewModel.currentDateStart, DateTime(2026, 2, 23));
    expect(find.text('FAR_WEEK'), findsOneWidget);
    final currentWeekButton = find.byKey(
      const ValueKey<String>('weekly_current_week_button'),
    );
    expect(currentWeekButton, findsOneWidget);

    await tester.tap(currentWeekButton);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 80));

    expect(viewModel.currentDateStart, DateTime(2026, 2, 9));
    expect(find.text('CURRENT_WEEK'), findsOneWidget);
    expect(currentWeekButton, findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });
}

WeeklyScheduleViewModel _buildViewModel({
  required DateTime now,
  required List<ScheduleEntry> entries,
}) {
  final provider = _TrackingScheduleProvider(entries);
  final sourceProvider = _FakeScheduleSourceProvider();
  final viewModel = WeeklyScheduleViewModel(
    provider,
    sourceProvider,
    nowProvider: () => now,
  );
  return viewModel;
}

Widget _wrapWithApp(WeeklyScheduleViewModel viewModel) {
  return ChangeNotifierProvider<WeeklyScheduleViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: const Scaffold(
        body: WeeklySchedulePage(),
      ),
    ),
  );
}

ScheduleEntry _entry(DateTime day, String title) {
  return ScheduleEntry(
    start: DateTime(day.year, day.month, day.day, 9),
    end: DateTime(day.year, day.month, day.day, 10),
    title: title,
    details: 'Lecture',
    professor: 'Prof',
    room: 'R1',
    type: ScheduleEntryType.Class,
  );
}

class _TrackingScheduleProvider implements ScheduleProvider {
  final List<ScheduleEntry> _entries;

  _TrackingScheduleProvider(this._entries);

  @override
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
    final entries = _entries.where((entry) {
      return start.isBefore(entry.end) && end.isAfter(entry.start);
    }).toList();
    return Schedule.fromList(entries);
  }

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    return ScheduleQueryResult(await getCachedSchedule(start, end), const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source = _FakeScheduleSource();

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  bool didSetupCorrectly() => true;

  @override
  void addDidChangeScheduleSourceCallback(OnDidChangeScheduleSource callback) {}

  @override
  void removeDidChangeScheduleSourceCallback(
    OnDidChangeScheduleSource callback,
  ) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleSourceProvider call: $invocation',
    );
  }
}

class _FakeScheduleSource implements ScheduleSource {
  @override
  bool canQuery() => true;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    return ScheduleQueryResult(Schedule(), const []);
  }
}

class _SpyWeeklyScheduleViewModel extends WeeklyScheduleViewModel {
  final List<_RangeRequest> prefetchRequests = <_RangeRequest>[];

  _SpyWeeklyScheduleViewModel(
    super.scheduleProvider,
    super.scheduleSourceProvider, {
    required super.nowProvider,
  });

  @override
  Future<void> prefetchWeek(DateTime start, DateTime end) async {
    prefetchRequests.add(_RangeRequest(start, end));
    await super.prefetchWeek(start, end);
  }
}

class _RangeRequest {
  final DateTime start;
  final DateTime end;

  _RangeRequest(this.start, this.end);
}
