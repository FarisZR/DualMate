import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/logging/crash_reporting.dart'
    as crash_reporting;
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/date_management/business/rapla_important_events_provider.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    crash_reporting.reportExceptionImpl =
        crash_reporting.reportExceptionToSentry;
  });

  test('rapla refresh uses a silent foreground maintenance origin', () async {
    final scheduleProvider = _TrackingScheduleProvider();
    final provider = RaplaImportantEventsProvider(
      _FakePreferencesProvider(),
      scheduleProvider,
      _FakeScheduleSourceProvider(),
    );

    await provider.refreshImportantEvents(
      DateTime(2026, 3, 1),
      DateTime(2026, 6, 1),
      CancellationToken(),
    );

    expect(scheduleProvider.origins, [
      ScheduleRefreshOrigin.foregroundMaintenance,
    ]);
  });

  test('expected network failure returns null without reporting', () async {
    final reportedErrors = <Object>[];
    crash_reporting.reportExceptionImpl = (error, trace) async {
      reportedErrors.add(error);
    };

    final provider = RaplaImportantEventsProvider(
      _FakePreferencesProvider(),
      _ThrowingScheduleProvider(
        ScheduleQueryFailedException(
          ServiceRequestFailed('Http request failed!'),
        ),
      ),
      _FakeScheduleSourceProvider(),
    );

    final result = await provider.refreshImportantEvents(
      DateTime(2026, 3, 1),
      DateTime(2026, 6, 1),
      CancellationToken(),
    );

    expect(result, isNull);
    expect(reportedErrors, isEmpty);
  });

  test(
    'unexpected ScheduleQueryFailedException is reported before returning null',
    () async {
      final reportedErrors = <Object>[];
      crash_reporting.reportExceptionImpl = (error, trace) async {
        reportedErrors.add(error);
      };

      final provider = RaplaImportantEventsProvider(
        _FakePreferencesProvider(),
        _ThrowingScheduleProvider(
          ScheduleQueryFailedException(
            StateError('parse structure regression'),
          ),
        ),
        _FakeScheduleSourceProvider(),
      );

      final result = await provider.refreshImportantEvents(
        DateTime(2026, 3, 1),
        DateTime(2026, 6, 1),
        CancellationToken(),
      );

      expect(result, isNull);
      expect(reportedErrors, isNotEmpty);
      expect(reportedErrors.first, isA<ScheduleQueryFailedException>());
    },
  );
}

class _TrackingScheduleProvider implements ScheduleProvider {
  final List<ScheduleRefreshOrigin> origins = <ScheduleRefreshOrigin>[];

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    origins.add(origin);
    return ScheduleQueryResult(Schedule(), const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _ThrowingScheduleProvider implements ScheduleProvider {
  final Object _error;

  _ThrowingScheduleProvider(this._error);

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken, {
    ScheduleRefreshOrigin origin = ScheduleRefreshOrigin.userBrowsing,
  }) async {
    throw _error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _FakePreferencesProvider implements PreferencesProvider {
  @override
  Future<String> getRaplaUrl() async => 'https://rapla.dhbw.example?key=test';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected PreferencesProvider call: $invocation');
  }
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source = _FakeScheduleSource();

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  bool didSetupCorrectly() => true;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected ScheduleSourceProvider call: $invocation',
    );
  }
}

class _FakeScheduleSource implements ScheduleSource {
  @override
  bool canQuery() => true;

  @override
  Future<ScheduleQueryResult> querySchedule(
    DateTime from,
    DateTime to, [
    CancellationToken? cancellationToken,
  ]) async {
    return ScheduleQueryResult(Schedule(), const []);
  }
}
