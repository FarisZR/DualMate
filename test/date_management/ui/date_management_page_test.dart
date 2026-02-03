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
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows empty state when rapla and DHmine unconfigured',
      (WidgetTester tester) async {
    final viewModel = _buildViewModel(
      useDhMineForDates: false,
      raplaUrl: '',
    );
    addTearDown(viewModel.dispose);

    await viewModel.reloadUseDhMineSetting();

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pumpAndSettle();

    expect(find.byType(DatesEmptyState), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('uses list layout on tablets',
      (WidgetTester tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = const Size(1200, 800);
    binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(binding.window.clearPhysicalSizeTestValue);
    addTearDown(binding.window.clearDevicePixelRatioTestValue);

    final viewModel = _buildViewModel(
      useDhMineForDates: false,
      raplaUrl: 'https://rapla.dhbw-stuttgart.de/rapla?key=abc',
      importantEvents: _sampleEvents(),
    );
    addTearDown(viewModel.dispose);

    await viewModel.reloadUseDhMineSetting();

    await tester.pumpWidget(_wrapWithApp(viewModel));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsWidgets);
  });
}

Widget _wrapWithApp(DateManagementViewModel viewModel) {
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
      home: Scaffold(
        body: DateManagementPage(),
      ),
    ),
  );
}

DateManagementViewModel _buildViewModel({
  required bool useDhMineForDates,
  required String raplaUrl,
  List<ImportantEvent> importantEvents = const [],
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

  final dateEntryProvider = _FakeDateEntryProvider();
  final raplaProvider = _FakeRaplaImportantEventsProvider(
    preferencesProvider,
    importantEvents,
  );

  return DateManagementViewModel(
    dateEntryProvider,
    preferencesProvider,
    raplaProvider,
  );
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
  _FakeDateEntryProvider() : super(_FakeDateManagementService(), _FakeDateEntryRepository());

  @override
  Future<List<DateEntry>> getCachedDateEntries(DateSearchParameters parameters) async {
    return <DateEntry>[];
  }

  @override
  Future<List<DateEntry>> getDateEntries(
    DateSearchParameters parameters,
    CancellationToken cancellationToken,
  ) async {
    return <DateEntry>[];
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

  _FakeRaplaImportantEventsProvider(
    PreferencesProvider preferencesProvider,
    this._events,
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
    CancellationToken cancellationToken,
  ) async {
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
