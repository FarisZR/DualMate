import 'dart:convert';

import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/model/meal_type.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:http_client_helper/http_client_helper.dart' as http;

class DhbwAppCanteenSource {
  Future<List<DailyMenu>> loadWeek(
    String site,
    int mensaId,
    DateTime weekStart, [
    CancellationToken? cancellationToken,
  ]) async {
    final token = cancellationToken ?? CancellationToken();
    final requestCancellationToken = http.CancellationToken();

    try {
      token.setCancellationCallback(() {
        requestCancellationToken.cancel();
      });

      final response = await http.HttpClientHelper.get(
        Uri.https('api.dhbw.app', '/mensa/$site'),
        cancelToken: requestCancellationToken,
      );

      if (response == null) {
        if (requestCancellationToken.isCanceled) {
          throw OperationCancelledException();
        }
        throw Exception('DHBW.app canteen request failed');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return _emptyWeek(weekStart);
      }

      final mensaEntry = decoded.whereType<Map<String, dynamic>>().firstWhere(
        (entry) => _mensaInfoId(entry) == mensaId,
        orElse: () => const <String, dynamic>{},
      );
      if (mensaEntry.isEmpty) {
        return _emptyWeek(weekStart);
      }

      return _menusFromEntry(mensaEntry, weekStart);
    } on http.OperationCanceledError catch (_) {
      throw OperationCancelledException();
    } finally {
      token.setCancellationCallback(null);
    }
  }

  int? _mensaInfoId(Map<String, dynamic> entry) {
    final mensaInfo = entry['mensaInfo'];
    if (mensaInfo is! Map) return null;
    final id = mensaInfo['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return null;
  }

  List<DailyMenu> _menusFromEntry(
    Map<String, dynamic> entry,
    DateTime weekStart,
  ) {
    final weekEnd = weekStart.add(const Duration(days: 5));
    final menusByDay = <DateTime, List<Meal>>{};
    final menus = entry['menus'];
    if (menus is List) {
      for (final menu in menus.whereType<Map<String, dynamic>>()) {
        final date = _parseMenuDate(menu['date']);
        if (date == null ||
            date.isBefore(weekStart) ||
            !date.isBefore(weekEnd)) {
          continue;
        }
        final meals = <Meal>[
          ..._mealsFrom(menu, date, 'starters', 'Vorspeise'),
          ..._mealsFrom(menu, date, 'mainCourses', 'Hauptgericht'),
          ..._mealsFrom(menu, date, 'sideOrders', 'Beilage'),
          ..._mealsFrom(menu, date, 'desserts', 'Dessert'),
        ];
        menusByDay[date] = meals;
      }
    }

    return List<DailyMenu>.generate(5, (index) {
      final date = toStartOfDay(weekStart.add(Duration(days: index)));
      return DailyMenu(date: date, meals: menusByDay[date] ?? <Meal>[]);
    });
  }

  Iterable<Meal> _mealsFrom(
    Map<String, dynamic> menu,
    DateTime date,
    String key,
    String fallbackCategory,
  ) {
    final items = menu[key];
    if (items is! List) return const <Meal>[];

    return items.whereType<Map<String, dynamic>>().map((item) {
      final category = item['type']?.toString() ?? fallbackCategory;
      final notes = <String>[
        ..._stringList(item['allergens']),
        ..._stringList(item['additives']),
      ];
      final name = item['name']?.toString() ?? '';
      return Meal(
        date: date,
        name: name,
        category: category,
        price: _price(item),
        notes: notes,
        mealTypes: _mealTypesFrom('$category $name ${notes.join(' ')}'),
      );
    });
  }

  List<String> _stringList(dynamic values) {
    if (values is! List) return const <String>[];
    return values.map((value) => value.toString()).toList();
  }

  double _price(Map<String, dynamic> item) {
    final value =
        item['priceStudent'] ?? item['priceEmployee'] ?? item['priceGuest'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  List<MealType> _mealTypesFrom(String value) {
    final normalized = value.toLowerCase();
    final types = <MealType>[];

    if (normalized.contains('vegan')) {
      types.add(MealType.vegan);
    }
    if (normalized.contains('vegetar')) {
      types.add(MealType.vegetarian);
    }
    if (normalized.contains('gefl') || normalized.contains('chicken')) {
      types.add(MealType.poultry);
    }
    if (normalized.contains('rind') || normalized.contains('beef')) {
      types.add(MealType.beef);
    }
    if (normalized.contains('schwein') || normalized.contains('pork')) {
      types.add(MealType.pork);
    }
    if (normalized.contains('fisch') || normalized.contains('fish')) {
      types.add(MealType.fish);
    }

    return types;
  }

  DateTime? _parseMenuDate(dynamic value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return toStartOfDay(parsed.toLocal());
  }

  List<DailyMenu> _emptyWeek(DateTime weekStart) {
    return List<DailyMenu>.generate(5, (index) {
      final date = toStartOfDay(weekStart.add(Duration(days: index)));
      return DailyMenu(date: date, meals: const <Meal>[]);
    });
  }
}
