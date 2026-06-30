import 'dart:async';
import 'dart:convert';

import 'package:dualmate/canteen/service/dhbw_app_canteen_source.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses one decoded site payload for multiple weeks', () async {
    var requestCount = 0;
    final source = DhbwAppCanteenSource(
      loadSitePayloadResponse: (_, __) async {
        requestCount++;
        return jsonEncode([
          _mensaEntry(7, [
            _menu(DateTime(2026, 6, 1), 'FirstWeekMeal'),
            _menu(DateTime(2026, 6, 8), 'SecondWeekMeal'),
          ]),
        ]);
      },
    );

    final firstWeek = await source.loadWeek('MA', 7, DateTime(2026, 6, 1));
    final secondWeek = await source.loadWeek('MA', 7, DateTime(2026, 6, 8));

    expect(requestCount, 1);
    expect(firstWeek.first.meals.single.name, 'FirstWeekMeal');
    expect(secondWeek.first.meals.single.name, 'SecondWeekMeal');
  });

  test('refreshes the site payload after the cache ttl expires', () async {
    var requestCount = 0;
    var now = DateTime(2026, 6, 1, 12);
    final source = DhbwAppCanteenSource(
      sitePayloadCacheDuration: const Duration(minutes: 5),
      now: () => now,
      loadSitePayloadResponse: (_, __) async {
        requestCount++;
        return jsonEncode([
          _mensaEntry(7, [_menu(DateTime(2026, 6, 1), 'Meal$requestCount')]),
        ]);
      },
    );

    final firstLoad = await source.loadWeek('MA', 7, DateTime(2026, 6, 1));
    now = now.add(const Duration(minutes: 6));
    final secondLoad = await source.loadWeek('MA', 7, DateTime(2026, 6, 1));

    expect(requestCount, 2);
    expect(firstLoad.first.meals.single.name, 'Meal1');
    expect(secondLoad.first.meals.single.name, 'Meal2');
  });

  test('keeps site payload caches separate per site', () async {
    var requestCount = 0;
    final source = DhbwAppCanteenSource(
      loadSitePayloadResponse: (uri, __) async {
        requestCount++;
        return jsonEncode([
          _mensaEntry(7, [_menu(DateTime(2026, 6, 1), uri.pathSegments.last)]),
        ]);
      },
    );

    await source.loadWeek('MA', 7, DateTime(2026, 6, 1));
    await source.loadWeek('CAS', 7, DateTime(2026, 6, 1));

    expect(requestCount, 2);
  });

  test('propagates cancellation to the underlying request token', () async {
    var requestWasCanceled = false;
    var requestCount = 0;
    final requestStarted = Completer<void>();
    final releaseRequest = Completer<void>();
    final source = DhbwAppCanteenSource(
      loadSitePayloadResponse: (_, requestToken) async {
        requestCount++;
        requestStarted.complete();
        await releaseRequest.future;
        requestWasCanceled = requestToken.isCanceled;
        return null;
      },
    );
    final cancellationToken = CancellationToken();

    final load = source.loadWeek(
      'MA',
      7,
      DateTime(2026, 6, 1),
      cancellationToken,
    );
    await requestStarted.future;
    cancellationToken.cancel();
    releaseRequest.complete();

    await expectLater(load, throwsA(isA<OperationCancelledException>()));
    expect(requestWasCanceled, isTrue);
    expect(requestCount, 1);
  });

  test(
    'null response throws ServiceRequestFailed for Sentry suppression',
    () async {
      final source = DhbwAppCanteenSource(
        loadSitePayloadResponse: (_, __) async => null,
      );

      await expectLater(
        source.loadWeek('MA', 7, DateTime(2026, 6, 1)),
        throwsA(isA<ServiceRequestFailed>()),
      );
    },
  );

  test('evicts failed payload fetches so the next request can retry', () async {
    var requestCount = 0;
    final source = DhbwAppCanteenSource(
      loadSitePayloadResponse: (_, __) async {
        requestCount++;
        if (requestCount == 1) {
          return '{invalid json';
        }
        return jsonEncode([
          _mensaEntry(7, [_menu(DateTime(2026, 6, 1), 'RecoveredMeal')]),
        ]);
      },
    );

    await expectLater(
      source.loadWeek('MA', 7, DateTime(2026, 6, 1)),
      throwsA(isA<FormatException>()),
    );
    final menus = await source.loadWeek('MA', 7, DateTime(2026, 6, 1));

    expect(requestCount, 2);
    expect(menus.first.meals.single.name, 'RecoveredMeal');
  });

  test(
    'shares one uncancelled in-flight site request across callers',
    () async {
      var requestCount = 0;
      final requestStarted = Completer<void>();
      final releaseRequest = Completer<void>();
      final source = DhbwAppCanteenSource(
        loadSitePayloadResponse: (_, __) async {
          requestCount++;
          requestStarted.complete();
          await releaseRequest.future;
          return jsonEncode([
            _mensaEntry(7, [_menu(DateTime(2026, 6, 1), 'SharedMeal')]),
          ]);
        },
      );

      final firstLoad = source.loadWeek('MA', 7, DateTime(2026, 6, 1));
      final secondLoad = source.loadWeek('MA', 7, DateTime(2026, 6, 1));
      await requestStarted.future;
      releaseRequest.complete();

      final results = await Future.wait([firstLoad, secondLoad]);

      expect(requestCount, 1);
      expect(results.first.first.meals.single.name, 'SharedMeal');
      expect(results.last.first.meals.single.name, 'SharedMeal');
    },
  );

  test(
    'does not share uncached in-flight requests with caller tokens',
    () async {
      var requestCount = 0;
      final releaseRequests = <Completer<void>>[];
      final source = DhbwAppCanteenSource(
        loadSitePayloadResponse: (_, __) async {
          requestCount++;
          final release = Completer<void>();
          releaseRequests.add(release);
          await release.future;
          return jsonEncode([
            _mensaEntry(7, [_menu(DateTime(2026, 6, 1), 'TokenMeal')]),
          ]);
        },
      );

      final firstLoad = source.loadWeek(
        'MA',
        7,
        DateTime(2026, 6, 1),
        CancellationToken(),
      );
      final secondLoad = source.loadWeek(
        'MA',
        7,
        DateTime(2026, 6, 1),
        CancellationToken(),
      );
      while (releaseRequests.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      for (final release in releaseRequests) {
        release.complete();
      }

      await Future.wait([firstLoad, secondLoad]);

      expect(requestCount, 2);
    },
  );

  test(
    'tokened request bypasses an uncancelled in-flight cache entry',
    () async {
      var requestCount = 0;
      final releaseRequests = <Completer<void>>[];
      final source = DhbwAppCanteenSource(
        loadSitePayloadResponse: (_, __) async {
          requestCount++;
          final release = Completer<void>();
          releaseRequests.add(release);
          await release.future;
          return jsonEncode([
            _mensaEntry(7, [_menu(DateTime(2026, 6, 1), 'Meal$requestCount')]),
          ]);
        },
      );

      final sharedLoad = source.loadWeek('MA', 7, DateTime(2026, 6, 1));
      while (releaseRequests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final tokenedLoad = source.loadWeek(
        'MA',
        7,
        DateTime(2026, 6, 1),
        CancellationToken(),
      );
      while (releaseRequests.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      for (final release in releaseRequests) {
        release.complete();
      }

      await Future.wait([sharedLoad, tokenedLoad]);

      expect(requestCount, 2);
    },
  );

  test('returns an empty week when the requested mensa is missing', () async {
    final source = DhbwAppCanteenSource(
      loadSitePayloadResponse: (_, __) async {
        return jsonEncode([
          _mensaEntry(5, [_menu(DateTime(2026, 6, 1), 'OtherMensaMeal')]),
        ]);
      },
    );

    final menus = await source.loadWeek('MA', 7, DateTime(2026, 6, 1));

    expect(menus, hasLength(5));
    expect(menus.expand((menu) => menu.meals), isEmpty);
  });
}

Map<String, Object?> _mensaEntry(int id, List<Map<String, Object?>> menus) {
  return {
    'mensaInfo': {'id': id},
    'menus': menus,
  };
}

Map<String, Object?> _menu(DateTime date, String mealName) {
  return {
    'date': date.toIso8601String(),
    'mainCourses': [
      {
        'name': mealName,
        'type': 'Hauptgericht',
        'priceStudent': 3.5,
        'allergens': const <String>[],
        'additives': const <String>[],
      },
    ],
  };
}
