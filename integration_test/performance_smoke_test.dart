import 'dart:io';

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
    final raplaStubServer = await _startRaplaStubServer();
    final raplaUrl =
        'http://${raplaStubServer.address.address}:${raplaStubServer.port}/rapla?page=calendar&user=USERNAME&file=CLASSID';
    SharedPreferences.setMockInitialValues(
      {
        PreferencesProvider.IsFirstStartKey: false,
        PreferencesProvider.ScheduleSourceType: ScheduleSourceType.Rapla.index,
        PreferencesProvider.RaplaUrlKey: raplaUrl,
      },
    );

    try {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await _finishOnboardingIfVisible(tester);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      if (find.byType(WeeklySchedulePage).evaluate().isNotEmpty) {
        await tester.pumpAndSettle(const Duration(seconds: 2));
        final chevronFinder = find.byIcon(Icons.chevron_right);
        if (chevronFinder.evaluate().isNotEmpty) {
          await tester.tap(chevronFinder.first);
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
        const ValueKey<String>('drawer_item_1'),
      );
      expect(canteenDrawerItem, findsOneWidget);
      await tester.tap(canteenDrawerItem);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final canteenFinder = find.byType(CanteenPage);
      expect(canteenFinder, findsOneWidget);

      final pageViewFinder = find.byType(PageView);
      if (pageViewFinder.evaluate().isNotEmpty) {
        await tester.fling(pageViewFinder.first, const Offset(-320, 0), 1200);
        await tester.pumpAndSettle(const Duration(milliseconds: 800));
      }
    } finally {
      await raplaStubServer.close(force: true);
    }
  });
}

Future<HttpServer> _startRaplaStubServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.html;
    request.response.write('''
<!doctype html>
<html>
  <head><title>Rapla Test Stub</title></head>
  <body>
    <div class="week_table"></div>
  </body>
</html>
''');
    await request.response.close();
  });
  return server;
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
  final menuByTooltip = find.byTooltip('Open navigation menu');
  if (menuByTooltip.evaluate().isNotEmpty) {
    await tester.tap(menuByTooltip.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 450));
    return;
  }

  final menuByIcon = find.byIcon(Icons.menu);
  if (menuByIcon.evaluate().isNotEmpty) {
    await tester.tap(menuByIcon.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 450));
  }
}
