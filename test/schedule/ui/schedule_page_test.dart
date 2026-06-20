import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/schedule_page.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    KiwiContainer().clear();
    FilterViewModel.resetCachedStateForTesting();
    SchedulePage.resetSharedState();
  });

  tearDown(() {
    SchedulePage.resetSharedState();
    FilterViewModel.resetCachedStateForTesting();
    KiwiContainer().clear();
  });

  testWidgets('renders weekly schedule directly without pager shell', (
    tester,
  ) async {
    final sourceProvider = _FakeScheduleSourceProvider();
    _registerScheduleDependencies(
      scheduleProvider: _FakeScheduleProvider(<ScheduleEntry>[
        _entry(DateTime(2026, 3, 9), 'CURRENT_WEEK'),
      ]),
      sourceProvider: sourceProvider,
    );

    final scheduleViewModel = ScheduleViewModel(sourceProvider);

    await tester.pumpWidget(_wrapSchedulePage(scheduleViewModel));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(WeeklySchedulePage), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);

    await _disposeHarness(tester, scheduleViewModel);
  });

  testWidgets('shows no-source UI without weekly page or bottom navigation', (
    tester,
  ) async {
    final sourceProvider = _FakeScheduleSourceProvider(
      didSetupCorrectlyValue: false,
      setupResult: false,
    );
    _registerScheduleDependencies(
      scheduleProvider: _ThrowingCachedScheduleProvider(),
      sourceProvider: sourceProvider,
    );

    final scheduleViewModel = ScheduleViewModel(sourceProvider);

    await tester.pumpWidget(_wrapSchedulePage(scheduleViewModel));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1050));
    await tester.idle();
    await tester.pump();

    expect(find.byType(ScheduleEmptyState), findsOneWidget);
    expect(find.byType(WeeklySchedulePage), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);

    await _disposeHarness(tester, scheduleViewModel);
  });

  testWidgets('shows weekly error UI when first load fails without cache', (
    tester,
  ) async {
    final sourceProvider = _FakeScheduleSourceProvider();
    _registerScheduleDependencies(
      scheduleProvider: _ThrowingCachedScheduleProvider(),
      sourceProvider: sourceProvider,
    );

    final scheduleViewModel = ScheduleViewModel(sourceProvider);

    await tester.pumpWidget(_wrapSchedulePage(scheduleViewModel));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.byType(WeeklySchedulePage), findsOneWidget);
    expect(find.text('No connection!'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('weekly_schedule_loading_line')),
      findsNothing,
    );

    await _disposeHarness(tester, scheduleViewModel);
  });

  testWidgets('defers weekly initialization while schedule tab is hidden', (
    tester,
  ) async {
    final sourceProvider = _FakeScheduleSourceProvider();
    final scheduleProvider = _FakeScheduleProvider(<ScheduleEntry>[
      _entry(DateTime(2026, 3, 9), 'CURRENT_WEEK'),
    ]);
    _registerScheduleDependencies(
      scheduleProvider: scheduleProvider,
      sourceProvider: sourceProvider,
    );

    final scheduleViewModel = ScheduleViewModel(sourceProvider);
    final currentEntryIndex = ValueNotifier<int>(1);

    await tester.pumpWidget(
      _wrapSchedulePage(
        scheduleViewModel,
        currentEntryIndex: currentEntryIndex,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.idle();

    expect(scheduleProvider.cachedRequests, 0);

    currentEntryIndex.value = 0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.idle();

    expect(scheduleProvider.cachedRequests, greaterThan(0));

    await _disposeHarness(tester, scheduleViewModel);
    currentEntryIndex.dispose();
  });

  testWidgets('deferred filter warmup uses cached dependencies', (
    tester,
  ) async {
    final sourceProvider = _FakeScheduleSourceProvider();
    final entryRepository = _FakeScheduleEntryRepository(['CURRENT_WEEK']);
    final filterRepository = _FakeScheduleFilterRepository([]);
    _registerScheduleDependencies(
      scheduleProvider: _FakeScheduleProvider(<ScheduleEntry>[
        _entry(DateTime(2026, 3, 9), 'CURRENT_WEEK'),
      ]),
      sourceProvider: sourceProvider,
      entryRepository: entryRepository,
      filterRepository: filterRepository,
    );

    final scheduleViewModel = ScheduleViewModel(sourceProvider);

    await tester.pumpWidget(_wrapSchedulePage(scheduleViewModel));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.idle();

    expect(entryRepository.queryAllNamesCallCount, 1);

    await _disposeHarness(tester, scheduleViewModel);
  });
}

void _registerScheduleDependencies({
  required ScheduleProvider scheduleProvider,
  required ScheduleSourceProvider sourceProvider,
  ScheduleEntryRepository? entryRepository,
  ScheduleFilterRepository? filterRepository,
}) {
  final container = KiwiContainer();
  container.registerInstance<ScheduleProvider>(scheduleProvider);
  container.registerInstance<ScheduleSourceProvider>(sourceProvider);
  if (entryRepository != null) {
    container.registerInstance<ScheduleEntryRepository>(entryRepository);
  }
  if (filterRepository != null) {
    container.registerInstance<ScheduleFilterRepository>(filterRepository);
  }
}

Widget _wrapSchedulePage(
  ScheduleViewModel scheduleViewModel, {
  ValueNotifier<int>? currentEntryIndex,
}) {
  final child = ChangeNotifierProvider<ScheduleViewModel>.value(
    value: scheduleViewModel,
    child: MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: SchedulePage(),
    ),
  );
  if (currentEntryIndex == null) {
    return child;
  }
  return ChangeNotifierProvider<ValueNotifier<int>>.value(
    value: currentEntryIndex,
    child: child,
  );
}

