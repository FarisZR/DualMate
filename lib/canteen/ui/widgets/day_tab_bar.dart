import 'package:dhbwstudentapp/common/i18n/localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DayTabBar extends StatelessWidget {
  final TabController controller;
  final List<DateTime> days;
  final ValueChanged<int> onTap;

  const DayTabBar({
    Key? key,
    required this.controller,
    required this.days,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var locale = L.of(context).locale.toString();
    var dayFormat = DateFormat.E(locale);
    var dateFormat = DateFormat.d(locale);

    return TabBar(
      controller: controller,
      onTap: onTap,
      labelColor: Theme.of(context).colorScheme.onSurface,
      tabs: days
          .map((day) => Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dayFormat.format(day)),
                    const SizedBox(height: 4),
                    Text(dateFormat.format(day)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
