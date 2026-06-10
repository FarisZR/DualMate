import 'dart:convert';

import 'package:dualmate/canteen/service/dhbw_app_canteen_source.dart';
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
