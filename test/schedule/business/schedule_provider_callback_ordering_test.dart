import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/logging/crash_reporting.dart'
    as crash_reporting;
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
  tearDown(() {
    crash_reporting.reportExceptionImpl =
        crash_reporting.reportExceptionToSentry;
  });

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
    provider.addScheduleEntryChangedCallback((_, __) async {
      callbackOrder.add('changed');
    });
    provider.addScheduleUpdatedCallback((_, __, ___) async {
      callbackOrder.add('updated');
    });

    await provider.getUpdatedSchedule(
      DateTime(2026, 2, 24),
      DateTime(2026, 2, 25),
      CancellationToken(),
      origin: ScheduleRefreshOrigin.backgroundPeriodic,
    );

    expect(callbackOrder, ['changed', 'updated']);
  });

  test('attended refresh origins still invoke changed callbacks with origin',
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
    ScheduleRefreshOrigin? capturedOrigin;
    provider.addScheduleEntryChangedCallback((_, origin) async {
      callbackOrder.add('changed');
      capturedOrigin = origin;
    });
    provider.addScheduleUpdatedCallback((_, __, ___) async {
      callbackOrder.add('updated');
    });

    await provider.getUpdatedSchedule(
      DateTime(2026, 2, 24),
      DateTime(2026, 2, 25),
      CancellationToken(),
      origin: ScheduleRefreshOrigin.userBrowsing,
    );

    expect(callbackOrder, ['changed', 'updated']);
    expect(capturedOrigin, ScheduleRefreshOrigin.userBrowsing);
  });

  test('schedule parse errors are reported through crash reporting', () async {
    final reportedErrors = <Object>[];
    final reportedTraces = <StackTrace>[];
    crash_reporting.reportExceptionImpl = (error, trace) async {
      reportedErrors.add(error);
      reportedTraces.add(trace);
    };

    final provider = ScheduleProvider(
      _FakeScheduleSourceProvider(
        _FakeScheduleSource(
          Schedule(),
          errors: [
            ParseError('event could not be interpreted', StackTrace.current)
          ],
        ),
      ),
      _FakeScheduleEntryRepository(),
      _FakeScheduleQueryInformationRepository(),
      _FakePreferencesProvider(),
      _FakeScheduleFilterRepository(),
    );

    final result = await provider.getUpdatedSchedule(
      DateTime(2026, 1, 26),
      DateTime(2026, 2, 2),
      CancellationToken(),
    );

    expect(result.errors, hasLength(1));
    expect(reportedErrors, hasLength(1));
    expect(reportedErrors.single, isA<StateError>());
    expect(
      reportedErrors.single.toString(),
      contains('event could not be interpreted'),
    );
    expect(reportedTraces, hasLength(1));
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
  final List<ParseError> _errors;

  _FakeScheduleSource(this._schedule, {List<ParseError> errors = const []})
      : _errors = errors;

  @override
  bool canQuery() => true;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    return ScheduleQueryResult(_schedule, _errors);
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
