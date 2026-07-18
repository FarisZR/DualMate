import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/schedule_entry_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'reminder action stays disabled until controller initialization',
    (tester) async {
      final reminders = _ReadyReminderController();
      await tester.pumpWidget(_app(reminders));

      var button = tester.widget<IconButton>(
        find.byKey(const ValueKey('class-reminder-button')),
      );
      expect(button.onPressed, isNull);

      reminders.ready = true;
      reminders.notifyListeners();
      await tester.pump();

      button = tester.widget<IconButton>(
        find.byKey(const ValueKey('class-reminder-button')),
      );
      expect(button.onPressed, isNotNull);
    },
  );
}

Widget _app(ClassReminderController reminders) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: const [Locale('en'), Locale('de')],
  localizationsDelegates: const [
    LocalizationDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: ScheduleEntryDetailBottomSheet(
      scheduleEntry: ScheduleEntry(
        start: DateTime(2026, 7, 20, 9),
        end: DateTime(2026, 7, 20, 11),
        title: 'Recht',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.Class,
      ),
      reminderController: reminders,
    ),
  ),
);

class _ReadyReminderController extends ChangeNotifier
    implements ClassReminderController {
  bool ready = false;

  @override
  bool get isInitialized => ready;

  @override
  bool get permissionsGranted => true;

  @override
  ClassReminderRule? ruleFor(ScheduleEntry entry) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
