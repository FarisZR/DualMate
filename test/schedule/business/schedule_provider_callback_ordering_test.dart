import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_information.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:test/test.dart';

void main() {
  test('schedule entry changed callbacks run before updated callbacks',
      () async {
    final schedule = Schedule.fromList([
      ScheduleEntry(
        start: DateTime(2026, 2, 24, 9),
        end: DateTime(2026, 2, 24, 10),
        title: 'Math',
        details: 'Lecture',
        professor: 'Prof',
        room: 'A1',
        type: ScheduleEntryType.Class,
      ),
    ]);

    final provider = ScheduleProvider(
      _FakeScheduleSourceProvider(_FakeScheduleSource(schedule)),
      _FakeScheduleEntryRepository(),
      _FakeScheduleQueryInformationRepository(),
      _FakePreferencesProvider(),
      _FakeScheduleFilterRepository(),
    );

    final callbackOrder = <String>[];
    provider.addScheduleEntryChangedCallback((_) async {
      callbackOrder.add('changed');
    });
    provider.addScheduleUpdatedCallback((_, __, ___) async {
      callbackOrder.add('updated');
    });

    await provider.getUpdatedSchedule(
      DateTime(2026, 2, 24),
      DateTime(2026, 2, 25),
      CancellationToken(),
    );

    expect(callbackOrder, ['changed', 'updated']);
  });
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source;

  _FakeScheduleSourceProvider(this._source);

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
        'Unexpected ScheduleSourceProvider call: $invocation');
  }
}

class _FakeScheduleSource implements ScheduleSource {
  final Schedule _schedule;

  _FakeScheduleSource(this._schedule);

  @override
  bool canQuery() => true;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    return ScheduleQueryResult(_schedule, const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected _FakeScheduleSource call: $invocation',
    );
  }
}

class _FakeScheduleEntryRepository implements ScheduleEntryRepository {
  Schedule _cached = Schedule();

  @override
  Future<Schedule> queryScheduleBetweenDates(
      DateTime start, DateTime end) async {
    return _cached;
  }

  @override
  Future<void> deleteScheduleEntriesBetween(
      DateTime start, DateTime end) async {}

  @override
  Future<void> saveSchedule(Schedule schedule) async {
    _cached = schedule;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
        'Unexpected ScheduleEntryRepository call: $invocation');
  }
}

class _FakeScheduleQueryInformationRepository
    implements ScheduleQueryInformationRepository {
  @override
  Future<List<ScheduleQueryInformation>> getQueryInformationBetweenDates(
    DateTime start,
    DateTime end,
  ) async {
    return [
      ScheduleQueryInformation(start, end, start),
    ];
  }

  @override
  Future<void> saveScheduleQueryInformation(
    ScheduleQueryInformation queryInformation,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleQueryInformationRepository call: $invocation',
    );
  }
}

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  Future<bool> getPrettifySchedule() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected PreferencesProvider call: $invocation');
  }
}

class _FakeScheduleFilterRepository implements ScheduleFilterRepository {
  @override
  Future<List<String>> queryAllHiddenNames() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
        'Unexpected ScheduleFilterRepository call: $invocation');
  }
}
