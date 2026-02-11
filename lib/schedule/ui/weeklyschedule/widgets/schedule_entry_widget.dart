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
            constraints.maxHeight < 24 || constraints.maxWidth < 72;
        final isCompact = !isVeryCompact &&
            (constraints.maxHeight < 42 || constraints.maxWidth < 100);
        final borderRadius = BorderRadius.circular(8);

        final baseStyle = textStyleScheduleEntryWidgetTitle(context).copyWith(
          color: textColor,
        );
        final textStyle = baseStyle.copyWith(
          fontSize: isVeryCompact
              ? 10.5
              : (isCompact ? 11.5 : (baseStyle.fontSize ?? 14)),
          fontWeight: isVeryCompact ? FontWeight.w600 : baseStyle.fontWeight,
          height: 1.15,
        );

        final horizontalPadding = isVeryCompact ? 3.0 : 5.0;
        final verticalPadding = isVeryCompact ? 2.0 : 4.0;
        final maxLines = isVeryCompact ? 1 : (isCompact ? 2 : 3);
        final shadowOpacity = isVeryCompact ? 0.0 : 0.14;

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
                  width: 0.6,
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
                    overflow: TextOverflow.ellipsis,
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
