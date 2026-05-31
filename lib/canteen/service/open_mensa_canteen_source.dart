import 'dart:convert';

import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/model/meal_type.dart';
import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:http_client_helper/http_client_helper.dart' as http;

class OpenMensaCanteenSource {
  Future<List<DailyMenu>> loadWeek(
    int canteenId,
    DateTime weekStart, [
    CancellationToken? cancellationToken,
  ]) async {
    final token = cancellationToken ?? CancellationToken();
    final requestCancellationToken = http.CancellationToken();

    try {
      token.setCancellationCallback(() {
        requestCancellationToken.cancel();
      });

      final menus = <DailyMenu>[];
      for (var index = 0; index < 5; index++) {
        final day = toStartOfDay(weekStart.add(Duration(days: index)));
        final meals = await _loadDayMeals(
          canteenId,
          day,
          requestCancellationToken,
        );
        menus.add(DailyMenu(date: day, meals: meals));
      }

      return menus;
    } on http.OperationCanceledError catch (_) {
      throw OperationCancelledException();
    } finally {
      token.setCancellationCallback(null);
    }
  }

  Future<List<Meal>> _loadDayMeals(
    int canteenId,
    DateTime day,
    http.CancellationToken requestCancellationToken,
  ) async {
    final response = await http.HttpClientHelper.get(
      Uri.https(
        'openmensa.org',
        '/api/v2/canteens/$canteenId/days/${_formatDate(day)}/meals',
      ),
      cancelToken: requestCancellationToken,
    );

    if (response == null) {
      if (requestCancellationToken.isCanceled) {
        throw OperationCancelledException();
      }
      throw Exception('OpenMensa request failed');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <Meal>[];
    }

    return decoded.whereType<Map<String, dynamic>>().map((entry) {
      final category = entry['category']?.toString() ?? '';
      final notes = (entry['notes'] as List?)
              ?.map((value) => value.toString())
              .toList() ??
          const <String>[];

      return Meal(
        date: day,
        name: entry['name']?.toString() ?? '',
        category: category,
        price: _resolvePrice(entry['prices']),
        notes: notes,
        mealTypes: _mealTypesFrom(category, notes),
      );
    }).toList();
  }

  double _resolvePrice(dynamic prices) {
    if (prices is! Map) return 0;
    final value = prices['students'] ?? prices['employees'] ?? prices['others'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  List<MealType> _mealTypesFrom(String category, List<String> notes) {
    final normalized = '${category.toLowerCase()} ${notes.join(' ').toLowerCase()}';
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

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
