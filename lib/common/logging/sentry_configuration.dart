import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');
const String _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');
const String _sentryEnvironment = String.fromEnvironment('SENTRY_ENVIRONMENT');

String get sentryDsn => _sentryDsn.trim();

bool isSentryConfigured({String? dsn}) {
  return (dsn ?? _sentryDsn).trim().isNotEmpty;
}

Future<void> configureSentryOptions(SentryFlutterOptions options) async {
  options.dsn = sentryDsn;
  options.debug = !kReleaseMode;
  options.diagnosticLevel = SentryLevel.debug;
  final trimmedEnvironment = _sentryEnvironment.trim();
  final trimmedRelease = _sentryRelease.trim();
  options.environment = trimmedEnvironment.isNotEmpty
      ? trimmedEnvironment
      : (kReleaseMode ? 'production' : 'debug');
  if (trimmedRelease.isNotEmpty) {
    options.release = trimmedRelease;
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
