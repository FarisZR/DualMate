import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/date_management/ui/date_management_page.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold startup allows immediate dates navigation and scroll',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      {
        PreferencesProvider.IsFirstStartKey: false,
        PreferencesProvider.ScheduleSourceType: ScheduleSourceType.None.index,
        PreferencesProvider.RaplaUrlKey:
            'https://rapla.dhbw-stuttgart.de/rapla?key=abc',
        PreferencesProvider.UseDhMineForDates: false,
        PreferencesProvider.DontShowRateNowDialog: true,
        PreferencesProvider.DidShowWidgetHelpDialog: true,
      },
    );

    app.main();
    await _pumpAndSettleWithTimeout(
      tester,
      initialDelay: const Duration(seconds: 2),
    );
    await _dismissBlockingDialogs(tester);

    await _openDrawer(tester);
    final datesDrawerItem = find.byKey(
      const ValueKey<String>('drawer_item_date_management'),
    );
    expect(datesDrawerItem, findsOneWidget);

    await tester.tap(datesDrawerItem, warnIfMissed: false);
    await _pumpAndSettleWithTimeout(
      tester,
      initialDelay: const Duration(seconds: 2),
    );
    await _dismissBlockingDialogs(tester);

    expect(find.byType(DateManagementPage), findsOneWidget);

    final scrollables = find.descendant(
      of: find.byType(DateManagementPage),
      matching: find.byType(Scrollable),
    );
    if (scrollables.evaluate().isNotEmpty) {
      await tester.fling(scrollables.first, const Offset(0, -300), 1200);
      await _pumpAndSettleWithTimeout(tester);
    }

    expect(find.byType(DateManagementPage), findsOneWidget);
  });
}

Future<void> _dismissBlockingDialogs(WidgetTester tester) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    final dialogs = find.byType(AlertDialog);
    if (dialogs.evaluate().isEmpty) {
      return;
    }

    final buttons = find.descendant(
      of: dialogs.first,
      matching: find.byType(TextButton),
    );

    if (buttons.evaluate().isEmpty) {
      await _pumpAndSettleWithTimeout(tester);
      continue;
    }

    await tester.tap(buttons.first, warnIfMissed: false);
    await _pumpAndSettleWithTimeout(tester);
  }
}

Future<void> _openDrawer(WidgetTester tester) async {
  final menuByIcon = find.byIcon(Icons.menu);
  final menuByTooltip = find.byTooltip('Open navigation menu');
  if (menuByIcon.evaluate().isNotEmpty) {
    await tester.tap(menuByIcon.first, warnIfMissed: false);
    await _pumpAndSettleWithTimeout(tester);
    return;
  }

  if (menuByTooltip.evaluate().isNotEmpty) {
    await tester.tap(menuByTooltip.first, warnIfMissed: false);
    await _pumpAndSettleWithTimeout(tester);
    return;
  }

  fail('Could not find menu button via Icons.menu or the navigation tooltip.');
}

Future<void> _pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration initialDelay = Duration.zero,
  Duration step = const Duration(milliseconds: 100),
  Duration timeout = const Duration(minutes: 3),
}) async {
  if (initialDelay > Duration.zero) {
    await tester.pump(initialDelay);
  }

  final endTime = tester.binding.clock.fromNowBy(timeout);
  while (tester.binding.hasScheduledFrame) {
    if (tester.binding.clock.now().isAfter(endTime)) {
      throw FlutterError(
        'pumpAndSettle timed out after ${timeout.inSeconds} seconds.',
      );
    }
    await tester.pump(step);
  }

  await tester.pump(step);
}
