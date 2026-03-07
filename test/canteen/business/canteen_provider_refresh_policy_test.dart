import 'dart:async';

import 'package:dualmate/canteen/business/canteen_provider.dart';
import 'package:dualmate/canteen/data/canteen_meal_repository.dart';
import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/service/canteen_scraper.dart';
import 'package:dualmate/common/data/database_access.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refreshWeekIfStale skips network when refreshed recently', () async {
    final database = _InMemoryDatabaseAccess();
    final repository = CanteenMealRepository(database);
    final scraper = _FakeCanteenScraper();
    final provider = CanteenProvider(repository, scraper);
    final monday = DateTime(2026, 2, 9);

    await provider.refreshWeekIfStale(
      monday,
      staleAfter: Duration.zero,
      prefetchNextWeek: false,
    );
    expect(scraper.loadWeekCalls, 1);

    await provider.refreshWeekIfStale(
      monday,
      staleAfter: const Duration(hours: 2),
      prefetchNextWeek: false,
    );

    expect(scraper.loadWeekCalls, 1);
  });

  test('refreshWeekIfStale deduplicates concurrent same-week refresh',
      () async {
    final database = _InMemoryDatabaseAccess();
    final repository = CanteenMealRepository(database);
    final scraper = _FakeCanteenScraper();
    final provider = CanteenProvider(repository, scraper);
    final monday = DateTime(2026, 2, 9);
    final blocker = Completer<void>();

    scraper.blocker = blocker;
    final first = provider.refreshWeekIfStale(
      monday,
      staleAfter: Duration.zero,
      prefetchNextWeek: false,
    );
    final second = provider.refreshWeekIfStale(
      monday,
      staleAfter: Duration.zero,
      prefetchNextWeek: false,
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(scraper.loadWeekCalls, 1);

    blocker.complete();
    await Future.wait([first, second]);
    expect(scraper.loadWeekCalls, 1);
  });

  test('refreshWeek tolerates callbacks removing listeners mid-notify',
      () async {
    final database = _InMemoryDatabaseAccess();
    final repository = CanteenMealRepository(database);
    final scraper = _FakeCanteenScraper();
    final provider = CanteenProvider(repository, scraper);
    final monday = DateTime(2026, 2, 9);
    final callbackOrder = <String>[];

    late final CanteenMenuUpdatedCallback secondCallback;
    secondCallback = (_, __, ___) async {
      callbackOrder.add('second');
    };

    provider.addMenuUpdatedCallback((_, __, ___) async {
      callbackOrder.add('first');
      provider.removeMenuUpdatedCallback(secondCallback);
    });
    provider.addMenuUpdatedCallback(secondCallback);

    await provider.refreshWeekIfStale(
      monday,
      staleAfter: Duration.zero,
      prefetchNextWeek: false,
    );

    expect(callbackOrder, ['first', 'second']);

    callbackOrder.clear();
    await provider.refreshWeek(
      monday.add(const Duration(days: 7)),
    );
    expect(callbackOrder, ['first']);
  });
}

class _FakeCanteenScraper extends CanteenScraper {
  int loadWeekCalls = 0;
  Completer<void>? blocker;

  @override
  Future<List<DailyMenu>> loadWeek(
    DateTime date, [
    CancellationToken? cancellationToken,
  ]) async {
    loadWeekCalls++;
    final pendingBlocker = blocker;
    if (pendingBlocker != null) {
      await pendingBlocker.future;
    }

    final weekStart = toStartOfDay(toMonday(date));
    final mondayMeal = Meal(
      date: weekStart,
      name: 'Meal_${weekStart.day}',
      category: 'Wahlessen 1',
      price: 3.5,
      notes: const <String>[],
      mealTypes: const [],
    );

    return <DailyMenu>[
      DailyMenu(date: weekStart, meals: <Meal>[mondayMeal]),
    ];
  }
}

class _InMemoryDatabaseAccess extends DatabaseAccess {
  final List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  int _idCounter = 0;

  @override
  Future<void> insertBatch(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row);
      map['id'] ??= ++_idCounter;
      _rows.add(map);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> queryRows(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final start = whereArgs![0] as int;
    final end = whereArgs[1] as int;
    final filtered = _rows.where((row) {
      final date = row['date'] as int;
      return date >= start && date < end;
    }).toList();
    filtered.sort((a, b) {
      final byDate = (a['date'] as int).compareTo(b['date'] as int);
      if (byDate != 0) return byDate;
      final byCategory =
          (a['category'] as String).compareTo(b['category'] as String);
      if (byCategory != 0) return byCategory;
      return (a['name'] as String).compareTo(b['name'] as String);
    });
    return filtered.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql,
    List<dynamic> parameters,
  ) async {
    final start = parameters[0] as int;
    final end = parameters[1] as int;
    int? maxDate;

    for (final row in _rows) {
      final date = row['date'] as int;
      if (date < start || date >= end) continue;
      maxDate = maxDate == null ? date : (date > maxDate ? date : maxDate);
    }

    return <Map<String, dynamic>>[
      <String, dynamic>{'last_date': maxDate},
    ];
  }

  @override
  Future<int> deleteWhere(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final start = whereArgs![0] as int;
    final end = whereArgs[1] as int;
    final before = _rows.length;
    _rows.removeWhere((row) {
      final date = row['date'] as int;
      return date >= start && date < end;
    });
    return before - _rows.length;
  }
}
