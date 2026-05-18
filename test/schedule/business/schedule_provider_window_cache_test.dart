import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/data/schedule_query_information_repository.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached schedules are reused across multiple windows', () async {
    final repository = _CountingScheduleEntryRepository();
    final provider = ScheduleProvider(
      _FakeScheduleSourceProvider(),
      repository,
      _FakeScheduleQueryInformationRepository(),
      _FakePreferencesProvider(),
      _FakeScheduleFilterRepository(),
    );

    final firstStart = DateTime(2026, 3, 2);
    final firstEnd = DateTime(2026, 3, 9);
    final secondStart = DateTime(2026, 3, 9);
    final secondEnd = DateTime(2026, 3, 16);

    await provider.getCachedSchedule(firstStart, firstEnd);
    await provider.getCachedSchedule(secondStart, secondEnd);
    await provider.getCachedSchedule(firstStart, firstEnd);

    expect(repository.callsFor(firstStart, firstEnd), 1);
    expect(repository.callsFor(secondStart, secondEnd), 1);
  });
}

class _CountingScheduleEntryRepository implements ScheduleEntryRepository {
  final Map<String, int> _queryCounts = <String, int>{};

  @override
  Future<Schedule> queryScheduleBetweenDates(
      DateTime start, DateTime end) async {
    _queryCounts.update(_key(start, end), (value) => value + 1,
        ifAbsent: () => 1);
    return Schedule();
  }

  int callsFor(DateTime start, DateTime end) =>
      _queryCounts[_key(start, end)] ?? 0;

  String _key(DateTime start, DateTime end) =>
      '${start.toIso8601String()}_${end.toIso8601String()}';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
        'Unexpected ScheduleEntryRepository call: $invocation');
  }
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
        'Unexpected ScheduleSourceProvider call: $invocation');
  }
}

class _FakeScheduleQueryInformationRepository
    implements ScheduleQueryInformationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleQueryInformationRepository call: $invocation',
    );
  }
}

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected PreferencesProvider call: $invocation');
  }
}

class _FakeScheduleFilterRepository implements ScheduleFilterRepository {
  @override
  Future<List<String>> queryAllHiddenNames() async => <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
        'Unexpected ScheduleFilterRepository call: $invocation');
  }
}
