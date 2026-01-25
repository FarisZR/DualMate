import 'dart:io';

import 'package:dualmate/canteen/model/meal_type.dart';
import 'package:dualmate/canteen/service/canteen_parser.dart';
import 'package:test/test.dart';

Future<void> main() async {
  var html = await File(Directory.current.absolute.path +
          '/test/canteen/service/html_resources/mensa_response.html')
      .readAsString();

  test('Canteen parser reads daily menus', () {
    var parser = CanteenParser();
    var menus = parser.parseWeeklyMenu(html);

    expect(menus.length, 1);
    expect(menus[0].date, DateTime(2026, 01, 19));
    expect(menus[0].meals.length, 2);
  });

  test('Canteen parser resolves meal types and allergens', () {
    var parser = CanteenParser();
    var menus = parser.parseWeeklyMenu(html);
    var meal = menus[0].meals[0];

    expect(meal.name, 'Kichererbsen-Curry');
    expect(meal.price, 3.6);
    expect(meal.mealTypes, contains(MealType.vegan));
    expect(meal.notes, contains('Sellerie'));
    expect(meal.notes, contains('Schwefeldioxid/Sulfit'));
    expect(meal.notes, contains('Apfel oder Salat inklusive'));
  });

  test('Canteen parser detects pork meals', () {
    var parser = CanteenParser();
    var menus = parser.parseWeeklyMenu(html);
    var meal = menus[0].meals[1];

    expect(meal.name, 'Kartoffeleintopf');
    expect(meal.mealTypes, contains(MealType.pork));
    expect(meal.notes, contains('Apfel oder Salat inklusive'));
  });
}
