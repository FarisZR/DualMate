import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/schedule/ui/schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'permission notice animation preserves the schedule child state',
    (tester) async {
      final reminders = _FakeReminderController();
      await tester.pumpWidget(_app(reminders));

      final stateBefore = tester.state<_StableScheduleState>(
        find.byType(_StableSchedule),
      );

      reminders.paused = true;
      reminders.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Class reminders are paused'), findsOneWidget);
      expect(
        tester.state<_StableScheduleState>(find.byType(_StableSchedule)),
        same(stateBefore),
      );

      reminders.paused = false;
      reminders.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        tester.state<_StableScheduleState>(find.byType(_StableSchedule)),
        same(stateBefore),
      );
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
    body: ClassReminderPauseAwareContent(
      controller: reminders,
      child: const _StableSchedule(),
    ),
  ),
);

class _StableSchedule extends StatefulWidget {
  const _StableSchedule();

  @override
  State<_StableSchedule> createState() => _StableScheduleState();
}

class _StableScheduleState extends State<_StableSchedule> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _FakeReminderController extends ChangeNotifier
    implements ClassReminderController {
  bool paused = false;

  @override
  bool get remindersPaused => paused;

  @override
  bool get permissionsGranted => !paused;

  @override
  bool get isInitialized => true;

  @override
  ClassReminderRule? ruleFor(ScheduleEntry entry) => null;

  @override
  Future<void> openReliablePermissionSettings() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
