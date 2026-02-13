import 'package:dualmate/canteen/ui/canteen_page.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold startup allows immediate canteen interactions',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      {
        PreferencesProvider.IsFirstStartKey: false,
        PreferencesProvider.ScheduleSourceType: ScheduleSourceType.Rapla.index,
        PreferencesProvider.RaplaUrlKey: '',
        PreferencesProvider.DontShowRateNowDialog: true,
        PreferencesProvider.DidShowWidgetHelpDialog: true,
      },
    );

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _dismissBlockingDialogs(tester);

    await _openDrawer(tester);
    final canteenDrawerItem = find.byKey(
      const ValueKey<String>('drawer_item_1'),
    );
    expect(canteenDrawerItem, findsOneWidget);
    await tester.tap(canteenDrawerItem, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _dismissBlockingDialogs(tester);

    expect(find.byType(CanteenPage), findsOneWidget);

    final pageViewFinder = find.byType(PageView);
    if (pageViewFinder.evaluate().isNotEmpty) {
      await tester.fling(pageViewFinder.first, const Offset(-320, 0), 1400);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      await tester.fling(pageViewFinder.first, const Offset(320, 0), 1400);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      await tester.fling(pageViewFinder.first, const Offset(-320, 0), 1400);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
    }

    expect(find.byType(CanteenPage), findsOneWidget);
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
  final menuByTooltip = find.byTooltip('Open navigation menu');
  if (menuByTooltip.evaluate().isNotEmpty) {
    await tester.tap(menuByTooltip.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 450));
    return;
  }

  final menuByIcon = find.byIcon(Icons.menu);
  if (menuByIcon.evaluate().isNotEmpty) {
    await tester.tap(menuByIcon.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 450));
  }
}
