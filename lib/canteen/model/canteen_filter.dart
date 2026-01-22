import 'package:dhbwstudentapp/canteen/model/meal.dart';
import 'package:dhbwstudentapp/canteen/model/meal_type.dart';

enum CanteenFilter {
  all,
  noPork,
  vegetarian,
  vegan,
}

extension CanteenFilterExtension on CanteenFilter {
  bool allowsMeal(Meal meal) {
    switch (this) {
      case CanteenFilter.all:
        return true;
      case CanteenFilter.noPork:
        return !meal.mealTypes.contains(MealType.pork);
      case CanteenFilter.vegetarian:
        return meal.mealTypes.contains(MealType.vegetarian) ||
            meal.mealTypes.contains(MealType.vegan);
      case CanteenFilter.vegan:
        return meal.mealTypes.contains(MealType.vegan);
    }
  }
}