Future<void> _disposeHarness(
  WidgetTester tester,
  ScheduleViewModel scheduleViewModel,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  SchedulePage.resetSharedState();
  await tester.pump();
  scheduleViewModel.dispose();
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

class _FakeScheduleProvider implements ScheduleProvider {
  final List<ScheduleEntry> _entries;
  int cachedRequests = 0;

  _FakeScheduleProvider(this._entries);

  @override
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
    cachedRequests += 1;
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

class _ThrowingCachedScheduleProvider extends _FakeScheduleProvider {
  _ThrowingCachedScheduleProvider() : super(const <ScheduleEntry>[]);

  @override
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
    throw Exception('cache read failed');
  }
}

class _FakeScheduleEntryRepository implements ScheduleEntryRepository {
  final List<String> names;
  int queryAllNamesCallCount = 0;

  _FakeScheduleEntryRepository(this.names);

  @override
  Future<List<String>> queryAllNamesOfScheduleEntries() async {
    queryAllNamesCallCount += 1;
    final sortedNames = List<String>.from(names)..sort();
    return sortedNames;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleEntryRepository call: $invocation',
    );
  }
}

class _FakeScheduleFilterRepository implements ScheduleFilterRepository {
  final List<String> hiddenNames;

  _FakeScheduleFilterRepository(this.hiddenNames);

  @override
  Future<List<String>> queryAllHiddenNames() async {
    return List<String>.from(hiddenNames);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleFilterRepository call: $invocation',
    );
  }
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source;
  final bool didSetupCorrectlyValue;
  final bool setupResult;

  _FakeScheduleSourceProvider({
    this.didSetupCorrectlyValue = true,
    this.setupResult = true,
    bool canQuery = true,
  }) : _source = _FakeScheduleSource(canQuery: canQuery);

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  bool didSetupCorrectly() => didSetupCorrectlyValue;

  @override
  Future<bool> setupScheduleSource() async {
    return setupResult;
  }

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
  final bool _canQuery;

  _FakeScheduleSource({bool canQuery = true}) : _canQuery = canQuery;

  @override
  bool canQuery() => _canQuery;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    return ScheduleQueryResult(Schedule(), const []);
  }
}
