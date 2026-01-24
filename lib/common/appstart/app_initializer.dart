import 'dart:io';

import 'package:dhbwstudentapp/canteen/business/canteen_provider.dart';
import 'package:dhbwstudentapp/common/appstart/background_initialize.dart';
import 'package:dhbwstudentapp/common/appstart/localization_initialize.dart';
import 'package:dhbwstudentapp/common/appstart/notification_schedule_changed_initialize.dart';
import 'package:dhbwstudentapp/common/appstart/notifications_initialize.dart';
import 'package:dhbwstudentapp/common/appstart/service_injector.dart';
import 'package:dhbwstudentapp/common/data/preferences/preferences_provider.dart';
import 'package:dhbwstudentapp/common/util/rapla_tls_override.dart';
import 'package:dhbwstudentapp/native/widget/widget_update_callback.dart';
import 'package:dhbwstudentapp/schedule/background/calendar_synchronizer.dart';
import 'package:dhbwstudentapp/schedule/business/schedule_provider.dart';
import 'package:dhbwstudentapp/schedule/business/schedule_source_provider.dart';
import 'package:kiwi/kiwi.dart';
import 'package:timezone/data/latest.dart' as tz;

bool isInitialized = false;
bool isBaseInitialized = false;

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

  tz.initializeTimeZones();
  print("Base init: time zones ${stopwatch.elapsedMilliseconds}ms");

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

  if (!isBackground) {
    try {
      await KiwiContainer()
          .resolve<CanteenProvider>()
          .refreshWeek(DateTime.now());
      print(
          "Background init: canteen refresh ${stopwatch.elapsedMilliseconds}ms");
    } catch (exception, trace) {
      print("Background init: canteen refresh failed");
      print(exception);
      print(trace);
    }
  }

  if (isBackground) {
    var setup = KiwiContainer().resolve<ScheduleSourceProvider>();
    setup.setupScheduleSource();
    print(
        "Background init: schedule source ${stopwatch.elapsedMilliseconds}ms");
  }

  // Callback-Function for synchronizing the device calendar with the schedule, when schedule is updated
  CalendarSynchronizer calendarSynchronizer = new CalendarSynchronizer(
      KiwiContainer().resolve<ScheduleProvider>(),
      KiwiContainer().resolve<ScheduleSourceProvider>(),
      KiwiContainer().resolve<PreferencesProvider>());

  calendarSynchronizer.registerSynchronizationCallback();
  calendarSynchronizer.scheduleSyncInAFewSeconds();
  print("Background init: calendar sync ${stopwatch.elapsedMilliseconds}ms");

  isInitialized = true;
  print("Initialization finished ${stopwatch.elapsedMilliseconds}ms");
}

///
/// Initializes the app for foreground or background use. After this call
/// everything will be loaded and the startup process is completed
///
Future<void> initializeApp(bool isBackground) async {
  await initializeAppBackground(isBackground);
}
