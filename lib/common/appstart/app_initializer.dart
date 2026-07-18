import 'dart:async';
import 'dart:io';

import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/common/appstart/background_initialize.dart';
import 'package:dualmate/common/appstart/performance_fixture_mode.dart';
import 'package:dualmate/common/appstart/performance_fixture_schedule_source.dart';
import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:dualmate/common/appstart/localization_initialize.dart';
import 'package:dualmate/common/appstart/notification_schedule_changed_initialize.dart';
import 'package:dualmate/common/appstart/notifications_initialize.dart';
import 'package:dualmate/common/appstart/notification_settings_state.dart';
import 'package:dualmate/common/appstart/service_injector.dart';
import 'package:dualmate/common/background/task_callback.dart';
import 'package:dualmate/common/background/work_scheduler_service.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/features/local_calendar_feature.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/common/util/rapla_tls_override.dart';
import 'package:dualmate/native/widget/widget_update_callback.dart';
import 'package:dualmate/schedule/background/calendar_synchronizer.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/ui/notification/next_day_information_notification.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:kiwi/kiwi.dart';
import 'package:timezone/data/latest.dart' as tz;

bool isInitialized = false;
bool isBaseInitialized = false;
bool isForegroundHeavyInitialized = false;
bool isForegroundCanteenPrewarmInitialized = false;

bool shouldAutoRequestNotificationPermissionAtStartup() {
  return false;
}

/// Helper that wraps reportCaughtException to ensure reporting failures never throw.
Future<void> _reportNonFatalInitException(
  Object error,
  StackTrace trace, {
  String? message,
  Map<String, String> tags = const <String, String>{},
  Map<String, Object?> contexts = const <String, Object?>{},
}) async {
  try {
    await AppDiagnostics.instance.reportCaughtException(
      error,
      trace,
      message: message,
      tags: tags,
      contexts: contexts,
    );
  } catch (reportError, reportTrace) {
    print("Failed to report exception:");
    print(reportError);
    print(reportTrace);
  }
}

void _updateNotificationSettingsState(
  NotificationSettingsState state, {
  required Object? notificationInitializationError,
  required Object? backgroundInitializationError,
}) {
  if (notificationInitializationError != null) {
    state.markFailed(notificationInitializationError);
    return;
  }

  if (backgroundInitializationError != null) {
    state.markFailed(backgroundInitializationError);
    return;
  }

  final container = KiwiContainer();
  final hasNotificationApi = container.isRegistered<NotificationApi>();
  final hasScheduler = container.isRegistered<WorkSchedulerService>();
  final hasNextDayTask = container.isRegistered<TaskCallback>(
    name: NextDayInformationNotification.name,
  );

  if (!hasNotificationApi || !hasScheduler || !hasNextDayTask) {
    state.markFailed(
      StateError('Notification settings dependencies were not registered.'),
    );
    return;
  }

  final scheduler = container.resolve<WorkSchedulerService>();
  if (!scheduler.isSchedulingAvailable()) {
    state.markUnavailable();
    return;
  }

  state.markReady();
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

  if (isPerformanceFixtureMode) {
    final scheduleSourceProvider = KiwiContainer()
        .resolve<ScheduleSourceProvider>();
    final didConfigureScheduleSource = await scheduleSourceProvider
        .setupScheduleSource();
    if (!didConfigureScheduleSource) {
      throw StateError(
        'Performance fixture mode requires a configured Schedule source.',
      );
    }
    scheduleSourceProvider.usePerformanceFixtureSource(
      PerformanceFixtureScheduleSource(),
    );
    print(
      "Base init: fixture schedule source ${stopwatch.elapsedMilliseconds}ms",
    );
  }

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
      "Base init: localizations deferred ${stopwatch.elapsedMilliseconds}ms",
    );
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

  final notificationSettingsState = KiwiContainer()
      .resolve<NotificationSettingsState>();
  notificationSettingsState.markLoading();

  Object? notificationInitializationError;
  final shouldRequestNotificationPermission =
      shouldAutoRequestNotificationPermissionAtStartup();
  try {
    await NotificationsInitialize().setupNotifications(
      requestRuntimePermission: shouldRequestNotificationPermission,
    );
    print("Background init: notifications ${stopwatch.elapsedMilliseconds}ms");
  } catch (error, trace) {
    notificationInitializationError = error;
    print("Background init: notifications failed (${error.runtimeType})");
    print(error);
    print(trace);
    await _reportNonFatalInitException(
      error,
      trace,
      message: 'Background init: notifications failed',
      tags: {'feature': 'notifications'},
      contexts: {
        'notifications': {'phase': 'plugin.initialize'},
      },
    );
  }

  Object? backgroundInitializationError;
  try {
    await BackgroundInitialize().setupBackgroundScheduling();
    print("Background init: workmanager ${stopwatch.elapsedMilliseconds}ms");
  } catch (error, trace) {
    backgroundInitializationError = error;
    print("Background init: workmanager failed (${error.runtimeType})");
    print(error);
    print(trace);
    await _reportNonFatalInitException(
      error,
      trace,
      message: 'Background init: workmanager failed',
      tags: {'feature': 'background'},
      contexts: {
        'background': {'phase': 'workmanager.setup'},
      },
    );
  }

  _updateNotificationSettingsState(
    notificationSettingsState,
    notificationInitializationError: notificationInitializationError,
    backgroundInitializationError: backgroundInitializationError,
  );

  if (notificationInitializationError == null) {
    try {
      NotificationScheduleChangedInitialize().setupNotification();
      print(
        "Background init: schedule notify ${stopwatch.elapsedMilliseconds}ms",
      );
    } catch (error, trace) {
      print("Background init: schedule notify failed (${error.runtimeType})");
      print(error);
      print(trace);
      await _reportNonFatalInitException(
        error,
        trace,
        message: 'Background init: schedule notify failed',
        tags: {'feature': 'notifications'},
        contexts: {
          'notifications': {'phase': 'schedule_changed.setup'},
        },
      );
    }
  } else {
    print("Background init: schedule notify skipped");
  }

  tz.initializeTimeZones();
  print("Background init: time zones ${stopwatch.elapsedMilliseconds}ms");

  try {
    await KiwiContainer().resolve<ClassReminderController>().initialize();
    print("Background init: reminders ${stopwatch.elapsedMilliseconds}ms");
  } catch (error, trace) {
    await _reportNonFatalInitException(
      error,
      trace,
      message: 'Background init: class reminders failed',
      tags: {'feature': 'class_reminders'},
    );
  }

  if (isBackground) {
    var setup = KiwiContainer().resolve<ScheduleSourceProvider>();
    await setup.setupScheduleSource();
    print(
      "Background init: schedule source ${stopwatch.elapsedMilliseconds}ms",
    );
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
  if (!isLocalCalendarFeatureEnabled) {
    return;
  }

  final stopwatch = Stopwatch()..start();
  unawaited(_setupCalendarSyncInBackground(stopwatch));
  print("Foreground heavy init scheduled ${stopwatch.elapsedMilliseconds}ms");
}

