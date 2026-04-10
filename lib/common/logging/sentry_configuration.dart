import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const String _defaultSentryDsn =
    'https://c066b6ee9a0627975699781ebdf378bd@o4511192693014528.ingest.de.sentry.io/4511192695046224';
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');
const String _sentryRelease = String.fromEnvironment('SENTRY_RELEASE');
const String _sentryEnvironment = String.fromEnvironment('SENTRY_ENVIRONMENT');

String get sentryDsn =>
    _sentryDsn.trim().isNotEmpty ? _sentryDsn.trim() : _defaultSentryDsn;

bool isSentryConfigured({String? dsn}) {
  return (dsn ?? sentryDsn).trim().isNotEmpty;
}

Future<void> configureSentryOptions(SentryFlutterOptions options) async {
  options.dsn = sentryDsn;
  options.debug = !kReleaseMode;
  options.diagnosticLevel = SentryLevel.debug;
  options.environment = _sentryEnvironment.isNotEmpty
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
