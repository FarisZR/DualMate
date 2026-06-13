import 'package:dualmate/common/logging/sentry_scrubber.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';

void main() {
  test('credentials are redacted from diagnostics maps', () {
    final sanitized = sanitizeDiagnosticsMap({
      'username': 'student@example.com',
      'password': 'correct-horse-battery-staple',
      'authToken': 'secret-token',
      'cookie': 'sid=abc',
      'feature': 'startup',
    });

    expect(sanitized['username'], sentryRedactedValue);
    expect(sanitized['password'], sentryRedactedValue);
    expect(sanitized['authToken'], sentryRedactedValue);
    expect(sanitized['cookie'], sentryRedactedValue);
    expect(sanitized['feature'], 'startup');
  });

  test('URLs lose query parameters', () {
    final sanitized = sanitizeDiagnosticsMap({
      'endpoint': 'https://example.com/path?token=secret&course=WDCM21B1',
      'nested': {
        'callback': Uri.parse(
          'https://dualis.example.test/results?session=secret#grades',
        ),
      },
    });

    expect(sanitized['endpoint'], 'https://example.com/path');
    expect(
      (sanitized['nested'] as Map<String, Object?>)['callback'],
      'https://dualis.example.test/results',
    );
  });

  test('Dualis, grade, and schedule fields are redacted', () {
    final sanitized = sanitizeDiagnosticsMap({
      'dualis': {'student': 'Jane Example'},
      'grade': '1.3',
      'scheduleEventTitle': 'Private appointment',
      'room': 'A.1.23',
      'technicalPhase': 'startup',
    });

    expect(sanitized['dualis'], sentryRedactedValue);
    expect(sanitized['grade'], sentryRedactedValue);
    expect(sanitized['scheduleEventTitle'], sentryRedactedValue);
    expect(sanitized['room'], sentryRedactedValue);
    expect(sanitized['technicalPhase'], 'startup');
  });

  test('normal technical fields and generic route names remain', () {
    final sanitized = sanitizeDiagnosticsMap({
      'appVersion': '2.0.1+42',
      'platform': 'android',
      'buildMode': 'release',
      'route': 'schedule',
      'transaction': 'dualis',
    });

    expect(sanitized['appVersion'], '2.0.1+42');
    expect(sanitized['platform'], 'android');
    expect(sanitized['buildMode'], 'release');
    expect(sanitized['route'], 'schedule');
    expect(sanitized['transaction'], 'dualis');
    expect(
      sanitizeRouteName('/schedule/2026-06-13?payload=secret'),
      'schedule',
    );
    expect(sanitizeRouteName('/student/jane@example.com'), 'unknown');
  });

  test('beforeSend removes user and scrubs event payloads', () {
    final event = SentryEvent(
      message: SentryMessage('Schedule failed for jane@example.com'),
      transaction: '/dualis/results?student=jane',
      user: SentryUser(id: 'raw-user-id'),
      tags: {'feature': 'schedule', 'platform': 'android'},
      // ignore: deprecated_member_use
      extra: {
        'rawUrl': 'https://rapla.example.test/calendar?token=secret',
        'buildMode': 'release',
      },
      request: SentryRequest(
        url: 'https://example.test/api?authorization=secret',
        cookies: 'sid=secret',
        headers: {'Authorization': 'Bearer secret', 'Accept': 'json'},
        data: {'password': 'secret'},
      ),
      breadcrumbs: [
        Breadcrumb(
          message: 'route with schedule payload',
          data: {'room': 'A.1.23', 'source': 'navigator'},
        ),
      ],
      exceptions: [
        SentryException(
          type: 'StateError',
          value: 'Dualis grade parse failed: 1.3',
        ),
      ],
    )..contexts['dualis'] = {'grade': '1.3'};

    final scrubbed = scrubSentryEvent(event, Hint())!;

    expect(scrubbed.user, isNull);
    expect(scrubbed.transaction, 'dualis');
    expect(scrubbed.message!.formatted, sentryRedactedValue);
    expect(scrubbed.tags!['feature'], 'schedule');
    expect(scrubbed.tags!['platform'], 'android');
    // ignore: deprecated_member_use
    expect(scrubbed.extra!['rawUrl'], sentryRedactedValue);
    expect(scrubbed.request!.url, 'https://example.test/api');
    expect(scrubbed.request!.queryString, isEmpty);
    expect(scrubbed.request!.cookies, isNull);
    expect(scrubbed.request!.headers['Authorization'], sentryRedactedValue);
    expect(scrubbed.request!.data, isNull);
    expect(scrubbed.breadcrumbs!.single.message, sentryRedactedValue);
    expect(scrubbed.breadcrumbs!.single.data!['room'], sentryRedactedValue);
    expect(scrubbed.exceptions!.single.value, sentryRedactedValue);
    expect(scrubbed.contexts['dualis'], sentryRedactedValue);
  });

  test('route settings sanitizer keeps only stable route names', () {
    final sanitized = sanitizeSentryRouteSettings(
      const RouteSettings(
        name: '/canteen/day?date=2026-06-13',
        arguments: {'payload': 'menu details'},
      ),
    );

    expect(sanitized!.name, 'canteen');
    expect(sanitized.arguments, isNull);
  });
}
