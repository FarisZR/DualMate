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

  testWidgets('recurring disclaimer uses its container foreground color', (
    tester,
  ) async {
    const foreground = Color(0xff102030);
    await tester.pumpWidget(
      _app(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ).copyWith(onSecondaryContainer: foreground),
        ),
      ),
    );

    await tester.tap(find.text('Every occurrence'));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Matches by class name'));
    final description = tester.widget<Text>(
      find.textContaining('same displayed class name'),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
    expect(title.style?.color, foreground);
    expect(description.style?.color, foreground);
    expect(icon.color, foreground);
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

  testWidgets('custom offset cannot be saved until it is positive', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        existingRule: ClassReminderRule(
          id: 'custom',
          scope: ClassReminderScope.oneTime,
          canonicalTitle: 'Recht',
          offset: const Duration(minutes: 10),
          sourceIdentity: 'rapla:a',
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    FilledButton saveButton() =>
        tester.widget(find.widgetWithText(FilledButton, 'Save reminder'));
    expect(saveButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '10');
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);
  });
}

Widget _app({
  Future<void> Function(Duration, ClassReminderScope)? onSave,
  ThemeData? theme,
  ClassReminderRule? existingRule,
}) => MaterialApp(
  theme: theme,
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
      existingRule: existingRule,
      onSave: onSave ?? (_, _) async {},
    ),
  ),
);
