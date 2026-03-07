import 'package:dualmate/common/appstart/app_initializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    isForegroundHeavyInitialized = false;
    isForegroundCanteenPrewarmInitialized = false;
  });

  test('foreground heavy init runs calendar-only path once', () async {
    var calendarCalls = 0;

    await initializeAppForegroundHeavy(
      runCalendarSync: () async {
        calendarCalls++;
      },
    );
    await initializeAppForegroundHeavy(
      runCalendarSync: () async {
        calendarCalls++;
      },
    );

    expect(calendarCalls, 1);
  });

  test('canteen prewarm runs at most once per process', () async {
    var prewarmCalls = 0;

    await prewarmCanteenIfStale(
      runCanteenPrewarm: () async {
        prewarmCalls++;
      },
    );
    await prewarmCanteenIfStale(
      runCanteenPrewarm: () async {
        prewarmCalls++;
      },
    );

    expect(prewarmCalls, 1);
  });

  test('notification runtime permission is not auto-requested at startup', () {
    expect(shouldAutoRequestNotificationPermissionAtStartup(), isFalse);
  });
}
