import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:flutter/material.dart';

class CanteenLocationSubtitle extends StatelessWidget {
  final CanteenLocation location;

  const CanteenLocationSubtitle({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final subtitle = location.subtitle;
    final children = <Widget>[
      if (subtitle != null && subtitle.isNotEmpty) Text(subtitle),
      if (location.usesDhbwApp)
        Text(
          L.of(context).canteenPoweredByDhbwApp,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
    ];

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
