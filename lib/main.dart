import 'dart:async';
import 'dart:io';

import 'package:dualmate/ui/root_page.dart';
import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:kiwi/kiwi.dart';
import 'package:flutter/material.dart';

import 'common/util/platform_util.dart';

final Stopwatch _startupStopwatch = Stopwatch()..start();

///
/// Main entry point for the app
///
void main() {
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

  runApp(RootPage(startupStopwatch: _startupStopwatch));

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
