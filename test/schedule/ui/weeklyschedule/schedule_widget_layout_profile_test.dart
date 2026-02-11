import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_entry_widget.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_grid.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses compact mobile grid dimensions on narrow layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        width: 360,
        height: 680,
      ),
    );

    final grid = tester.widget<ScheduleGrid>(find.byType(ScheduleGrid));
    expect(grid.timeLabelsWidth, 46);
    expect(grid.dateLabelsHeight, 52);
  });

  testWidgets('keeps default grid dimensions on wide layouts', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: 800,
        height: 680,
      ),
    );

    final grid = tester.widget<ScheduleGrid>(find.byType(ScheduleGrid));
    expect(grid.timeLabelsWidth, 54);
    expect(grid.dateLabelsHeight, 72);
  });

  testWidgets('compact layout keeps adjacent day event cards nearly touching',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: 360,
        height: 680,
        schedule: Schedule.fromList([
          _entry(DateTime(2026, 2, 9, 9), DateTime(2026, 2, 9, 10), 'A'),
          _entry(DateTime(2026, 2, 10, 9), DateTime(2026, 2, 10, 10), 'B'),
        ]),
      ),
    );

    final entryA = find.ancestor(
      of: find.text('A'),
      matching: find.byType(ScheduleEntryWidget),
    );
    final entryB = find.ancestor(
      of: find.text('B'),
      matching: find.byType(ScheduleEntryWidget),
    );

    final aRect = tester.getRect(entryA);
    final bRect = tester.getRect(entryB);
    final gap = bRect.left - aRect.right;
    expect(gap, lessThanOrEqualTo(0.3));
  });

  testWidgets('compact layout keeps overlap cards visually separated',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        width: 360,
        height: 680,
        schedule: Schedule.fromList([
          _entry(DateTime(2026, 2, 9, 9), DateTime(2026, 2, 9, 11), 'C1'),
          _entry(
              DateTime(2026, 2, 9, 9, 30), DateTime(2026, 2, 9, 10, 30), 'C2'),
        ]),
      ),
    );

    final entryC1 = find.ancestor(
      of: find.text('C1'),
      matching: find.byType(ScheduleEntryWidget),
    );
    final entryC2 = find.ancestor(
      of: find.text('C2'),
      matching: find.byType(ScheduleEntryWidget),
    );

    final rect1 = tester.getRect(entryC1);
    final rect2 = tester.getRect(entryC2);
    final left = rect1.left <= rect2.left ? rect1 : rect2;
    final right = rect1.left <= rect2.left ? rect2 : rect1;
    final gap = right.left - left.right;
    expect(gap, greaterThanOrEqualTo(0.2));
  });
}

Widget _buildApp({
  required double width,
  required double height,
  Schedule? schedule,
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
          width: width,
          height: height,
          child: ScheduleWidget(
            schedule: schedule ?? Schedule(),
            displayStart: DateTime(2026, 2, 9),
            displayEnd: DateTime(2026, 2, 13),
            onScheduleEntryTap: (_) {},
            now: DateTime(2026, 2, 11, 12),
            displayStartHour: 7,
            displayEndHour: 19,
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
