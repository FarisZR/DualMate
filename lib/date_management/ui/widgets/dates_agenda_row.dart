import 'package:dualmate/date_management/ui/theme/dates_agenda_theme.dart';
import 'package:dualmate/date_management/ui/widgets/dates_agenda_layout.dart';
import 'package:dualmate/date_management/ui/widgets/dates_render_data.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';

class ImportantEventAgendaRow extends StatelessWidget {
  final ImportantEventAgendaRowRenderData data;
  final DatesAgendaLayoutSpec layoutSpec;
  final VoidCallback? onTap;
  final bool isInExamWeek;
  final ThemeData? resolvedTheme;

  const ImportantEventAgendaRow({
    super.key,
    required this.data,
    required this.layoutSpec,
    this.onTap,
    this.isInExamWeek = false,
    this.resolvedTheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = resolvedTheme ?? Theme.of(context);
    final agendaTheme =
        theme.extension<DatesAgendaTheme>() ??
        (theme.brightness == Brightness.dark
            ? DatesAgendaTheme.dark
            : DatesAgendaTheme.light);
    final categoryColors = agendaTheme.colorsFor(
      data.event.event.type,
      theme.colorScheme,
    );

    return Semantics(
      container: true,
      label: data.event.semanticsLabel,
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(top: _topSpacing),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: layoutSpec.railWidth,
              child: data.suppressDateRail
                  ? const SizedBox.shrink()
                  : _buildDateRail(
                      event: data.event,
                      color: categoryColors.accent,
                      textTheme: theme.textTheme,
                    ),
            ),
            Expanded(
              child: DecoratedBox(
                key: const Key('dates_agenda_rail_divider'),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: agendaTheme.divider, width: 1),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: layoutSpec.gap + (isInExamWeek ? 12 : 0),
                  ),
                  child: _buildEventSurface(
                    event: data.event,
                    colors: categoryColors,
                    showCategoryIcon: layoutSpec.showCategoryIcon,
                    textTheme: theme.textTheme,
                    onTap: onTap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _topSpacing {
    switch (data.spacingRole) {
      case AgendaRowSpacingRole.first:
      case AgendaRowSpacingRole.afterSectionHeading:
        return 0;
      case AgendaRowSpacingRole.sameDayContinuation:
        return 8;
      case AgendaRowSpacingRole.normalDateChange:
        return 12;
      case AgendaRowSpacingRole.distantDateChange:
        return 28;
    }
  }
}

Widget _buildDateRail({
  required ImportantEventRenderData event,
  required Color color,
  required TextTheme textTheme,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: color),
      textAlign: TextAlign.center,
      child: _buildDateContent(event: event, textTheme: textTheme),
    ),
  );
}

Widget _buildDateContent({
  required ImportantEventRenderData event,
  required TextTheme textTheme,
}) {
  switch (event.rangeStyle) {
    case ImportantEventRangeStyle.singleDay:
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(event.weekday, style: textTheme.labelMedium),
          Text(
            event.startDay,
            style: textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(event.startMonth, style: textTheme.labelMedium),
          if (event.startYear != null)
            Text(event.startYear!, style: textTheme.labelSmall),
        ],
      );
    case ImportantEventRangeStyle.sameMonth:
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(event.weekday, style: textTheme.labelMedium),
          Text(
            '${event.startDay.padLeft(2, '0')}–${event.endDay}',
            style: textTheme.titleLarge,
          ),
          Text(event.startMonth, style: textTheme.labelMedium),
          if (event.startYear != null)
            Text(event.startYear!, style: textTheme.labelSmall),
        ],
      );
    case ImportantEventRangeStyle.crossMonth:
    case ImportantEventRangeStyle.crossYear:
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildRangeEndpoint(
            day: event.startDay.padLeft(2, '0'),
            month: event.startMonth,
            year: event.startYear,
            textTheme: textTheme,
          ),
          const SizedBox(height: 4),
          _buildRangeEndpoint(
            day: event.endDay!,
            month: event.endMonth!,
            year: event.endYear,
            textTheme: textTheme,
          ),
        ],
      );
  }
}

Widget _buildRangeEndpoint({
  required String day,
  required String month,
  required String? year,
  required TextTheme textTheme,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(day, style: textTheme.titleLarge),
      Text(month, style: textTheme.labelMedium),
      if (year != null) Text(year, style: textTheme.labelSmall),
    ],
  );
}

Widget _buildEventSurface({
  required ImportantEventRenderData event,
  required DatesAgendaCategoryColors colors,
  required bool showCategoryIcon,
  required TextTheme textTheme,
  required VoidCallback? onTap,
}) {
  return Material(
    key: const Key('dates_agenda_event_surface'),
    type: MaterialType.card,
    elevation: 0,
    clipBehavior: Clip.none,
    color: colors.container,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      onTap: onTap,
      excludeFromSemantics: true,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showCategoryIcon) ...<Widget>[
              _buildCategoryIcon(
                key: const Key('dates_agenda_category_icon'),
                category: event.event.type,
                colors: colors,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    event.event.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w600,
                      decoration: event.isPast
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (event.timeText != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      event.timeText!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                  ],
                  if (event.event.professor.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      event.event.professor,
                      key: const Key('important_event_professor_text'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildCategoryIcon({
  required Key key,
  required ScheduleEntryType category,
  required DatesAgendaCategoryColors colors,
}) {
  final fill = Color.alphaBlend(
    colors.accent.withValues(alpha: 0.12),
    colors.container,
  );
  return Container(
    key: key,
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
    child: Icon(_iconFor(category), color: colors.accent, size: 20),
  );
}

IconData _iconFor(ScheduleEntryType category) {
  switch (category) {
    case ScheduleEntryType.Exam:
      return Icons.school_outlined;
    case ScheduleEntryType.SpecialEvent:
      return Icons.event_outlined;
    case ScheduleEntryType.PublicHoliday:
      return Icons.celebration_outlined;
    case ScheduleEntryType.Unknown:
    case ScheduleEntryType.Class:
    case ScheduleEntryType.Online:
      return Icons.calendar_today_outlined;
  }
}
