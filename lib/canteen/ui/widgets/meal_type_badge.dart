import 'package:dualmate/canteen/model/meal_type.dart';
import 'package:flutter/material.dart';

class MealTypeBadge extends StatelessWidget {
  final List<MealType> mealTypes;

  const MealTypeBadge({
    Key? key,
    required this.mealTypes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mealTypes.isEmpty) {
      return const SizedBox(width: 24);
    }

    var emojiText = mealTypes.map((type) => type.emoji).join(" ");

    return Text(
      emojiText,
      style: const TextStyle(fontSize: 20),
    );
  }
}
