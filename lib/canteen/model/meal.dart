import 'package:dhbwstudentapp/canteen/model/meal_type.dart';

class Meal {
  int? id;
  final DateTime date;
  final String name;
  final String category;
  final double price;
  final List<String> notes;
  final List<MealType> mealTypes;

  Meal({
    this.id,
    required this.date,
    required this.name,
    required this.category,
    required this.price,
    required this.notes,
    required this.mealTypes,
  });

  String get formattedPrice => price.toStringAsFixed(2);
}
