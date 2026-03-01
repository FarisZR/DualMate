import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/date_management/ui/date_management_page.dart';
import 'package:dualmate/dualis/ui/dualis_page.dart';
import 'package:dualmate/main.dart' as app;
import 'package:dualmate/ui/onboarding/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('post-onboarding first drawer navigation stays stable',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      {
        PreferencesProvider.IsFirstStartKey: true,
        PreferencesProvider.DontShowRateNowDialog: true,
        PreferencesProvider.DidShowWidgetHelpDialog: true,
      },
    );

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await _finishOnboardingWithNoneSource(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _dismissBlockingDialogs(tester);

    await _openDrawer(tester);
    final dualisDrawerItem =
        find.byKey(const ValueKey<String>('drawer_item_2'));
    expect(dualisDrawerItem, findsOneWidget);
    await tester.tap(dualisDrawerItem, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _dismissBlockingDialogs(tester);
    expect(find.byType(DualisPage), findsOneWidget);

    await _openDrawer(tester);
    final datesDrawerItem = find.byKey(const ValueKey<String>('drawer_item_3'));
    expect(datesDrawerItem, findsOneWidget);
    await tester.tap(datesDrawerItem, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _dismissBlockingDialogs(tester);
    expect(find.byType(DateManagementPage), findsOneWidget);
  });
}

Future<void> _finishOnboardingWithNoneSource(WidgetTester tester) async {
  final onboardingFinder = find.byType(OnboardingPage);
  if (onboardingFinder.evaluate().isEmpty) {
    return;
  }

  final radioTiles = find.byType(RadioListTile);
  if (radioTiles.evaluate().isNotEmpty) {
    await tester.tap(radioTiles.last, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 450));
  }

  for (var i = 0; i < 6; i++) {
    if (onboardingFinder.evaluate().isEmpty) {
      return;
    }

    final actionButtons = find.byType(TextButton);
    if (actionButtons.evaluate().isEmpty) {
      break;
    }

    await tester.tap(actionButtons.last, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
  }
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
