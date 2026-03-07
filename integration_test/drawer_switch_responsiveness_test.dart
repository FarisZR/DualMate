import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/date_management/ui/date_management_page.dart';
import 'package:dualmate/dualis/ui/dualis_page.dart';
import 'package:dualmate/main.dart' as app;
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('drawer switch defers heavy page build until close animation',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      {
        PreferencesProvider.IsFirstStartKey: false,
        PreferencesProvider.ScheduleSourceType: ScheduleSourceType.None.index,
        PreferencesProvider.RaplaUrlKey: '',
        PreferencesProvider.UseDhMineForDates: false,
        PreferencesProvider.DontShowRateNowDialog: true,
        PreferencesProvider.DidShowWidgetHelpDialog: true,
      },
    );

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _dismissBlockingDialogs(tester);

    await _openDrawer(tester);
    final dualisDrawerItem =
        find.byKey(const ValueKey<String>('drawer_item_dualis'));
    expect(dualisDrawerItem, findsOneWidget);

    await tester.tap(dualisDrawerItem, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(DualisPage), findsNothing);

    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _dismissBlockingDialogs(tester);
    expect(find.byType(DualisPage), findsOneWidget);

    await _openDrawer(tester);
    final datesDrawerItem =
        find.byKey(const ValueKey<String>('drawer_item_date_management'));
    expect(datesDrawerItem, findsOneWidget);

    await tester.tap(datesDrawerItem, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(DateManagementPage), findsNothing);

    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _dismissBlockingDialogs(tester);
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
      await tester.pumpAndSettle(const Duration(milliseconds: 250));
      continue;
    }

    await tester.tap(buttons.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 450));
  }
}

Future<void> _openDrawer(WidgetTester tester) async {
  final menuByIcon = find.byIcon(Icons.menu);
  final menuByTooltip = find.byTooltip('Open navigation menu');
  if (menuByIcon.evaluate().isNotEmpty) {
    await tester.tap(menuByIcon.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 450));
    return;
  }

  if (menuByTooltip.evaluate().isNotEmpty) {
    await tester.tap(menuByTooltip.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 450));
    return;
  }

  fail('Could not find menu button via Icons.menu or the navigation tooltip.');
}
