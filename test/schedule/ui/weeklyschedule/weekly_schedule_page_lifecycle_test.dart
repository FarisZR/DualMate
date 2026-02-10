import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/viewmodels/weekly_schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'resume-triggered background refresh keeps monday lessons visible',
    (tester) async {
      const mondayTitle = 'MONDAY_ANCHOR';
      final entries = <ScheduleEntry>[
        _entry(DateTime(2026, 2, 9), mondayTitle),
        _entry(DateTime(2026, 2, 10), 'TUESDAY_ENTRY'),
        _entry(DateTime(2026, 2, 16), 'NEXT_MONDAY'),
      ];
      final provider = _TrackingScheduleProvider(entries);
      final sourceProvider = _FakeScheduleSourceProvider();
      final nowOnTuesday = DateTime(2026, 2, 10, 11, 0);
      final viewModel = WeeklyScheduleViewModel(
        provider,
        sourceProvider,
        nowProvider: () => nowOnTuesday,
      );

      await viewModel.updateSchedule(
        DateTime(2026, 2, 9),
        DateTime(2026, 2, 16),
        force: true,
      );

      await tester.pumpWidget(_wrapWithApp(viewModel));
      await tester.pump();

      expect(find.text(mondayTitle), findsOneWidget);
      expect(viewModel.currentDateStart, DateTime(2026, 2, 9));
      expect(viewModel.currentDateStart.weekday, DateTime.monday);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(viewModel.currentDateStart, DateTime(2026, 2, 9));
      expect(viewModel.currentDateStart.weekday, DateTime.monday);
      expect(find.text(mondayTitle), findsOneWidget);

      expect(
        provider.cachedRequests.any(
          (request) =>
              request.start == DateTime(2026, 2, 10) &&
              request.end == DateTime(2026, 2, 24),
        ),
        isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      viewModel.dispose();
    },
  );
}

Widget _wrapWithApp(WeeklyScheduleViewModel viewModel) {
  return ChangeNotifierProvider<WeeklyScheduleViewModel>.value(
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
        body: WeeklySchedulePage(),
      ),
    ),
  );
}

ScheduleEntry _entry(DateTime day, String title) {
  return ScheduleEntry(
    start: DateTime(day.year, day.month, day.day, 9),
    end: DateTime(day.year, day.month, day.day, 10),
    title: title,
    details: 'Lecture',
    professor: 'Prof',
    room: 'R1',
    type: ScheduleEntryType.Class,
  );
}

class _TrackingScheduleProvider implements ScheduleProvider {
  final List<ScheduleEntry> _entries;
  final List<_RangeRequest> cachedRequests = <_RangeRequest>[];

  _TrackingScheduleProvider(this._entries);

  @override
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
    cachedRequests.add(_RangeRequest(start, end));
    return _trim(start, end);
  }

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken,
  ) async {
    return ScheduleQueryResult(_trim(start, end), const []);
  }

  Schedule _trim(DateTime start, DateTime end) {
    final entries = _entries.where((entry) {
      return start.isBefore(entry.end) && end.isAfter(entry.start);
    }).toList();
    return Schedule.fromList(entries);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RangeRequest {
  final DateTime start;
  final DateTime end;

  _RangeRequest(this.start, this.end);
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source = _FakeScheduleSource();

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  bool didSetupCorrectly() => true;

  @override
  void addDidChangeScheduleSourceCallback(OnDidChangeScheduleSource callback) {}

  @override
  void removeDidChangeScheduleSourceCallback(
    OnDidChangeScheduleSource callback,
  ) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
