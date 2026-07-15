import 'dart:async';

import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/date_management/business/date_entry_provider.dart';
import 'package:dualmate/date_management/business/rapla_important_events_provider.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/model/date_search_parameters.dart';
import 'package:dualmate/date_management/ui/date_management_page.dart';
import 'package:dualmate/date_management/ui/viewmodels/date_management_view_model.dart';
import 'package:dualmate/date_management/ui/widgets/dates_empty_state.dart';
import 'package:dualmate/date_management/ui/widgets/dates_agenda_row.dart';
import 'package:dualmate/date_management/ui/widgets/important_event_section_heading.dart';
import 'package:dualmate/date_management/service/date_management_service.dart';
import 'package:dualmate/date_management/data/date_entry_repository.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows empty state when rapla and DHmine unconfigured', (
    WidgetTester tester,
  ) async {
    final viewModel = _buildViewModel(useDhMineForDates: false, raplaUrl: '');

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pumpAndSettle();

    expect(find.byType(DatesEmptyState), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets('uses list layout on tablets', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final viewModel = _buildViewModel(
      useDhMineForDates: false,
      raplaUrl: 'https://rapla.dhbw-stuttgart.de/rapla?key=abc',
      importantEvents: _sampleEvents(),
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsWidgets);
    final raplaList = tester.widget<ListView>(
      find.byKey(const Key('rapla_dates_list')),
    );
    expect(
      raplaList.padding,
      const EdgeInsets.symmetric(horizontal: 180, vertical: 12),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets('pull to refresh triggers updateDates in rapla mode', (
    WidgetTester tester,
  ) async {
    final viewModel = _buildViewModel(
      useDhMineForDates: false,
      raplaUrl: 'https://rapla.dhbw-stuttgart.de/rapla?key=abc',
      importantEvents: _sampleEvents(),
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);

    final before = viewModel.updateDatesCalls;
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 250));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(viewModel.updateDatesCalls, greaterThan(before));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets('pull to refresh triggers updateDates in DHmine mode', (
    WidgetTester tester,
  ) async {
    final viewModel = _buildViewModel(
      useDhMineForDates: true,
      raplaUrl: '',
      importantEvents: const [],
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);

    final before = viewModel.updateDatesCalls;
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 250));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(viewModel.updateDatesCalls, greaterThan(before));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets('defers dates initialization to keep first drawer open smooth', (
    WidgetTester tester,
  ) async {
    final viewModel = _buildViewModel(
      useDhMineForDates: false,
      raplaUrl: 'https://rapla.dhbw-stuttgart.de/rapla?key=abc',
      importantEvents: _sampleEvents(),
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump();

    expect(viewModel.initializeCalls, 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(viewModel.initializeCalls, 0);

    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(viewModel.initializeCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets('lazily constructs flattened Rapla rows', (
    WidgetTester tester,
  ) async {
    final events = List<ImportantEvent>.generate(
      80,
      (index) => ImportantEvent(
        title: 'Rapla event $index',
        start: DateTime(2026, 8, 1).add(Duration(days: index)),
        end: DateTime(2026, 8, 1, 1).add(Duration(days: index)),
        type: ScheduleEntryType.PublicHoliday,
      ),
    );
    final viewModel = _buildViewModel(
      useDhMineForDates: false,
      raplaUrl: 'https://rapla.dhbw-stuttgart.de/rapla?key=abc',
      importantEvents: events,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rapla_dates_list')), findsOneWidget);
    expect(find.text('Rapla event 0'), findsOneWidget);
    expect(find.text('Rapla event 79'), findsNothing);
    expect(
      find.byType(ImportantEventAgendaRow).evaluate().length,
      lessThan(events.length),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets(
    'renders exam weeks as a heading followed by independent agenda rows',
    (WidgetTester tester) async {
      final viewModel = _buildViewModel(
        useDhMineForDates: false,
        raplaUrl: 'https://rapla.dhbw-stuttgart.de/rapla?key=abc',
        importantEvents: [
          ImportantEvent(
            title: 'Klausurwoche',
            start: DateTime(2026, 8, 10),
            end: DateTime(2026, 8, 14),
            type: ScheduleEntryType.SpecialEvent,
          ),
          ImportantEvent(
            title: 'Exam 1',
            start: DateTime(2026, 8, 11, 8),
            end: DateTime(2026, 8, 11, 10),
            type: ScheduleEntryType.Exam,
          ),
          ImportantEvent(
            title: 'Exam 2',
            start: DateTime(2026, 8, 12, 8),
            end: DateTime(2026, 8, 12, 10),
            type: ScheduleEntryType.Exam,
          ),
          ImportantEvent(
            title: 'Exam 3',
            start: DateTime(2026, 8, 13, 8),
            end: DateTime(2026, 8, 13, 10),
            type: ScheduleEntryType.Exam,
          ),
          ImportantEvent(
            title: 'Exam 4',
            start: DateTime(2026, 8, 14, 8),
            end: DateTime(2026, 8, 14, 10),
            type: ScheduleEntryType.Exam,
          ),
        ],
      );

      await tester.pumpWidget(_wrapWithApp(viewModel));
      await tester.pump(const Duration(milliseconds: 420));
      await tester.pumpAndSettle();

      expect(find.byType(ImportantEventSectionHeading), findsOneWidget);
      expect(find.byType(ImportantEventAgendaRow), findsNWidgets(4));
      expect(find.text('Klausurwoche'), findsOneWidget);
      expect(find.text('Exam 1'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      viewModel.dispose();
    },
  );

  testWidgets('uses lazy fixed-width DH-Mine rows for long data', (
    WidgetTester tester,
  ) async {
    final entries = List<DateEntry>.generate(
      100,
      (index) => DateEntry(
        description: 'DH-Mine date $index with a long description',
        year: '2026',
        comment: '',
        databaseName: 'Termine_Horb_INF',
        start: DateTime(2026, 8, 1, 8).add(Duration(days: index)),
        end: DateTime(2026, 8, 1, 10).add(Duration(days: index)),
        room: '',
      ),
    );
    final viewModel = _buildViewModel(
      useDhMineForDates: true,
      raplaUrl: '',
      dateEntries: entries,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dhmine_dates_list')), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('DH-Mine date 99 with a long description'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('DH-Mine date 99 with a long description'),
      500,
      scrollable: find.descendant(
        of: find.byKey(const Key('dhmine_dates_list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.text('DH-Mine date 99 with a long description'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });

  testWidgets(
    'keeps loading indicator through the loading-to-content transition',
    (WidgetTester tester) async {
      final loading = Completer<void>();
      final viewModel = _buildViewModel(
        useDhMineForDates: false,
        raplaUrl: 'https://rapla.dhbw-stuttgart.de/rapla?key=abc',
        importantEvents: _sampleEvents(),
        raplaLoading: loading.future,
      );
      final tickerEnabled = ValueNotifier<bool>(false);
      addTearDown(tickerEnabled.dispose);

      await tester.pumpWidget(
        _wrapWithApp(viewModel, tickerEnabledNotifier: tickerEnabled),
      );
      await tester.pump(const Duration(milliseconds: 420));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Exam A'), findsNothing);

      loading.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));

      expect(find.text('Exam A'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      tickerEnabled.value = true;
      await tester.pump();
      expect(find.text('Exam A'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      viewModel.dispose();
    },
  );

  testWidgets('keeps Rapla scroll position correct while constructing rows', (
    WidgetTester tester,
  ) async {
    final events = List<ImportantEvent>.generate(
      60,
      (index) => ImportantEvent(
        title: 'Scrollable event $index',
        start: DateTime(2026, 8, 1).add(Duration(days: index)),
        end: DateTime(2026, 8, 1, 1).add(Duration(days: index)),
        type: ScheduleEntryType.PublicHoliday,
      ),
    );
    final viewModel = _buildViewModel(
      useDhMineForDates: false,
      raplaUrl: 'https://rapla.dhbw-stuttgart.de/rapla?key=abc',
      importantEvents: events,
    );

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Scrollable event 59'),
      500,
      scrollable: find.descendant(
        of: find.byKey(const Key('rapla_dates_list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Scrollable event 59'), findsOneWidget);
    expect(find.text('Scrollable event 0'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    viewModel.dispose();
  });
}

Widget _wrapWithApp(
  DateManagementViewModel viewModel, {
  bool tickerEnabled = true,
  ValueListenable<bool>? tickerEnabledNotifier,
}) {
  final page = DateManagementPage();
  final body = tickerEnabledNotifier == null
      ? TickerMode(enabled: tickerEnabled, child: page)
      : ValueListenableBuilder<bool>(
          valueListenable: tickerEnabledNotifier,
          child: page,
          builder: (context, enabled, child) {
            return TickerMode(enabled: enabled, child: child!);
          },
        );
  return ChangeNotifierProvider<DateManagementViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: Scaffold(body: body),
    ),
  );
}

_TrackingDateManagementViewModel _buildViewModel({
  required bool useDhMineForDates,
  required String raplaUrl,
  List<ImportantEvent> importantEvents = const [],
  List<DateEntry> dateEntries = const [],
  Future<void>? raplaLoading,
}) {
  final preferencesAccess = _FakePreferencesAccess({
    PreferencesProvider.UseDhMineForDates: useDhMineForDates,
    PreferencesProvider.RaplaUrlKey: raplaUrl,
    PreferencesProvider.LastViewedDateEntryDatabase: '',
    PreferencesProvider.LastViewedDateEntryYear: DateTime.now().year.toString(),
  });
  final preferencesProvider = PreferencesProvider(
    preferencesAccess,
    _FakeSecureStorageAccess(),
  );

  final dateEntryProvider = _FakeDateEntryProvider(dateEntries);
  final raplaProvider = _FakeRaplaImportantEventsProvider(
    preferencesProvider,
    importantEvents,
    raplaLoading,
  );

  return _TrackingDateManagementViewModel(
    dateEntryProvider,
    preferencesProvider,
    raplaProvider,
  );
}

class _TrackingDateManagementViewModel extends DateManagementViewModel {
  int initializeCalls = 0;
  int updateDatesCalls = 0;

  _TrackingDateManagementViewModel(
    DateEntryProvider dateEntryProvider,
    PreferencesProvider preferencesProvider,
    RaplaImportantEventsProvider raplaImportantEventsProvider,
  ) : super(
        dateEntryProvider,
        preferencesProvider,
        raplaImportantEventsProvider,
      );

  @override
  void initialize() {
    initializeCalls += 1;
    super.initialize();
  }

  @override
  Future<void> updateDates() async {
    updateDatesCalls += 1;
    return super.updateDates();
  }
}

List<ImportantEvent> _sampleEvents() {
  final now = DateTime.now();
  return [
    ImportantEvent(
      title: 'Exam A',
      start: now.add(const Duration(days: 1)),
      end: now.add(const Duration(days: 1, hours: 2)),
      type: ScheduleEntryType.Exam,
    ),
    ImportantEvent(
      title: 'Holiday',
      start: now.add(const Duration(days: 3)),
      end: now.add(const Duration(days: 3, hours: 1)),
      type: ScheduleEntryType.PublicHoliday,
    ),
  ];
}

class _FakePreferencesAccess extends PreferencesAccess {
  final Map<String, Object?> _store;

  _FakePreferencesAccess(this._store);

  @override
  Future<void> set<T>(String key, T value) async {
    _store[key] = value;
  }

  @override
  Future<T?> get<T>(String key) async {
    return _store[key] as T?;
  }
}

class _FakeSecureStorageAccess extends SecureStorageAccess {
  final Map<String, String?> _store = {};

  @override
  Future<void> set(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> get(String key) async {
    return _store[key];
  }
}

class _FakeDateEntryProvider extends DateEntryProvider {
  final List<DateEntry> _entries;

  _FakeDateEntryProvider(this._entries)
    : super(_FakeDateManagementService(), _FakeDateEntryRepository());

  @override
  Future<List<DateEntry>> getCachedDateEntries(
    DateSearchParameters parameters,
  ) async {
    return _entries;
  }

  @override
  Future<List<DateEntry>> getDateEntries(
    DateSearchParameters parameters,
    CancellationToken cancellationToken,
  ) async {
    return _entries;
  }
}

class _FakeDateManagementService extends DateManagementService {
  @override
  Future<List<DateEntry>> queryAllDates(
    DateSearchParameters parameters,
    CancellationToken cancellationToken,
  ) async {
    return <DateEntry>[];
  }
}

class _FakeDateEntryRepository extends DateEntryRepository {
  _FakeDateEntryRepository() : super(_FakeDatabaseAccess());
}

class _FakeRaplaImportantEventsProvider extends RaplaImportantEventsProvider {
  final List<ImportantEvent> _events;
  final Future<void>? _loading;

  _FakeRaplaImportantEventsProvider(
    PreferencesProvider preferencesProvider,
    this._events,
    this._loading,
  ) : super(
        preferencesProvider,
        _FakeScheduleProvider(preferencesProvider),
        _FakeScheduleSourceProvider(preferencesProvider),
      );

  @override
  Future<List<ImportantEvent>> getCachedImportantEvents(
    DateTime start,
    DateTime end,
  ) async {
    if (_loading != null) {
      await _loading;
    }
    return _events;
  }

  @override
  Future<ScheduleQueryResult?> refreshImportantEvents(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken,
  ) async {
    return null;
  }
}

class _FakeScheduleProvider extends ScheduleProvider {
  _FakeScheduleProvider(PreferencesProvider preferencesProvider)
    : super(
        _FakeScheduleSourceProvider(preferencesProvider),
        _FakeScheduleEntryRepository(),
        _FakeScheduleQueryInformationRepository(),
        preferencesProvider,
        _FakeScheduleFilterRepository(),
      );

  @override
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
    return Schedule();
  }

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    return ScheduleQueryResult(Schedule(), <ParseError>[]);
  }
}

class _FakeScheduleSourceProvider extends ScheduleSourceProvider {
  _FakeScheduleSourceProvider(PreferencesProvider preferencesProvider)
    : super(
        preferencesProvider,
        false,
        _FakeScheduleEntryRepository(),
        _FakeScheduleQueryInformationRepository(),
      );

  @override
  Future<bool> setupScheduleSource() async {
    return true;
  }

  @override
  bool didSetupCorrectly() => true;
}

class _FakeScheduleEntryRepository extends ScheduleEntryRepository {
  _FakeScheduleEntryRepository() : super(_FakeDatabaseAccess());
}

class _FakeScheduleFilterRepository extends ScheduleFilterRepository {
  _FakeScheduleFilterRepository() : super(_FakeDatabaseAccess());
}

class _FakeScheduleQueryInformationRepository
    extends ScheduleQueryInformationRepository {
  _FakeScheduleQueryInformationRepository() : super(_FakeDatabaseAccess());
}

class _FakeDatabaseAccess extends DatabaseAccess {
  @override
  Future<int> insert(String table, Map<String, dynamic> row) async {
    return 0;
  }

  @override
  Future<List<Map<String, dynamic>>> queryRows(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql,
    List<dynamic> parameters,
  ) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<int> queryAggregator(String query, List<dynamic> arguments) async {
    return 0;
  }

  @override
  Future<int> update(String table, Map<String, dynamic> row) async {
    return 0;
  }

  @override
  Future<int> delete(String table, int id) async {
    return 0;
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