Future<void> prewarmCanteenIfStale({
  Duration staleAfter = const Duration(hours: 2),
  Future<void> Function()? runCanteenPrewarm,
}) async {
  if (isPerformanceFixtureMode) {
    return;
  }
  if (isForegroundCanteenPrewarmInitialized) {
    return;
  }

  isForegroundCanteenPrewarmInitialized = true;

  final prewarm =
      runCanteenPrewarm ??
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
      "Foreground canteen prewarm: refresh ${stopwatch.elapsedMilliseconds}ms",
    );
  } on Exception catch (exception, trace) {
    print("Foreground canteen prewarm failed (${exception.runtimeType})");
    print(exception);
    print(trace);
    await _reportNonFatalInitException(
      exception,
      trace,
      message: 'Foreground canteen prewarm failed',
      tags: {'feature': 'canteen'},
      contexts: {
        'canteen': {'phase': 'foreground_prewarm'},
      },
    );
    // Swallowing here is intentional; we don't want to block startup.
  } catch (error, trace) {
    print("Foreground canteen prewarm failed");
    print(error);
    print(trace);
    await _reportNonFatalInitException(
      error,
      trace,
      message: 'Foreground canteen prewarm failed',
      tags: {'feature': 'canteen'},
      contexts: {
        'canteen': {'phase': 'foreground_prewarm'},
      },
    );
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
      "Foreground heavy init: calendar sync ${stopwatch.elapsedMilliseconds}ms",
    );
  } on Exception catch (exception, trace) {
    print(
      "Foreground heavy init: calendar sync failed (${exception.runtimeType})",
    );
    print(exception);
    print(trace);
    await _reportNonFatalInitException(
      exception,
      trace,
      message: 'Foreground heavy init: calendar sync failed',
      tags: {'feature': 'calendar'},
      contexts: {
        'calendar': {'phase': 'foreground_sync_setup'},
      },
    );
    // Swallowing here is intentional; we don't want to block startup.
  } catch (error, trace) {
    print("Foreground heavy init: calendar sync failed");
    print(error);
    print(trace);
    await _reportNonFatalInitException(
      error,
      trace,
      message: 'Foreground heavy init: calendar sync failed',
      tags: {'feature': 'calendar'},
      contexts: {
        'calendar': {'phase': 'foreground_sync_setup'},
      },
    );
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
