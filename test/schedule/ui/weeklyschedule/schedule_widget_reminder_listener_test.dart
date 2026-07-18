import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/model/schedule.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/widgets/schedule_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('one schedule layer listener serves all reminder indicators', (
    tester,
  ) async {
    final reminders = _CountingReminderController();
    final start = DateTime(2026, 7, 20);
    final entries = List<ScheduleEntry>.generate(
      20,
      (index) => ScheduleEntry(
        start: start.add(Duration(hours: 8 + (index % 8))),
        end: start.add(Duration(hours: 9 + (index % 8))),
        title: 'Class $index',
        details: '',
        professor: '',
        room: '',
        type: ScheduleEntryType.Class,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('de')],
        localizationsDelegates: const [
          LocalizationDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 800,
            child: ScheduleWidget(
              schedule: Schedule.fromList(entries),
              displayStart: start,
              displayEnd: start.add(const Duration(days: 4)),
              onScheduleEntryTap: (_) {},
              now: start,
              displayStartHour: 7,
              displayEndHour: 18,
              reminderController: reminders,
            ),
          ),
        ),
      ),
    );

    expect(reminders.maxActiveListeners, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(reminders.activeListeners, 0);
  });
}

class _CountingReminderController extends ChangeNotifier
    implements ClassReminderController {
  int activeListeners = 0;
  int maxActiveListeners = 0;

  @override
  void addListener(VoidCallback listener) {
    activeListeners++;
    if (activeListeners > maxActiveListeners) {
      maxActiveListeners = activeListeners;
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    activeListeners--;
    super.removeListener(listener);
  }

  @override
  bool get permissionsGranted => true;

  @override
  bool get remindersPaused => false;

  @override
  ClassReminderRule? ruleFor(ScheduleEntry entry) {
    if (entry.title != 'Class 0') return null;
    return ClassReminderRule(
      id: 'class-0',
      scope: ClassReminderScope.recurring,
      canonicalTitle: 'Class 0',
      offset: const Duration(minutes: 15),
      sourceIdentity: 'rapla:a',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
