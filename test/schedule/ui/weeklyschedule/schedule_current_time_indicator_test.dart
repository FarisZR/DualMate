import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_current_time_indicator.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows weekly current-time indicator when now is in range', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        now: DateTime(2026, 2, 11, 12, 15),
      ),
    );

    expect(find.byType(ScheduleCurrentTimeIndicator), findsOneWidget);
  });

  testWidgets('hides weekly current-time indicator before visible hours', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        now: DateTime(2026, 2, 11, 6, 55),
      ),
    );

    expect(find.byType(ScheduleCurrentTimeIndicator), findsNothing);
  });

  testWidgets('shows weekly current-time indicator at visible start hour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        now: DateTime(2026, 2, 11, 7, 0),
      ),
    );

    expect(find.byType(ScheduleCurrentTimeIndicator), findsOneWidget);
  });

  testWidgets('hides weekly current-time indicator after visible hours', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        now: DateTime(2026, 2, 11, 19, 0),
      ),
    );

    expect(find.byType(ScheduleCurrentTimeIndicator), findsNothing);
  });

  testWidgets('hides weekly current-time indicator when today is not visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        now: DateTime(2026, 3, 1, 12, 0),
      ),
    );

    expect(find.byType(ScheduleCurrentTimeIndicator), findsNothing);
  });

  testWidgets('weekly current-time indicator does not block entry taps', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _buildApp(
        now: DateTime(2026, 2, 11, 12, 15),
        schedule: Schedule.fromList([
          _entry(
            DateTime(2026, 2, 11, 12, 0),
            DateTime(2026, 2, 11, 13, 0),
            'Operating Systems',
          ),
        ]),
        onTap: (_) => tapCount++,
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(ScheduleCurrentTimeIndicator), findsOneWidget);

    await tester.tap(find.text('Operating Systems'));
    await tester.pump();

    expect(tapCount, 1);
  });
}

Widget _buildApp({
  required DateTime now,
  Schedule? schedule,
  void Function(ScheduleEntry)? onTap,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      LocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('de')],
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          height: 680,
          child: ScheduleWidget(
            schedule: schedule ?? Schedule(),
            displayStart: DateTime(2026, 2, 9),
            displayEnd: DateTime(2026, 2, 13),
            onScheduleEntryTap: onTap ?? (_) {},
            now: now,
            displayStartHour: 7.0,
            displayEndHour: 19.0,
          ),
        ),
      ),
    ),
  );
}

ScheduleEntry _entry(DateTime start, DateTime end, String title) {
  return ScheduleEntry(
    start: start,
    end: end,
    title: title,
    details: 'Details',
    professor: 'Prof',
    room: 'R1',
    type: ScheduleEntryType.Class,
  );
}
