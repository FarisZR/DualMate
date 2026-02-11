import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/model/schedule.dart';
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
}

Widget _buildApp({required double width, required double height}) {
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
            schedule: Schedule(),
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
