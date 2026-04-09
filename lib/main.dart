import 'dart:async';
import 'dart:io';

import 'package:dualmate/ui/root_page.dart';
import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:kiwi/kiwi.dart';
import 'package:flutter/material.dart';

import 'common/util/platform_util.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final Stopwatch _startupStopwatch = Stopwatch()..start();

///
/// Main entry point for the app
///
Future<void> main() async {
  // Setup the flutter bindings and the error reporting as early as possible
  WidgetsFlutterBinding.ensureInitialized();
  PerformanceTelemetry.instance.ensureFrameTimingListenerAttached();
  PerformanceTelemetry.instance.logInstant(
    'startup.binding.ready',
    args: {'elapsedMs': _startupStopwatch.elapsedMilliseconds},
  );
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    reportException(details.exception, details.stack ?? StackTrace.current);
  };

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://c066b6ee9a0627975699781ebdf378bd@o4511192693014528.ingest.de.sentry.io/4511192695046224';
      // Adds request headers and IP for users, for more info visit:
      // https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected/
      options.sendDefaultPii = true;
      options.enableLogs = true;
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // Configure Session Replay
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () => runApp(SentryWidget(child: RootPage(startupStopwatch: _startupStopwatch))),
  );
  // TODO: Remove this line after sending the first sample event to sentry.
  await Sentry.captureException(StateError('This is a sample exception.'));

  // Keep startup non-blocking so Android splash is never held by async setup.
  unawaited(() async {
    try {
      await PlatformUtil.initializePortraitLandscapeMode();
    } catch (error, trace) {
      await reportException(error, trace);
    }
  }());
}

///
/// Save the current language in the preferences.
/// The language of the last app start is used for the background initialization.
/// When the app runs in the background this is an easy way to get the
/// used language
///

Future<void> saveLastStartLanguage() async {
  PreferencesProvider preferencesProvider = KiwiContainer().resolve();
  await preferencesProvider.setLastUsedLanguageCode(Platform.localeName);
}
