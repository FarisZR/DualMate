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

  test('URLs are redacted', () {
    final sanitized = sanitizeDiagnosticsMap({
      'endpoint': 'https://example.com/path?token=secret&course=WDCM21B1',
      'nested': {
        'callback': Uri.parse(
          'https://dualis.example.test/results?session=secret#grades',
        ),
      },
    });

    expect(sanitized['endpoint'], sentryRedactedValue);
    expect(
      (sanitized['nested'] as Map<String, Object?>)['callback'],
      sentryRedactedValue,
    );
  });

  test('embedded identifiers in free-form strings are redacted', () {
    expect(
      sanitizeDiagnosticsValue('Bad state: login failed for jane@example.com'),
      'Bad state: login failed for $sentryRedactedValue',
    );
    expect(
      sanitizeDiagnosticsValue(
        'GET https://example.com/path?token=secret failed',
      ),
      'GET $sentryRedactedValue failed',
    );
    expect(
      sanitizeDiagnosticsValue('Authorization: Bearer abc.def-123'),
      'Authorization: $sentryRedactedValue',
    );
    expect(
      sanitizeDiagnosticsValue('request failed id_token=abc.def.ghi'),
      'request failed id_token=$sentryRedactedValue',
    );
    expect(
      sanitizeDiagnosticsValue(
        'jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature failed',
      ),
      'jwt $sentryRedactedValue failed',
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

  test('numeric sensitive fields are redacted', () {
    final sanitized = sanitizeDiagnosticsMap({
      'grade': 1.3,
      'session': 42,
      'scheduleEventCount': 3,
      'buildNumber': 42,
    });

    expect(sanitized['grade'], sentryRedactedValue);
    expect(sanitized['session'], sentryRedactedValue);
    expect(sanitized['scheduleEventCount'], sentryRedactedValue);
    expect(sanitized['buildNumber'], 42);
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

  test(
    'static performance span names remain but sensitive names are redacted',
    () {
      const allowedNames = [
        'schedule.open',
        'schedule.week.change',
        'schedule.cache.read',
        'schedule.entries.filter',
        'schedule.remote.fetch',
        'schedule.remote.parse',
        'schedule.state.apply',
        'schedule.list.build',
        'canteen.open',
        'canteen.cache.read',
        'canteen.remote.fetch',
        'canteen.menu.parse',
        'canteen.state.apply',
        'dualis.open',
        'dualis.login.request',
        'dualis.results.parse',
        'dualis.state.apply',
      ];

      for (final name in allowedNames) {
        expect(sanitizeDiagnosticsName(name), name);
      }

      expect(
        sanitizeDiagnosticsName('schedule.math lecture room A.1.23'),
        sentryRedactedValue,
      );
      expect(
        sanitizeDiagnosticsName('/dualis/results?student=jane@example.com'),
        'dualis',
      );
    },
  );

  test('performance span data keeps numeric and coarse fields only', () {
    final sanitized = sanitizeDiagnosticsMap({
      'entryCount': 42,
      'cachedEntryCount': 12,
      'loadedEntryCount': 30,
      'filteredEntryCount': 20,
      'durationMs': 153,
      'weekOffset': -1,
      'isCacheHit': true,
      'isForcedRefresh': false,
      'sourceType': 'rapla',
      'status': 'success',
      'buildMs': 18,
      'rasterMs': 21,
      'jankyFrameCount': 2,
      'maxBuildMs': 34,
      'maxRasterMs': 28,
      'refreshRateHz': 120,
      'deviceTier': 'high_refresh',
      'room': 'A.1.23',
      'privateUrl': 'https://rapla.example.test?key=secret',
      'username': 'jane@example.com',
      'grade': '1.3',
      'token': 'secret',
    });

    expect(sanitized['entryCount'], 42);
    expect(sanitized['cachedEntryCount'], 12);
    expect(sanitized['loadedEntryCount'], 30);
    expect(sanitized['filteredEntryCount'], 20);
    expect(sanitized['durationMs'], 153);
    expect(sanitized['weekOffset'], -1);
    expect(sanitized['isCacheHit'], isTrue);
    expect(sanitized['isForcedRefresh'], isFalse);
    expect(sanitized['sourceType'], 'rapla');
    expect(sanitized['status'], 'success');
    expect(sanitized['buildMs'], 18);
    expect(sanitized['rasterMs'], 21);
    expect(sanitized['jankyFrameCount'], 2);
    expect(sanitized['maxBuildMs'], 34);
    expect(sanitized['maxRasterMs'], 28);
    expect(sanitized['refreshRateHz'], 120);
    expect(sanitized['deviceTier'], 'high_refresh');
    expect(sanitized['room'], sentryRedactedValue);
    expect(sanitized['privateUrl'], sentryRedactedValue);
    expect(sanitized['username'], sentryRedactedValue);
    expect(sanitized['grade'], sentryRedactedValue);
    expect(sanitized['token'], sentryRedactedValue);
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
          value: 'login failed for jane@example.com',
        ),
      ],
    )..contexts['dualis'] = {'grade': '1.3'};

    final scrubbed = scrubSentryEvent(event, Hint())!;

    expect(scrubbed.user, isNull);
    expect(scrubbed.transaction, 'dualis');
    expect(
      scrubbed.message!.formatted,
      'Schedule failed for $sentryRedactedValue',
    );
    expect(scrubbed.tags!['feature'], 'schedule');
    expect(scrubbed.tags!['platform'], 'android');
    // ignore: deprecated_member_use
    expect(scrubbed.extra!['rawUrl'], sentryRedactedValue);
    expect(scrubbed.request!.url, sentryRedactedValue);
    expect(scrubbed.request!.queryString, isEmpty);
    expect(scrubbed.request!.cookies, isNull);
    expect(scrubbed.request!.headers['Authorization'], sentryRedactedValue);
    expect(scrubbed.request!.data, isNull);
    expect(scrubbed.breadcrumbs!.single.message, sentryRedactedValue);
    expect(scrubbed.breadcrumbs!.single.data!['room'], sentryRedactedValue);
    expect(
      scrubbed.exceptions!.single.value,
      'login failed for $sentryRedactedValue',
    );
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
