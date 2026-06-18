import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/ui/widgets/important_event_tile.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows professor for exam events', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrapWithApp(
        SizedBox(
          width: 180,
          child: ImportantEventTile(
            event: ImportantEvent(
              title: 'Klausur',
              start: DateTime(2026, 7, 31, 8),
              end: DateTime(2026, 7, 31, 10),
              professor: 'Prof. Schmidt',
              type: ScheduleEntryType.Exam,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );

    expect(find.text('Klausur'), findsOneWidget);
    expect(find.text('Prof. Schmidt'), findsOneWidget);
    expect(find.byKey(const Key('important_event_professor_text')),
        findsOneWidget);

    final professorText = tester.widget<Text>(
      find.byKey(const Key('important_event_professor_text')),
    );
    expect(professorText.maxLines, 1);
    expect(professorText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('long professor names do not start autonomous scroll animations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithApp(
        SizedBox(
          width: 180,
          child: ImportantEventTile(
            event: ImportantEvent(
              title: 'Klausur',
              start: DateTime(2026, 7, 31, 8),
              end: DateTime(2026, 7, 31, 10),
              professor:
                  'Prof. Schmidt, Prof. Becker, Prof. Mueller, Prof. Fischer',
              type: ScheduleEntryType.Exam,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );

    final professorText = tester.widget<Text>(
      find.byKey(const Key('important_event_professor_text')),
    );

    expect(professorText.maxLines, 1);
    expect(professorText.overflow, TextOverflow.ellipsis);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('hides professor for non exam events', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithApp(
        ImportantEventTile(
          event: ImportantEvent(
            title: 'Feiertag',
            start: DateTime(2026, 7, 31),
            end: DateTime(2026, 7, 31),
            professor: 'Prof. Schmidt',
            type: ScheduleEntryType.PublicHoliday,
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );

    expect(find.text('Feiertag'), findsOneWidget);
    expect(find.text('Prof. Schmidt'), findsNothing);
  });
}

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      LocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('de')],
    home: Scaffold(body: child),
  );
}
