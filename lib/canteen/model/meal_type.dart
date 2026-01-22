enum MealType {
  vegan,
  vegetarian,
  pork,
  beef,
  poultry,
  fish,
  healthy,
}

extension MealTypeExtension on MealType {
  String get emoji {
    switch (this) {
      case MealType.vegan:
        return "🌱";
      case MealType.vegetarian:
        return "🥬";
      case MealType.pork:
        return "🐷";
      case MealType.beef:
        return "🐄";
      case MealType.poultry:
        return "🍗";
      case MealType.fish:
        return "🐟";
      case MealType.healthy:
        return "💪";
    }
  }

  String get storageValue => toString().split('.').last;
}

MealType? mealTypeFromStorage(String value) {
  for (var type in MealType.values) {
    if (type.storageValue == value) {
      return type;
    }
  }
  return null;
}

List<MealType> mealTypesFromStorage(String? value) {
  if (value == null || value.trim().isEmpty) return [];
  return value
      .split(',')
      .map((entry) => entry.trim())
      .map(mealTypeFromStorage)
      .whereType<MealType>()
      .toList();
}

String mealTypesToStorage(List<MealType> mealTypes) {
  return mealTypes.map((type) => type.storageValue).join(',');
}
