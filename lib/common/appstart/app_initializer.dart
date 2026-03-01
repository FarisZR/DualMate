import 'dart:async';
import 'dart:io';

import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/common/appstart/background_initialize.dart';
import 'package:dualmate/common/appstart/localization_initialize.dart';
import 'package:dualmate/common/appstart/notification_schedule_changed_initialize.dart';
import 'package:dualmate/common/appstart/notifications_initialize.dart';
import 'package:dualmate/common/appstart/service_injector.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/util/rapla_tls_override.dart';
import 'package:dualmate/native/widget/widget_update_callback.dart';
import 'package:dualmate/schedule/background/calendar_synchronizer.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:kiwi/kiwi.dart';
import 'package:timezone/data/latest.dart' as tz;

bool isInitialized = false;
bool isBaseInitialized = false;
bool isForegroundHeavyInitialized = false;
bool isForegroundCanteenPrewarmInitialized = false;

bool shouldRequestNotificationPermissionForLaunchCount(int launchCount) {
  return launchCount > 1;
}

Future<void> initializeAppBase(bool isBackground) async {
  if (isBaseInitialized) {
    return;
  }

  final stopwatch = Stopwatch()..start();
  print("Initialize base requested. Is background: $isBackground");

  HttpOverrides.global = RaplaHttpOverrides();
  print("Base init: http overrides ${stopwatch.elapsedMilliseconds}ms");

  injectServices(isBackground);
  print("Base init: services ${stopwatch.elapsedMilliseconds}ms");

  print("Base init: time zones deferred ${stopwatch.elapsedMilliseconds}ms");

  if (isBackground) {
    await LocalizationInitialize.fromPreferences(
      KiwiContainer().resolve<PreferencesProvider>(),
    ).setupLocalizations();
    print("Base init: localizations ${stopwatch.elapsedMilliseconds}ms");
  } else {
    // Foreground UI localizations are provided by LocalizationDelegate.
    // Registering a second localization object in Kiwi here causes avoidable
    // startup work on the first frame path.
    print(
        "Base init: localizations deferred ${stopwatch.elapsedMilliseconds}ms");
  }
  print("Base init finished ${stopwatch.elapsedMilliseconds}ms");

  isBaseInitialized = true;
}

Future<void> initializeAppBackground(bool isBackground) async {
  if (isInitialized) {
    print("Already initialized. Abort.");
    return;
  }

  final stopwatch = Stopwatch()..start();
  await initializeAppBase(isBackground);

  var widgetUpdateCallback = WidgetUpdateCallback(KiwiContainer().resolve());
  widgetUpdateCallback.registerScheduleCallback(KiwiContainer().resolve());
  widgetUpdateCallback.registerCanteenCallback(KiwiContainer().resolve());
  print("Background init: widgets ${stopwatch.elapsedMilliseconds}ms");

  final shouldRequestNotificationPermission =
      await _shouldRequestNotificationRuntimePermission(
    isBackground: isBackground,
  );
  await NotificationsInitialize().setupNotifications(
    requestRuntimePermission: shouldRequestNotificationPermission,
  );
  print("Background init: notifications ${stopwatch.elapsedMilliseconds}ms");
  try {
    await BackgroundInitialize().setupBackgroundScheduling();
    print("Background init: workmanager ${stopwatch.elapsedMilliseconds}ms");
  } on Exception catch (exception, trace) {
    print("Background init: workmanager failed (${exception.runtimeType})");
    print(exception);
    print(trace);
  } catch (error, trace) {
    print("Background init: workmanager failed");
    print(error);
    print(trace);
  }

  try {
    NotificationScheduleChangedInitialize().setupNotification();
    print(
        "Background init: schedule notify ${stopwatch.elapsedMilliseconds}ms");
  } on Exception catch (exception, trace) {
    print("Background init: schedule notify failed (${exception.runtimeType})");
    print(exception);
    print(trace);
  } catch (error, trace) {
    print("Background init: schedule notify failed");
    print(error);
    print(trace);
  }

  tz.initializeTimeZones();
  print("Background init: time zones ${stopwatch.elapsedMilliseconds}ms");

  if (isBackground) {
    var setup = KiwiContainer().resolve<ScheduleSourceProvider>();
    setup.setupScheduleSource();
    print(
        "Background init: schedule source ${stopwatch.elapsedMilliseconds}ms");
  }

  isInitialized = true;
  print("Initialization finished ${stopwatch.elapsedMilliseconds}ms");
}

