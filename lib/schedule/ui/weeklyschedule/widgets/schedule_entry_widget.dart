import 'package:dualmate/common/ui/schedule_entry_type_mappings.dart';
import 'package:dualmate/common/ui/text_styles.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';

typedef ScheduleEntryTapCallback = Function(ScheduleEntry entry);

class ScheduleEntryWidget extends StatelessWidget {
  final ScheduleEntry scheduleEntry;
  final ScheduleEntryTapCallback onScheduleEntryTap;

  const ScheduleEntryWidget({
    Key? key,
    required this.scheduleEntry,
    required this.onScheduleEntryTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color = scheduleEntryTypeToColor(context, scheduleEntry.type);
    var textColor =
        color.computeLuminance() > 0.45 ? Colors.black : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryCompact =
            constraints.maxHeight < 22 || constraints.maxWidth < 60;
        final isCompact = !isVeryCompact &&
            (constraints.maxHeight < 42 || constraints.maxWidth < 84);
        final denseMobile = constraints.maxWidth <= 72;
        final borderRadius = BorderRadius.circular(8);

        final baseStyle = textStyleScheduleEntryWidgetTitle(context).copyWith(
          color: textColor,
        );
        final baseFontSize = baseStyle.fontSize ?? 14.0;
        final fontSize = isVeryCompact
            ? 11.5
            : (isCompact || denseMobile
                ? baseFontSize.clamp(12.0, 13.0)
                : baseFontSize);
        final horizontalPadding =
            (isCompact || denseMobile || isVeryCompact) ? 2.0 : 4.0;
        final verticalPadding =
            (isCompact || denseMobile || isVeryCompact) ? 1.5 : 3.0;

        final estimatedLineHeight = fontSize * 1.08;
        final availableTextHeight =
            (constraints.maxHeight - (verticalPadding * 2)).clamp(0.0, 3000.0);
        final lineBudget = estimatedLineHeight <= 0
            ? 1
            : (availableTextHeight / estimatedLineHeight).floor().clamp(1, 12);
        final maxLines = (isCompact || denseMobile || isVeryCompact)
            ? lineBudget.clamp(1, 6)
            : lineBudget;

        final textStyle = baseStyle.copyWith(
          fontSize: fontSize,
          fontWeight: isVeryCompact ? FontWeight.w600 : baseStyle.fontWeight,
          height: 1.08,
        );

        final shadowOpacity = isVeryCompact ? 0.0 : 0.14;
        final borderWidth =
            (isCompact || denseMobile || isVeryCompact) ? 0.5 : 0.6;
        final overflow = (isCompact || denseMobile || isVeryCompact)
            ? TextOverflow.clip
            : TextOverflow.ellipsis;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: shadowOpacity == 0
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: shadowOpacity),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Ink(
              decoration: BoxDecoration(
                color: color,
                borderRadius: borderRadius,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                  width: borderWidth,
                ),
              ),
              child: InkWell(
                borderRadius: borderRadius,
                onTap: () {
                  onScheduleEntryTap(scheduleEntry);
                },
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    verticalPadding,
                  ),
                  child: Text(
                    scheduleEntry.title,
                    maxLines: maxLines,
                    softWrap: true,
                    overflow: overflow,
                    textAlign: TextAlign.left,
                    style: textStyle,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
