import 'package:dualmate/common/logging/crash_reporting.dart'
    as crash_reporting;
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reportedErrors = <Object>[];

  setUp(() {
    reportedErrors.clear();
    crash_reporting.reportExceptionImpl = (error, trace) async {
      reportedErrors.add(error);
    };
  });

  tearDown(() {
    crash_reporting.reportExceptionImpl =
        crash_reporting.reportExceptionToSentry;
  });

  group('isExpectedScheduleFetchFailure', () {
    test('matches ServiceRequestFailed directly', () {
      expect(
        isExpectedScheduleFetchFailure(ServiceRequestFailed('Http request')),
        isTrue,
      );
    });

    test(
      'matches ScheduleQueryFailedException wrapping ServiceRequestFailed',
      () {
        expect(
          isExpectedScheduleFetchFailure(
            ScheduleQueryFailedException(ServiceRequestFailed('timeout')),
          ),
          isTrue,
        );
      },
    );

    test(
      'does not match ScheduleQueryFailedException wrapping a generic error',
      () {
        expect(
          isExpectedScheduleFetchFailure(
            ScheduleQueryFailedException(StateError('parse boom')),
          ),
          isFalse,
        );
      },
    );

    test('does not match unrelated exceptions', () {
      expect(isExpectedScheduleFetchFailure(StateError('unexpected')), isFalse);
    });
  });

  group('weekly schedule refresh Sentry suppression', () {
    test(
      'expected network failure (ServiceRequestFailed) does not call exception reporter',
      () async {
        final provider = _ThrowingScheduleProvider(
          ScheduleQueryFailedException(
            ServiceRequestFailed('Http request failed!'),
          ),
        );
        final viewModel = _buildViewModel(provider);
        addTearDown(viewModel.dispose);

        await _forceRefresh(viewModel);

        expect(
          reportedErrors,
          isEmpty,
          reason: 'Expected network failures must not create Sentry Issues',
        );
      },
    );

    test(
      'expected network failure still marks updateFailed in the view model',
      () async {
        final provider = _ThrowingScheduleProvider(
          ScheduleQueryFailedException(
            ServiceRequestFailed('Http request failed!'),
          ),
        );
        final viewModel = _buildViewModel(provider);
        addTearDown(viewModel.dispose);

        await _forceRefresh(viewModel);

        expect(
          viewModel.updateFailed,
          isTrue,
          reason: 'UI failure state must still update for expected failures',
        );
      },
    );

    test(
      'expected network failure still allows isUpdating to settle',
      () async {
        final provider = _ThrowingScheduleProvider(
          ScheduleQueryFailedException(
            ServiceRequestFailed('Http request failed!'),
          ),
        );
        final viewModel = _buildViewModel(provider);
        addTearDown(viewModel.dispose);

        await _forceRefresh(viewModel);

        expect(
          viewModel.isUpdating,
          isFalse,
          reason: 'Loading spinner must clear even for suppressed failures',
        );
      },
    );

    test(
      'unexpected exception during refresh still calls exception reporter',
      () async {
        final provider = _ThrowingScheduleProvider(StateError('unexpected'));
        final viewModel = _buildViewModel(provider);
        addTearDown(viewModel.dispose);

        await _forceRefresh(viewModel);

        expect(
          reportedErrors,
          isNotEmpty,
          reason: 'Unexpected exceptions must still reach Sentry',
        );
        expect(reportedErrors.first, isA<StateError>());
      },
    );

    test(
      'non-network ScheduleQueryFailedException still calls exception reporter',
      () async {
        final provider = _ThrowingScheduleProvider(
          ScheduleQueryFailedException(
            StateError('parse structure regression'),
          ),
        );
        final viewModel = _buildViewModel(provider);
        addTearDown(viewModel.dispose);

        await _forceRefresh(viewModel);

        expect(
          reportedErrors,
          isNotEmpty,
          reason:
              'Non-network ScheduleQueryFailedException variants must still '
              'be reported',
        );
        expect(reportedErrors.first, isA<ScheduleQueryFailedException>());
      },
    );

    test(
      'non-network ScheduleQueryFailedException still marks updateFailed',
      () async {
        final provider = _ThrowingScheduleProvider(
          ScheduleQueryFailedException(
            StateError('parse structure regression'),
          ),
        );
        final viewModel = _buildViewModel(provider);
        addTearDown(viewModel.dispose);

        await _forceRefresh(viewModel);

        expect(viewModel.updateFailed, isTrue);
      },
    );

    test(
      'raw ServiceRequestFailed during refresh does not call reporter',
      () async {
        final provider = _ThrowingScheduleProvider(
          ServiceRequestFailed('connection reset'),
        );
        final viewModel = _buildViewModel(provider);
        addTearDown(viewModel.dispose);

        await _forceRefresh(viewModel);

        expect(
          reportedErrors,
          isEmpty,
          reason: 'Raw ServiceRequestFailed is an expected network failure',
        );
        expect(viewModel.updateFailed, isTrue);
      },
    );

    test(
      'expected network failure via awaitRefresh path does not call reporter',
      () async {
        final provider = _ThrowingScheduleProvider(
          ScheduleQueryFailedException(
            ServiceRequestFailed('Http request failed!'),
          ),
        );
        final viewModel = _buildViewModel(provider);
        addTearDown(viewModel.dispose);

        await viewModel.refreshVisibleWeek();

        expect(
          reportedErrors,
          isEmpty,
          reason: 'awaitRefresh path must also suppress expected failures',
        );
        expect(viewModel.updateFailed, isTrue);
      },
    );
  });
}

final _weekStart = DateTime(2026, 2, 9);
final _weekEnd = DateTime(2026, 2, 16);

WeeklyScheduleViewModel _buildViewModel(ScheduleProvider provider) {
  return WeeklyScheduleViewModel(
    provider,
    _FakeScheduleSourceProvider(),
    nowProvider: () => DateTime(2026, 2, 10, 10),
  );
}

Future<void> _forceRefresh(WeeklyScheduleViewModel viewModel) {
  return viewModel.updateSchedule(
    _weekStart,
    _weekEnd,
    force: true,
    awaitRefresh: true,
  );
}

class _ThrowingScheduleProvider implements ScheduleProvider {
  final Object _error;

  _ThrowingScheduleProvider(this._error);

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
    throw _error;
  }

  @override
  Future<DateTime?> getLastQueryTimeForWindow(
    DateTime start,
    DateTime end,
  ) async {
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source = _FakeScheduleSource();
  final List<OnDidChangeScheduleSource> _callbacks =
      <OnDidChangeScheduleSource>[];

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  bool didSetupCorrectly() => true;

  @override
  void addDidChangeScheduleSourceCallback(OnDidChangeScheduleSource callback) {
    _callbacks.add(callback);
  }

  @override
  void removeDidChangeScheduleSourceCallback(
    OnDidChangeScheduleSource callback,
  ) {
    _callbacks.remove(callback);
  }

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
