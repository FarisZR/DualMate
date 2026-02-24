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
  test('entry changed callback runs before schedule updated callback', () async {
    final start = DateTime(2026, 2, 9);
    final end = DateTime(2026, 2, 16);

    final freshEntry = ScheduleEntry(
      start: DateTime(2026, 2, 10, 9),
      end: DateTime(2026, 2, 10, 10),
      title: 'Course',
      details: 'Lecture',
      professor: 'Prof',
      room: 'R1',
      type: ScheduleEntryType.Class,
    );

    final provider = ScheduleProvider(
      _FakeScheduleSourceProvider(Schedule.fromList([freshEntry])),
      _FakeScheduleEntryRepository(),
      _FakeScheduleQueryInformationRepository(start, end),
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

    await provider.getUpdatedSchedule(start, end, CancellationToken());

    expect(callbackOrder, ['changed', 'updated']);
  });
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source;

  _FakeScheduleSourceProvider(Schedule resultSchedule)
      : _source = _FakeScheduleSource(resultSchedule);

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleSource implements ScheduleSource {
  final Schedule _resultSchedule;

  _FakeScheduleSource(this._resultSchedule);

  @override
  bool canQuery() => true;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    return ScheduleQueryResult(_resultSchedule, const []);
  }
}

class _FakeScheduleEntryRepository implements ScheduleEntryRepository {
  Schedule _cached = Schedule();

  @override
  Future<void> deleteScheduleEntriesBetween(DateTime start, DateTime end) async {
    _cached = Schedule();
  }

  @override
  Future<Schedule> queryScheduleBetweenDates(DateTime start, DateTime end) async {
    return _cached;
  }

  @override
  Future<void> saveSchedule(Schedule schedule) async {
    _cached = schedule;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleFilterRepository implements ScheduleFilterRepository {
  @override
  Future<List<String>> queryAllHiddenNames() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleQueryInformationRepository
    implements ScheduleQueryInformationRepository {
  final DateTime start;
  final DateTime end;

  _FakeScheduleQueryInformationRepository(this.start, this.end);

  @override
  Future<List<ScheduleQueryInformation>> getQueryInformationBetweenDates(
    DateTime start,
    DateTime end,
  ) async {
    return [
      ScheduleQueryInformation(this.start, this.end, DateTime(2026, 2, 1)),
    ];
  }

  @override
  Future<void> saveScheduleQueryInformation(
    ScheduleQueryInformation queryInformation,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  Future<bool> getPrettifySchedule() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
