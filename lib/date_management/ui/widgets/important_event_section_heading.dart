import 'package:dualmate/date_management/ui/theme/dates_agenda_theme.dart';
import 'package:dualmate/date_management/ui/widgets/dates_agenda_layout.dart';
import 'package:dualmate/date_management/ui/widgets/dates_render_data.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';

class ImportantEventSectionHeading extends StatelessWidget {
  final ImportantEventSectionHeadingRenderData data;
  final DatesAgendaLayoutSpec layoutSpec;
  final bool isFirst;
  final ThemeData? resolvedTheme;

  const ImportantEventSectionHeading({
    super.key,
    required this.data,
    required this.layoutSpec,
    required this.isFirst,
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
    final colors = agendaTheme.colorsFor(dataCategory, theme.colorScheme);
    final iconFill = Color.alphaBlend(
      colors.accent.withValues(alpha: 0.12),
      colors.container,
    );

    return Semantics(
      container: true,
      header: true,
      headingLevel: 2,
      label: data.semanticsLabel,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(top: isFirst ? 8 : 24, bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: layoutSpec.railWidth),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: layoutSpec.gap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconFill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.school_outlined,
                        color: colors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            data.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.rangeSubtitle,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const dataCategory =
      // Exam-week headings always use the exam token set.
      // Kept as a typed constant so widgets never infer from source text.
      ScheduleEntryType.Exam;
}
