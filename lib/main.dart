import 'dart:async';

import 'package:dualmate/ui/root_page.dart';
import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/logging/sentry_configuration.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'common/util/platform_util.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Registers the upstream DHBWStudentInformationApp license (AGPL v3) so that it
/// is listed alongside the Flutter package licenses in the "View licenses" page.
void _registerAdditionalLicenses() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/licenses/DHBWStudentInformationApp_LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(['DHBWStudentInformationApp'], license);
  });
}

final Stopwatch _startupStopwatch = Stopwatch()..start();

///
/// Main entry point for the app
///
Future<void> main() async {
  // Setup the flutter bindings and the error reporting as early as possible
  WidgetsFlutterBinding.ensureInitialized();
  _registerAdditionalLicenses();
  PerformanceTelemetry.instance.ensureFrameTimingListenerAttached();
  PerformanceTelemetry.instance.logInstant(
    'startup.binding.ready',
    args: {'elapsedMs': _startupStopwatch.elapsedMilliseconds},
  );
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    if (!isExpectedScheduleFetchFailure(details.exception)) {
      reportException(details.exception, details.stack ?? StackTrace.current);
    }
  };

  final rootApp = RootPage(startupStopwatch: _startupStopwatch);
  var appStartedViaSentryRunner = false;
  if (isSentryConfigured()) {
    try {
      await SentryFlutter.init(
        configureSentryOptions,
        appRunner: () {
          appStartedViaSentryRunner = true;
          runApp(SentryWidget(child: rootApp));
        },
      );
      await AppDiagnostics.instance.recordInfo(
        'startup',
        'sentry.initialized',
        data: {'elapsedMs': _startupStopwatch.elapsedMilliseconds},
      );
    } catch (error, trace) {
      if (!appStartedViaSentryRunner) {
        runApp(rootApp);
      }
      await reportException(error, trace);
    }
  } else {
    runApp(rootApp);
  }
  // Keep startup non-blocking so Android splash is never held by async setup.
  unawaited(() async {
    try {
      await PlatformUtil.initializePortraitLandscapeMode();
    } catch (error, trace) {
      await reportException(error, trace);
    }
  }());
}
