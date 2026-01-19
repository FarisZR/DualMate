import 'package:flutter/material.dart';

TextStyle textStyleDailyScheduleEntryWidgetProfessor(BuildContext context) =>
    Theme.of(context).textTheme.titleSmall ?? const TextStyle();

TextStyle textStyleDailyScheduleEntryWidgetTitle(BuildContext context) =>
        (Theme.of(context).textTheme.headlineMedium ?? const TextStyle()).copyWith(
            color: Theme.of(context).textTheme.titleLarge?.color,
        );

TextStyle textStyleDailyScheduleEntryWidgetType(BuildContext context) =>
    (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w300,
          letterSpacing: 0.15,
        );

TextStyle textStyleDailyScheduleEntryWidgetTimeStart(BuildContext context) =>
    (Theme.of(context).textTheme.headlineSmall ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        );

TextStyle textStyleDailyScheduleEntryWidgetTimeEnd(BuildContext context) =>
    Theme.of(context).textTheme.titleSmall ?? const TextStyle();

TextStyle textStyleDailyScheduleCurrentDate(BuildContext context) =>
        (Theme.of(context).textTheme.headlineMedium ?? const TextStyle()).copyWith(
            color: Theme.of(context).textTheme.headlineSmall?.color,
        );
TextStyle textStyleDailyScheduleNoEntries(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall ?? const TextStyle();

TextStyle textStyleScheduleEntryWidgetTitle(BuildContext context) =>
    (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.normal,
        );

TextStyle textStyleScheduleEntryBottomPageTitle(BuildContext context) =>
    Theme.of(context).textTheme.titleSmall ?? const TextStyle();

TextStyle textStyleScheduleEntryBottomPageTimeFromTo(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall ?? const TextStyle();

TextStyle textStyleScheduleEntryBottomPageTime(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall ?? const TextStyle();

TextStyle textStyleScheduleEntryBottomPageType(BuildContext context) =>
    (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w300,
        );

TextStyle textStyleScheduleWidgetColumnTitleDay(BuildContext context) =>
    (Theme.of(context).textTheme.titleSmall ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w300,
        );
