import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/ui/widgets/meal_type_badge.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MealCard extends StatelessWidget {
  static final Map<String, NumberFormat> _priceFormatters =
      <String, NumberFormat>{};

  final Meal meal;

  const MealCard({
    Key? key,
    required this.meal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final locale = L.of(context).locale.toString();
    final priceFormatter = _priceFormatters.putIfAbsent(
      locale,
      () => NumberFormat.currency(
        locale: locale,
        symbol: "€",
        decimalDigits: 2,
      ),
    );

    var cardColor = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFE6E6E8)
        : const Color(0xFF2A2A2A);

    return Card(
      elevation: 0,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MealTypeBadge(mealTypes: meal.mealTypes),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _localizedCategory(context),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Text(
                    priceFormatter.format(meal.price),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (meal.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _notesText(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _notesText() {
    var notes = meal.notes.take(4).toList();
    var text = notes.join(" · ");
    if (meal.notes.length > notes.length) {
      text = "$text · …";
    }
    return text;
  }

  String _localizedCategory(BuildContext context) {
    var match = RegExp(r"Wahlessen\s*(\d)").firstMatch(meal.category);
    if (match != null) {
      return L
          .of(context)
          .canteenCategoryWahlessen
          .replaceFirst("%0", match.group(1) ?? "");
    }

    return meal.category;
  }
}
