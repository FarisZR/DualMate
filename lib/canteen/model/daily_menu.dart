import 'package:dhbwstudentapp/canteen/model/meal.dart';

class DailyMenu {
  final DateTime date;
  final List<Meal> meals;

  DailyMenu({
    required this.date,
    required this.meals,
  });
}
