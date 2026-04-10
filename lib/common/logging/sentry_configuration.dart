import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');
const String _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');
const String _sentryEnvironment = String.fromEnvironment('SENTRY_ENVIRONMENT');

Future<void> configureSentryOptions(SentryFlutterOptions options) async {
  if (_sentryDsn.isNotEmpty) {
    options.dsn = _sentryDsn;
  } else if (kReleaseMode) {
    debugPrint(
      'SENTRY_DSN is not configured; Sentry events will not be sent in release.',
    );
  }
  options.debug = !const bool.fromEnvironment('dart.vm.product');
  options.environment =
      _sentryEnvironment.isNotEmpty
          ? _sentryEnvironment
          : (kReleaseMode ? 'production' : 'debug');
  if (_sentryRelease.isNotEmpty) {
    options.release = _sentryRelease;
  }
  options.sendDefaultPii = false;
  options.enableLogs = !kReleaseMode;
  options.enableAutoPerformanceTracing = true;
  options.enableFramesTracking = true;
  options.enableAutoSessionTracking = true;
  options.enableNativeCrashHandling = true;
  options.enableUserInteractionBreadcrumbs = true;
  options.enableUserInteractionTracing = true;
  options.attachScreenshot = false;
  options.tracesSampleRate = kReleaseMode ? 0.1 : 1.0;
  options.profilesSampleRate = kReleaseMode ? 0.0 : 1.0;
  options.replay.sessionSampleRate = kReleaseMode ? 0.0 : 0.1;
  options.replay.onErrorSampleRate = kReleaseMode ? 0.2 : 1.0;
}
