import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/model/schedule_query_result.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/schedule/ui/schedule_page.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi/kiwi.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    KiwiContainer().clear();
    SchedulePage.resetSharedState();
  });

  tearDown(() {
    SchedulePage.resetSharedState();
    KiwiContainer().clear();
  });

  testWidgets('renders weekly schedule directly without pager shell', (
    tester,
  ) async {
    final container = KiwiContainer();
    container.registerInstance<ScheduleProvider>(
      _FakeScheduleProvider(
        <ScheduleEntry>[
          _entry(DateTime(2026, 3, 9), 'CURRENT_WEEK'),
        ],
      ),
    );
    container.registerInstance<ScheduleSourceProvider>(
        _FakeScheduleSourceProvider());

    final scheduleViewModel = ScheduleViewModel(_FakeScheduleSourceProvider());

    await tester.pumpWidget(
      ChangeNotifierProvider<ScheduleViewModel>.value(
        value: scheduleViewModel,
        child: MaterialApp(
          localizationsDelegates: const [
            LocalizationDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('de')],
          home: SchedulePage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(WeeklySchedulePage), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    SchedulePage.resetSharedState();
    scheduleViewModel.dispose();
  });
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

class _FakeScheduleProvider implements ScheduleProvider {
  final List<ScheduleEntry> _entries;

  _FakeScheduleProvider(this._entries);

  @override
  Future<Schedule> getCachedSchedule(DateTime start, DateTime end) async {
    final entries = _entries.where((entry) {
      return start.isBefore(entry.end) && end.isAfter(entry.start);
    }).toList();
    return Schedule.fromList(entries);
  }

  @override
  Future<ScheduleQueryResult> getUpdatedSchedule(
    DateTime start,
    DateTime end,
    CancellationToken cancellationToken,
  ) async {
    return ScheduleQueryResult(await getCachedSchedule(start, end), const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected ScheduleProvider call: $invocation');
  }
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  final ScheduleSource _source = _FakeScheduleSource();

  @override
  ScheduleSource get currentScheduleSource => _source;

  @override
  bool didSetupCorrectly() => true;

  @override
  Future<bool> setupScheduleSource() async {
    return true;
  }

  @override
  void addDidChangeScheduleSourceCallback(OnDidChangeScheduleSource callback) {}

  @override
  void removeDidChangeScheduleSourceCallback(
    OnDidChangeScheduleSource callback,
  ) {}

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
