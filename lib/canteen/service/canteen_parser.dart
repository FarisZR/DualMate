import 'package:dualmate/canteen/model/daily_menu.dart';
import 'package:dualmate/canteen/model/meal.dart';
import 'package:dualmate/canteen/model/meal_type.dart';
import 'package:dualmate/canteen/service/allergen_legend.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

class CanteenParser {
  List<DailyMenu> parseWeeklyMenu(String html) {
    var document = parse(html);
    var dailyMenus = <DailyMenu>[];

    for (var i = 1; i <= 5; i++) {
      var navElement = document.getElementById("canteen_day_nav_$i");
      var dayElement = document.getElementById("canteen_day_$i");

      if (navElement == null || dayElement == null) continue;

      var dateString = navElement.attributes["rel"]?.trim();
      if (dateString == null || dateString.isEmpty) continue;

      var parsedDate = DateTime.tryParse(dateString);
      if (parsedDate == null) continue;

      var date = toStartOfDay(parsedDate);
      var meals = _parseDayMeals(dayElement, date);
      dailyMenus.add(DailyMenu(date: date, meals: meals));
    }

    dailyMenus.sort((a, b) => a.date.compareTo(b.date));
    return dailyMenus;
  }

  List<Meal> _parseDayMeals(Element dayElement, DateTime date) {
    var meals = <Meal>[];
    var typeRows = dayElement.getElementsByClassName("mensatype_rows");
    var dayNote = _extractDayNote(dayElement);

    for (var typeRow in typeRows) {
      var category =
          typeRow.getElementsByClassName("mensatype").firstOrNull?.text.trim();

      if (category == null || category.isEmpty) continue;

      var mealBodies = typeRow.querySelectorAll(".meal-detail-table > tbody");
      if (mealBodies.isEmpty) continue;

      var mealRows = mealBodies.first.children;

      for (var index = 0; index < mealRows.length; index++) {
        var mealRow = mealRows[index];
        var titleElement =
            mealRow.getElementsByClassName("menu-title").firstOrNull;

        if (titleElement == null) continue;

        if (_isDayNote(titleElement.text)) {
          continue;
        }

        var mealTypes = _parseMealTypes(mealRow);
        var notes = <String>[];
        if (dayNote != null) {
          notes.add(dayNote);
        }
        var title = _extractTitleAndNotes(titleElement.text, notes);

        var priceText =
            mealRow.getElementsByClassName("price_1").firstOrNull?.text;

        var price = _parsePrice(priceText);
        if (price == null || title.isEmpty) continue;

        meals.add(Meal(
          date: date,
          name: title,
          category: category,
          price: price,
          notes: notes,
          mealTypes: mealTypes,
        ));
      }
    }

    return meals;
  }

  List<MealType> _parseMealTypes(Element mealRow) {
    var mealTypes = <MealType>[];
    var icons = mealRow.getElementsByTagName("img");

    for (var icon in icons) {
      var title = icon.attributes["title"] ?? "";
      var mealType = _mealTypeFromTitle(title);

      if (mealType != null && !mealTypes.contains(mealType)) {
        mealTypes.add(mealType);
      }
    }

    return mealTypes;
  }

  MealType? _mealTypeFromTitle(String title) {
    var normalized = title.toLowerCase();

    if (normalized.contains("vegan")) {
      return MealType.vegan;
    }
    if (normalized.contains("vegetar")) {
      return MealType.vegetarian;
    }
    if (normalized.contains("schweinefleisch")) {
      return MealType.pork;
    }
    if (normalized.contains("rindfleisch")) {
      return MealType.beef;
    }
    if (normalized.contains("geflügel") || normalized.contains("gefluegel")) {
      return MealType.poultry;
    }
    if (normalized.contains("msc")) {
      return MealType.fish;
    }
    if (normalized.contains("mensavital")) {
      return MealType.healthy;
    }

    return null;
  }

  String _extractTitleAndNotes(String titleWithExtras, List<String> notes) {
    var match = RegExp(r"\[(.+?)\]").firstMatch(titleWithExtras);

    if (match == null) return titleWithExtras.trim();

    var codes = match.group(1)?.split(",") ?? [];
    for (var code in codes) {
      var trimmed = code.trim();
      if (trimmed.isEmpty) continue;
      notes.add(AllergenLegend.resolve(trimmed) ?? trimmed);
    }

    return titleWithExtras.replaceRange(match.start, match.end, "").trim();
  }

  double? _parsePrice(String? priceText) {
    if (priceText == null) return null;

    var match = RegExp(r"\d+(?:[\.,]\d+)?").firstMatch(priceText);
    if (match == null) return null;

    var normalized = match.group(0)?.replaceAll(",", ".");
    if (normalized == null || normalized.isEmpty) return null;

    return double.tryParse(normalized);
  }

  String? _extractDayNote(Element dayElement) {
    for (var titleElement in dayElement.getElementsByClassName("menu-title")) {
      if (_isDayNote(titleElement.text)) {
        return "Apfel oder Salat inklusive";
      }
    }

    return null;
  }

  bool _isDayNote(String text) {
    var normalized = text.toLowerCase();
    return normalized
            .contains("zu jedem gericht reichen wir apfel oder salat") ||
        normalized
            .contains("zu diesem gericht reichen wir frisches obst oder salat");
  }
}

extension _ElementListExtension on List<Element> {
  Element? get firstOrNull => isEmpty ? null : first;
}
