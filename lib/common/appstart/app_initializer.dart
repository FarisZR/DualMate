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
  } else {
    await LocalizationInitialize.fromLanguageCode(Platform.localeName)
        .setupLocalizations();
  }
  print("Base init: localizations ${stopwatch.elapsedMilliseconds}ms");
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

  NotificationsInitialize().setupNotifications();
  print("Background init: notifications ${stopwatch.elapsedMilliseconds}ms");
  BackgroundInitialize().setupBackgroundScheduling();
  print("Background init: workmanager ${stopwatch.elapsedMilliseconds}ms");
  NotificationScheduleChangedInitialize().setupNotification();
  print("Background init: schedule notify ${stopwatch.elapsedMilliseconds}ms");

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

Future<void> initializeAppForegroundHeavy() async {
  if (isForegroundHeavyInitialized) {
    return;
  }

  isForegroundHeavyInitialized = true;

  final stopwatch = Stopwatch()..start();
  unawaited(_refreshCanteenInBackground(stopwatch));
  unawaited(_setupCalendarSyncInBackground(stopwatch));
  print("Foreground heavy init scheduled ${stopwatch.elapsedMilliseconds}ms");
}

Future<void> _refreshCanteenInBackground(Stopwatch stopwatch) async {
  try {
    await KiwiContainer()
        .resolve<CanteenProvider>()
        .refreshWeek(DateTime.now());
    print(
        "Foreground heavy init: canteen refresh ${stopwatch.elapsedMilliseconds}ms");
  } on Exception catch (exception, trace) {
    print(
        "Foreground heavy init: canteen refresh failed (${exception.runtimeType})");
    print(exception);
    print(trace);
    // Swallowing here is intentional; we don't want to block startup.
  } catch (error, trace) {
    print("Foreground heavy init: canteen refresh failed");
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

///
/// Initializes the app for foreground or background use. After this call
/// everything will be loaded and the startup process is completed
///
Future<void> initializeApp(bool isBackground) async {
  await initializeAppBackground(isBackground);
}
