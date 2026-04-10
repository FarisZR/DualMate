import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const String sentryDsn =
    'https://c066b6ee9a0627975699781ebdf378bd@o4511192693014528.ingest.de.sentry.io/4511192695046224';
const String sentryRelease = 'dualmate@2.0.0-beta+39';

Future<void> configureSentryOptions(SentryFlutterOptions options) async {
  options.dsn = sentryDsn;
  options.debug = !const bool.fromEnvironment('dart.vm.product');
  options.environment = kReleaseMode ? 'production' : 'debug';
  options.release = sentryRelease;
  options.sendDefaultPii = true;
  options.enableLogs = true;
  options.enableAutoPerformanceTracing = true;
  options.enableFramesTracking = true;
  options.enableAutoSessionTracking = true;
  options.enableNativeCrashHandling = true;
  options.enableUserInteractionBreadcrumbs = true;
  options.enableUserInteractionTracing = true;
  options.attachScreenshot = true;
  options.tracesSampleRate = 1.0;
  options.profilesSampleRate = 1.0;
  options.replay.sessionSampleRate = 0.1;
  options.replay.onErrorSampleRate = 1.0;
}
