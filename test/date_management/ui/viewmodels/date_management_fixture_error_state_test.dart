import 'package:dualmate/common/appstart/performance_fixture_mode.dart';
import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/date_management/business/date_entry_provider.dart';
import 'package:dualmate/date_management/business/rapla_important_events_provider.dart';
import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/model/date_search_parameters.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/service/date_management_service.dart';
import 'package:dualmate/date_management/data/date_entry_repository.dart';
import 'package:dualmate/date_management/ui/viewmodels/date_management_view_model.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fixture mode: successful cached DhMine load does not show error state',
    () async {
      // Issue 9: Fixture mode intentionally skips the remote fetch by assigning
      // null. The VM must not interpret that as a failure. Run with
      // --dart-define=PERF_TEST_OFFLINE_FIXTURES=true.
      if (!isPerformanceFixtureMode) {
        return;
      }

      final preferences = PreferencesProvider(
        _FakePreferencesAccess({
          PreferencesProvider.UseDhMineForDates: true,
          PreferencesProvider.RaplaUrlKey: '',
          PreferencesProvider.LastViewedDateEntryDatabase: '',
          PreferencesProvider.LastViewedDateEntryYear:
              DateTime.now().year.toString(),
        }),
        _FakeSecureStorageAccess(),
      );

      final dateEntryProvider = _ThrowingDateEntryProvider();
      final raplaProvider = _StubRaplaProvider(preferences);

      final viewModel = DateManagementViewModel(
        dateEntryProvider,
        preferences,
        raplaProvider,
      );
      addTearDown(viewModel.dispose);

      viewModel.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(viewModel.updateFailed, isFalse,
          reason: 'Fixture mode must not report an error when the remote '
              'fetch is intentionally skipped.');
    },
  );
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

class _ThrowingDateEntryProvider extends DateEntryProvider {
  _ThrowingDateEntryProvider()
      : super(_StubDateManagementService(), _StubDateEntryRepository());

  @override
  Future<List<DateEntry>> getCachedDateEntries(
    DateSearchParameters parameters,
  ) async {
    return <DateEntry>[];
  }

  @override
  Future<List<DateEntry>> getDateEntries(
    DateSearchParameters parameters,
    CancellationToken cancellationToken,
  ) async {
    throw ServiceRequestFailed('simulated network failure');
  }
}

class _StubDateManagementService extends DateManagementService {
  @override
  Future<List<DateEntry>> queryAllDates(
    DateSearchParameters parameters,
    CancellationToken cancellationToken,
  ) async => <DateEntry>[];
}

class _StubDateEntryRepository extends DateEntryRepository {
  _StubDateEntryRepository() : super(_StubDatabaseAccess());
}

class _StubRaplaProvider extends RaplaImportantEventsProvider {
  _StubRaplaProvider(PreferencesProvider preferences)
      : super(
          preferences,
          _StubScheduleProvider(preferences),
          _StubScheduleSourceProvider(preferences),
        );

  @override
  Future<List<ImportantEvent>> getCachedImportantEvents(
    DateTime start,
    DateTime end,
  ) async => <ImportantEvent>[];

  @override
  Future<ScheduleQueryResult?> refreshImportantEvents(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken,
  ) async => null;
}

class _StubScheduleProvider extends ScheduleProvider {
  _StubScheduleProvider(PreferencesProvider preferences)
      : super(
          _StubScheduleSourceProvider(preferences),
          _StubScheduleEntryRepository(),
          _StubScheduleQueryInfoRepository(),
          preferences,
          _StubScheduleFilterRepository(),
        );

  @override
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async =>
      Schedule();

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async =>
      ScheduleQueryResult(Schedule(), <ParseError>[]);
}

class _StubScheduleSourceProvider extends ScheduleSourceProvider {
  _StubScheduleSourceProvider(PreferencesProvider preferences)
      : super(
          preferences,
          false,
          _StubScheduleEntryRepository(),
          _StubScheduleQueryInfoRepository(),
        );

  @override
  Future<bool> setupScheduleSource() async => true;

  @override
  bool didSetupCorrectly() => true;
}

class _StubScheduleEntryRepository extends ScheduleEntryRepository {
  _StubScheduleEntryRepository() : super(_StubDatabaseAccess());
}

class _StubScheduleFilterRepository extends ScheduleFilterRepository {
  _StubScheduleFilterRepository() : super(_StubDatabaseAccess());
}

class _StubScheduleQueryInfoRepository extends ScheduleQueryInformationRepository {
  _StubScheduleQueryInfoRepository() : super(_StubDatabaseAccess());
}

class _StubDatabaseAccess extends DatabaseAccess {
  @override
  Future<int> insert(String table, Map<String, dynamic> row) async => 0;

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
  }) async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql,
    List<dynamic> parameters,
  ) async => <Map<String, dynamic>>[];

  @override
  Future<int> queryAggregator(String query, List<dynamic> arguments) async => 0;

  @override
  Future<int> update(String table, Map<String, dynamic> row) async => 0;

  @override
  Future<int> delete(String table, int id) async => 0;

  @override
  Future<int> deleteWhere(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async => 0;
}
