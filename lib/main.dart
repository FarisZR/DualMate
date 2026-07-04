import 'dart:async';

import 'package:dualmate/ui/root_page.dart';
import 'package:dualmate/common/logging/app_diagnostics.dart';
import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/common/logging/performance_telemetry.dart';
import 'package:dualmate/common/logging/sentry_configuration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
const Duration _sentryColdStartDeferral = Duration(seconds: 60);

void _scheduleDeferredSentryInitialization() {
  if (!isSentryConfigured()) {
    return;
  }

  if (kDebugMode) {
    unawaited(_initializeSentryAfterStartup());
    return;
  }

  Timer(_sentryColdStartDeferral, () {
    SchedulerBinding.instance.scheduleTask<void>(
      _initializeSentryAfterStartup,
      Priority.idle,
      debugLabel: 'deferredSentryInitialization',
    );
  });
}

Future<void> _initializeSentryAfterStartup() async {
  if (Sentry.isEnabled) {
    return;
  }

  try {
    await SentryFlutter.init(configureSentryOptions);
    await AppDiagnostics.instance.recordInfo(
      'startup',
      'sentry.initialized',
      data: {'elapsedMs': _startupStopwatch.elapsedMilliseconds},
    );
  } catch (error, trace) {
    if (kDebugMode) {
      debugPrint('Deferred Sentry initialization failed: $error');
      debugPrint('$trace');
    }
  }
}

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
    reportException(details.exception, details.stack ?? StackTrace.current);
  };

  final rootApp = RootPage(startupStopwatch: _startupStopwatch);
  runApp(rootApp);
  _scheduleDeferredSentryInitialization();
  // Keep startup non-blocking so Android splash is never held by async setup.
  unawaited(() async {
    try {
      await PlatformUtil.initializePortraitLandscapeMode();
    } catch (error, trace) {
      await reportException(error, trace);
    }
  }());
}
