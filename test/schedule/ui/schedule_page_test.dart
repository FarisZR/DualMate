import 'dart:io';
import 'dart:ui' as ui;

import 'package:dualmate/common/data/preferences/app_theme_enum.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/dualis/model/credentials.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/schedule_page.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_page.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';
import 'package:provider/provider.dart';

void main() {
  if (const bool.fromEnvironment('CAPTURE_TIMETABLE_EMPTY_STATE')) {
    setUpAll(() async {
      final fonts =
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
      final loader = FontLoader('Roboto')
        ..addFont(
          File('$fonts/Roboto-Regular.ttf')
              .readAsBytes()
              .then((bytes) => bytes.buffer.asByteData()),
        );
      await loader.load();
    });
  }
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

  for (final language in ['en', 'de']) {
    for (final theme in [AppTheme.Light, AppTheme.Dark]) {
      testWidgets(
        'no source hides a cached week and Configure opens customization ($language / $theme)',
        (tester) async {
          tester.view.physicalSize = const Size(393, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final sourceProvider = _FakeScheduleSourceProvider(
            didSetupCorrectlyValue: false,
            setupResult: false,
          );
          _registerScheduleDependencies(
            scheduleProvider: _FakeScheduleProvider([
              _entry(DateTime.now(), 'REMOVED_TIMETABLE'),
            ]),
            sourceProvider: sourceProvider,
            entryRepository: _FakeScheduleEntryRepository([]),
          );
          KiwiContainer().registerInstance<TimetableRepository>(
            _EmptyTimetables(),
          );
          final model = ScheduleViewModel(sourceProvider);
          await tester.pumpWidget(
            _wrapSchedulePage(model, locale: Locale(language), theme: theme),
          );
          await tester.pump(const Duration(milliseconds: 1100));
          await tester.pump();

          expect(find.byType(ScheduleEmptyState), findsOneWidget);
          expect(find.byType(WeeklySchedulePage), findsNothing);
          expect(find.text('REMOVED_TIMETABLE'), findsNothing);
          await tester.pumpAndSettle();
          if (const bool.fromEnvironment('CAPTURE_TIMETABLE_EMPTY_STATE')) {
            await _capture(
              tester,
              'empty-$language-${theme.name.toLowerCase()}',
            );
          }
          final l = L.of(tester.element(find.byType(ScheduleEmptyState)));
          await tester.tap(
            find.widgetWithText(
              FilledButton,
              l.scheduleEmptyStateSetUrl.toUpperCase(),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(TimetableCustomizationPage), findsOneWidget);
          expect(find.text(l.timetableAdd), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _disposeHarness(tester, model);
        },
      );
    }
  }

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

  testWidgets('does not preload the obsolete global filter list', (
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

    expect(entryRepository.queryAllNamesCallCount, 0);

    await _disposeHarness(tester, scheduleViewModel);
  });
}

class _EmptyTimetables implements TimetableRepository {
  @override
  Future<List<TimetableConfiguration>> load() async => [];
  @override
  Future<Map<String, List<String>>> moduleNames() async => {};
  @override
  PreferencesProvider get preferences => _EmptyPreferences();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyPreferences implements PreferencesProvider {
  @override
  Future<Credentials> loadDualisCredentials() async => Credentials('', '');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  Locale locale = const Locale('en'),
  AppTheme theme = AppTheme.Light,
}) {
  final child = ChangeNotifierProvider<ScheduleViewModel>.value(
    value: scheduleViewModel,
    child: MaterialApp(
      locale: locale,
      theme: ColorPalettes.buildTheme(theme),
      builder: (_, child) => RepaintBoundary(
        key: const ValueKey('schedule_test_capture'),
        child: child!,
      ),
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: Scaffold(body: SchedulePage()),
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

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('schedule_test_capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('screenshots/timetable-empty-state')
        ..createSync(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
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
