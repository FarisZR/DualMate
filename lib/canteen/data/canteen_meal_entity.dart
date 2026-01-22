import 'dart:convert';

import 'package:dhbwstudentapp/canteen/model/meal.dart';
import 'package:dhbwstudentapp/canteen/model/meal_type.dart';
import 'package:dhbwstudentapp/common/data/database_entity.dart';

class CanteenMealEntity extends DatabaseEntity {
  late Meal _meal;

  CanteenMealEntity.fromModel(Meal meal) {
    _meal = meal;
  }

  CanteenMealEntity.fromMap(Map<String, dynamic> map) {
    fromMap(map);
  }

  @override
  void fromMap(Map<String, dynamic> map) {
    var notesValue = map["notes"]?.toString();
    var decodedNotes = <String>[];

    if (notesValue != null && notesValue.isNotEmpty) {
      var parsed = jsonDecode(notesValue);
      if (parsed is List) {
        decodedNotes = parsed.map((entry) => entry.toString()).toList();
      }
    }

    var date = DateTime.fromMillisecondsSinceEpoch(map["date"] ?? 0);

    var priceValue = map["price"];
    var price = 0.0;

    if (priceValue is num) {
      price = priceValue.toDouble();
    } else if (priceValue is String) {
      price = double.tryParse(priceValue) ?? 0.0;
    }

    _meal = Meal(
      id: map["id"],
      date: date,
      name: map["name"] ?? "",
      category: map["category"] ?? "",
      price: price,
      notes: decodedNotes,
      mealTypes: mealTypesFromStorage(map["meal_types"]?.toString()),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      "id": _meal.id,
      "date": _meal.date.millisecondsSinceEpoch,
      "name": _meal.name,
      "category": _meal.category,
      "price": _meal.price,
      "notes": jsonEncode(_meal.notes),
      "meal_types": mealTypesToStorage(_meal.mealTypes),
    };
  }

  Meal asMeal() => _meal;

  static String tableName() => "canteen_meals";
}
