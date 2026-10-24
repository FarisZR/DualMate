import 'package:dualmate/common/data/preferences/preferences_access.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/data/preferences/secure_storage_access.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/date_management/business/date_entry_provider.dart';
import 'package:dualmate/date_management/business/rapla_important_events_provider.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/ui/viewmodels/date_management_view_model.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Timetables repository;
  late ScheduleSourceProvider source;
  late _Events events;
  late DateManagementViewModel model;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesProvider(
      PreferencesAccess(),
      SecureStorageAccess(),
    );
    repository = _Timetables();
    source = ScheduleSourceProvider(
      preferences,
      true,
      _Entries(),
      _Queries(),
      timetableRepository: repository,
    );
    events = _Events(source);
    model = DateManagementViewModel(
      _Dates(),
      preferences,
      events,
      timetableSourceProvider: source,
    );
    await model.prepare();
  });
  tearDown(() => model.dispose());

  test('Dates opened before source setup reads persisted timetables', () async {
    expect(source.activeSourceIdentities, isEmpty);
    await model.updateDates();
    await _drain();
    expect(model.raplaUrlValid, isTrue);
    expect(model.bothSourcesUnconfigured, isFalse);
    expect(model.importantEvents.map((e) => e.title), ['Exam']);
  });

  test(
    'unchanged source setup during refresh preserves loaded events',
    () async {
      await source.setupScheduleSource();
      await model.updateDates();
      await _drain();
      expect(events.refreshes, greaterThan(0));
      expect(events.cancelled, isFalse);
      expect(model.importantEvents.map((e) => e.title), ['Exam']);
      final reads = events.reads;
      await source.setupScheduleSource();
      await _drain();
      expect(events.reads, reads);
      expect(model.importantEvents.map((e) => e.title), ['Exam']);
    },
  );

  test(
    'selection revision with identical identities reloads visible dates',
    () async {
      await source.setupScheduleSource();
      await model.updateDates();
      await _drain();
      expect(model.importantEvents, isNotEmpty);
      final reads = events.reads;
      events.visible = false;
      events.offline = true;
      repository.revision++;
      await source.setupScheduleSource();
      await _drain();
      expect(model.importantEvents, isEmpty);
      expect(events.reads, greaterThan(reads));
      expect(model.isLoading, isFalse);
    },
  );
}

Future<void> _drain() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Timetables implements TimetableRepository {
  int revision = 1;
  @override
  Future<TimetableSnapshot> loadSnapshot() async => TimetableSnapshot([
    TimetableConfiguration(
      id: 'ical:b4',
      label: 'B4',
      type: ScheduleSourceType.Ical,
      value: 'https://example.com/b4.ics',
      includeAll: true,
    ),
  ], revision);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Events implements RaplaImportantEventsProvider {
  final ScheduleSourceProvider source;
  bool visible = true;
  bool offline = false;
  bool cancelled = false;
  int refreshes = 0;
  int reads = 0;
  _Events(this.source);
  @override
  Future<List<ImportantEvent>> getCachedImportantEvents(
    DateTime start,
    DateTime end,
  ) async {
    reads++;
    return visible
        ? [
            ImportantEvent(
              title: 'Exam',
              start: DateTime.now().add(const Duration(days: 1)),
              end: DateTime.now().add(const Duration(days: 1, hours: 1)),
              type: ScheduleEntryType.Exam,
            ),
          ]
        : [];
  }

  @override
  Future<ScheduleQueryResult?> refreshImportantEvents(
    DateTime start,
    DateTime end,
    CancellationToken token,
  ) async {
    refreshes++;
    if (offline) return null;
    await source.setupScheduleSource();
    cancelled = cancelled || token.isCancelled();
    return ScheduleQueryResult(Schedule(), []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Dates implements DateEntryProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Entries implements ScheduleEntryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Queries implements ScheduleQueryInformationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
