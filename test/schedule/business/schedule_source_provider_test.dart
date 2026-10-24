import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/data/timetable_repository.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'an invalid child marks the combined timetable setup as invalid',
    () async {
      final configs = _Timetables([
        _configuration(
          ScheduleSourceType.Ical,
          'https://example.com/calendar.ics',
        ),
        _configuration(ScheduleSourceType.Rapla, 'invalid-url'),
      ]);
      final provider = _provider(configs);
      bool? setupSuccess;
      provider.addDidChangeScheduleSourceCallback(
        (_, success) => setupSuccess = success,
      );
      expect(await provider.setupScheduleSource(), isFalse);
      expect(provider.didSetupCorrectly(), isFalse);
      expect(provider.currentScheduleSource.canQuery(), isFalse);
      expect(setupSuccess, isFalse);
    },
  );

  test(
    'source callbacks during Save keep the active performance fixture',
    () async {
      final config = _configuration(
        ScheduleSourceType.Ical,
        'https://example.com/calendar.ics',
      );
      final provider = _provider(_Timetables([config]));
      final fixture = _Fixture();
      provider.usePerformanceFixtureSource(fixture);
      final notified = <ScheduleSource>[];
      provider.addDidChangeScheduleSourceCallback(
        (source, _) => notified.add(source),
      );
      await provider.saveTimetables([config.withModule('Math', true)]);
      expect(provider.currentScheduleSource, same(fixture));
      expect(notified, [same(fixture)]);
    },
  );
  group('clearScheduleCache', () {
    test('deletes entries and query information', () async {
      final entryRepo = _RecordingEntryRepository();
      final queryRepo = _RecordingQueryInformationRepository();
      final provider = ScheduleSourceProvider(
        _FakePreferencesProvider(),
        false,
        entryRepo,
        queryRepo,
      );

      await provider.clearScheduleCache();

      expect(entryRepo.deleteAllCalls, 1);
      expect(queryRepo.deleteAllCalls, 1);
    });
  });

  group('wouldChangeTo', () {
    ScheduleSourceProvider _makeUnconfiguredProvider() =>
        ScheduleSourceProvider(
          _FakePreferencesProvider(),
          false,
          _RecordingEntryRepository(),
          _RecordingQueryInformationRepository(),
        );

    test('reports no change for None type with empty value', () {
      final provider = _makeUnconfiguredProvider();
      expect(provider.wouldChangeTo(ScheduleSourceType.None, ''), isFalse);
    });

    test('reports no change for configured type with empty value', () {
      final provider = _makeUnconfiguredProvider();
      expect(provider.wouldChangeTo(ScheduleSourceType.Rapla, ''), isFalse);
    });

    test('reports change for configured type with non-empty value', () {
      final provider = _makeUnconfiguredProvider();
      expect(
        provider.wouldChangeTo(
          ScheduleSourceType.Rapla,
          'https://rapla.dhbw-karlsruhe.de/rapla?page=calendar&user=test&file=TINF25B4',
        ),
        isTrue,
      );
    });
  });
}

ScheduleSourceProvider _provider(_Timetables configs) => ScheduleSourceProvider(
  _FakePreferencesProvider(),
  true,
  _RecordingEntryRepository(),
  _RecordingQueryInformationRepository(),
  timetableRepository: configs,
);
TimetableConfiguration _configuration(ScheduleSourceType type, String value) =>
    TimetableConfiguration(
      id: type.name,
      label: type.name,
      type: type,
      value: value,
    );

class _Timetables implements TimetableRepository {
  List<TimetableConfiguration> configurations;
  _Timetables(this.configurations);
  @override
  Future<TimetableSnapshot> loadSnapshot() async =>
      TimetableSnapshot(configurations, 1);
  @override
  Future<void> save(List<TimetableConfiguration> value) async =>
      configurations = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fixture implements ScheduleSource {
  @override
  bool canQuery() => true;
  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? token,
  ]) async => ScheduleQueryResult(Schedule(), []);
}

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingEntryRepository implements ScheduleEntryRepository {
  int deleteAllCalls = 0;

  @override
  Future<void> deleteAllScheduleEntries() async {
    deleteAllCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingQueryInformationRepository
    implements ScheduleQueryInformationRepository {
  int deleteAllCalls = 0;

  @override
  Future<void> deleteAllQueryInformation() async {
    deleteAllCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
