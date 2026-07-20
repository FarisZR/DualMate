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

  testWidgets('missed reminder notice uses English locale and actions', (
    tester,
  ) async {
    final reminders = _FakeReminderController()..missed = true;
    await tester.pumpWidget(_app(reminders));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('A class reminder may have been missed'), findsOneWidget);
    expect(
      find.text(
        'Your phone may be restricting DualMate in the background. Allow unrestricted battery usage to improve reminder reliability.',
      ),
      findsOneWidget,
    );
    expect(find.text('Battery settings'), findsOneWidget);
    expect(
      find.text('Eine Erinnerung wurde möglicherweise verpasst'),
      findsNothing,
    );

    await tester.tap(find.text('Battery settings'));
    await tester.pump();
    expect(reminders.batterySettingsOpens, 1);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(reminders.dismissals, 1);
  });

  testWidgets('missed reminder notice uses German locale only', (tester) async {
    final reminders = _FakeReminderController()..missed = true;
    await tester.pumpWidget(_app(reminders, locale: const Locale('de')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Eine Erinnerung wurde möglicherweise verpasst'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Dein Smartphone schränkt DualMate möglicherweise im Hintergrund ein. Erlaube eine uneingeschränkte Akkunutzung, damit Erinnerungen zuverlässiger funktionieren.',
      ),
      findsOneWidget,
    );
    expect(find.text('Akkueinstellungen'), findsOneWidget);
    expect(find.text('A class reminder may have been missed'), findsNothing);
    expect(find.byTooltip('Schließen'), findsOneWidget);
  });

  testWidgets('paused permission notice takes precedence over missed notice', (
    tester,
  ) async {
    final reminders = _FakeReminderController()
      ..paused = true
      ..missed = true;
    await tester.pumpWidget(_app(reminders));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Class reminders are paused'), findsOneWidget);
    expect(
      find.text('A class reminder may have been missed').hitTestable(),
      findsNothing,
    );
  });

  testWidgets('missed notice preserves schedule state without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final reminders = _FakeReminderController();
    await tester.pumpWidget(_app(reminders, textScale: 1.3));
    final stateBefore = tester.state<_StableScheduleState>(
      find.byType(_StableSchedule),
    );

    reminders.missed = true;
    reminders.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(
      tester.state<_StableScheduleState>(find.byType(_StableSchedule)),
      same(stateBefore),
    );

    reminders.missed = false;
    reminders.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(
      tester.state<_StableScheduleState>(find.byType(_StableSchedule)),
      same(stateBefore),
    );
  });
}

Widget _app(
  ClassReminderController reminders, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('de')],
  localizationsDelegates: const [
    LocalizationDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
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
  bool missed = false;
  int dismissals = 0;
  int batterySettingsOpens = 0;

  @override
  bool get remindersPaused => paused;

  @override
  bool get hasLikelyMissedReminder => missed;

  @override
  bool get permissionsGranted => !paused;

  @override
  bool get isInitialized => true;

  @override
  ClassReminderRule? ruleFor(ScheduleEntry entry) => null;

  @override
  Future<void> openReliablePermissionSettings() async {}

  @override
  void dismissLikelyMissedReminder() {
    dismissals++;
    missed = false;
  }

  @override
  Future<void> openBatterySettingsForMissedReminder() async {
    batterySettingsOpens++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
