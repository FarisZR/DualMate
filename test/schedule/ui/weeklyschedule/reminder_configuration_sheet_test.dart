import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/reminder_configuration_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recurring selection shows name-matching disclaimer', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Every occurrence'));
    await tester.pumpAndSettle();

    expect(find.text('Matches by class name'), findsOneWidget);
    expect(find.textContaining('same displayed class name'), findsOneWidget);
  });

  testWidgets('saves the selected offset and scope', (tester) async {
    Duration? savedOffset;
    ClassReminderScope? savedScope;
    await tester.pumpWidget(
      _app(
        onSave: (offset, scope) async {
          savedOffset = offset;
          savedScope = scope;
        },
      ),
    );

    await tester.tap(find.text('30 minutes before'));
    await tester.tap(find.text('Every occurrence'));
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(savedOffset, const Duration(minutes: 30));
    expect(savedScope, ClassReminderScope.recurring);
  });
}

Widget _app({Future<void> Function(Duration, ClassReminderScope)? onSave}) =>
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        LocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: Scaffold(
        body: ReminderConfigurationSheet(
          existingRule: null,
          onSave: onSave ?? (_, _) async {},
        ),
      ),
    );
