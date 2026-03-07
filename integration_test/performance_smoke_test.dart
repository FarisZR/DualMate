import 'package:dualmate/canteen/ui/canteen_page.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/weekly_schedule_page.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/ui/onboarding/onboarding_page.dart';
import 'package:dualmate/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startup, schedule swipe and canteen navigation stay responsive',
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

    await _finishOnboardingIfVisible(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _dismissBlockingDialogs(tester);

    if (find.byType(WeeklySchedulePage).evaluate().isNotEmpty) {
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final chevronFinder = find.byIcon(Icons.chevron_right);
      if (chevronFinder.evaluate().isNotEmpty) {
        await tester.tap(chevronFinder.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
      }

      final weeklyPageFinder = find.byType(WeeklySchedulePage);
      if (weeklyPageFinder.evaluate().isNotEmpty) {
        await tester.fling(weeklyPageFinder, const Offset(-360, 0), 1400);
        await tester.pumpAndSettle(const Duration(milliseconds: 800));
        await tester.fling(weeklyPageFinder, const Offset(360, 0), 1400);
        await tester.pumpAndSettle(const Duration(milliseconds: 800));
      }
    }

    await _openDrawer(tester);
    final canteenDrawerItem = find.byKey(
      const ValueKey<String>('drawer_item_canteen'),
    );
    expect(canteenDrawerItem, findsOneWidget);
    await tester.tap(canteenDrawerItem, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _dismissBlockingDialogs(tester);

    final canteenFinder = find.byType(CanteenPage);
    expect(canteenFinder, findsOneWidget);

    final pageViewFinder = find.byType(PageView);
    if (pageViewFinder.evaluate().isNotEmpty) {
      await tester.fling(pageViewFinder.first, const Offset(-320, 0), 1200);
      await tester.pumpAndSettle(const Duration(milliseconds: 800));
    }
  });
}

Future<void> _finishOnboardingIfVisible(WidgetTester tester) async {
  final onboardingFinder = find.byType(OnboardingPage);
  if (onboardingFinder.evaluate().isEmpty) {
    return;
  }

  for (var i = 0; i < 8; i++) {
    final actionButtons = find.byType(TextButton);
    if (actionButtons.evaluate().isEmpty) break;
    await tester.tap(actionButtons.last);
    await tester.pumpAndSettle(const Duration(milliseconds: 450));
    if (onboardingFinder.evaluate().isEmpty) {
      break;
    }
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

Future<void> _dismissBlockingDialogs(WidgetTester tester) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    final dialogs = find.byType(AlertDialog);
    if (dialogs.evaluate().isEmpty) return;

    final buttons = find.descendant(
      of: dialogs.first,
      matching: find.byType(TextButton),
    );
    if (buttons.evaluate().isEmpty) {
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      continue;
    }

    await tester.tap(buttons.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 450));
  }
}
