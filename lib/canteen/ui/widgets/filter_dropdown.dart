import 'package:dhbwstudentapp/canteen/model/canteen_filter.dart';
import 'package:dhbwstudentapp/common/i18n/localizations.dart';
import 'package:flutter/material.dart';

class FilterDropdown extends StatelessWidget {
  final CanteenFilter filter;
  final ValueChanged<CanteenFilter> onChanged;

  const FilterDropdown({
    Key? key,
    required this.filter,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<CanteenFilter>(
        value: filter,
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        items: CanteenFilter.values
            .map((entry) => DropdownMenuItem(
                  value: entry,
                  child: Text(_label(context, entry)),
                ))
            .toList(),
      ),
    );
  }

  String _label(BuildContext context, CanteenFilter entry) {
    switch (entry) {
      case CanteenFilter.all:
        return L.of(context).canteenFilterAll;
      case CanteenFilter.noPork:
        return L.of(context).canteenFilterNoPork;
      case CanteenFilter.vegetarian:
        return L.of(context).canteenFilterVegetarian;
      case CanteenFilter.vegan:
        return L.of(context).canteenFilterVegan;
    }
  }
}