Future<void> initializeAppForegroundHeavy({
  Future<void> Function()? runCalendarSync,
}) async {
  if (isForegroundHeavyInitialized) {
    return;
  }

  isForegroundHeavyInitialized = true;

  final runCalendar = runCalendarSync ?? initializeForegroundCalendarSyncOnly;
  await runCalendar();
}

Future<void> initializeForegroundCalendarSyncOnly() async {
  final stopwatch = Stopwatch()..start();
  unawaited(_setupCalendarSyncInBackground(stopwatch));
  print("Foreground heavy init scheduled ${stopwatch.elapsedMilliseconds}ms");
}

Future<void> prewarmCanteenIfStale({
  Duration staleAfter = const Duration(hours: 2),
  Future<void> Function()? runCanteenPrewarm,
}) async {
  if (isForegroundCanteenPrewarmInitialized) {
    return;
  }

  isForegroundCanteenPrewarmInitialized = true;

  final prewarm = runCanteenPrewarm ??
      () async {
        final stopwatch = Stopwatch()..start();
        await _prewarmCanteenIfStaleInBackground(
          stopwatch,
          staleAfter: staleAfter,
        );
      };

  await prewarm();
}

Future<void> _prewarmCanteenIfStaleInBackground(
  Stopwatch stopwatch, {
  required Duration staleAfter,
}) async {
  try {
    await KiwiContainer().resolve<CanteenProvider>().refreshWeekIfStale(
          DateTime.now(),
          staleAfter: staleAfter,
          prefetchNextWeek: false,
        );
    print(
        "Foreground canteen prewarm: refresh ${stopwatch.elapsedMilliseconds}ms");
  } on Exception catch (exception, trace) {
    print("Foreground canteen prewarm failed (${exception.runtimeType})");
    print(exception);
    print(trace);
    // Swallowing here is intentional; we don't want to block startup.
  } catch (error, trace) {
    print("Foreground canteen prewarm failed");
    print(error);
    print(trace);
    // Swallowing here is intentional; we don't want to block startup.
  }
}

Future<void> _setupCalendarSyncInBackground(Stopwatch stopwatch) async {
  try {
    CalendarSynchronizer calendarSynchronizer = CalendarSynchronizer(
      KiwiContainer().resolve<ScheduleProvider>(),
      KiwiContainer().resolve<ScheduleSourceProvider>(),
      KiwiContainer().resolve<PreferencesProvider>(),
    );

    calendarSynchronizer.registerSynchronizationCallback();
    calendarSynchronizer.scheduleSyncInAFewSeconds();
    print(
        "Foreground heavy init: calendar sync ${stopwatch.elapsedMilliseconds}ms");
  } on Exception catch (exception, trace) {
    print(
        "Foreground heavy init: calendar sync failed (${exception.runtimeType})");
    print(exception);
    print(trace);
    // Swallowing here is intentional; we don't want to block startup.
  } catch (error, trace) {
    print("Foreground heavy init: calendar sync failed");
    print(error);
    print(trace);
    // Swallowing here is intentional; we don't want to block startup.
  }
}

Future<bool> _shouldRequestNotificationRuntimePermission({
  required bool isBackground,
}) async {
  if (isBackground) {
    return false;
  }

  try {
    final appLaunchCounter = await KiwiContainer()
        .resolve<PreferencesProvider>()
        .getAppLaunchCounter();
    return shouldRequestNotificationPermissionForLaunchCount(appLaunchCounter);
  } catch (_) {
    // Best effort; if we cannot read preferences we keep current behavior.
    return true;
  }
}

///
/// Initializes the app for foreground or background use. After this call
/// everything will be loaded and the startup process is completed
///
Future<void> initializeApp(bool isBackground) async {
  await initializeAppBackground(isBackground);
}
