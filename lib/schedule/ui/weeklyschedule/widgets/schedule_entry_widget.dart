import 'dart:math' as math;

import 'package:dualmate/common/ui/schedule_entry_type_mappings.dart';
import 'package:dualmate/common/ui/text_styles.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';

typedef ScheduleEntryTapCallback = Function(ScheduleEntry entry);

class ScheduleEntryWidget extends StatelessWidget {
  final ScheduleEntry scheduleEntry;
  final ScheduleEntryTapCallback onScheduleEntryTap;
  final double? renderedWidth;
  final double? renderedHeight;

  const ScheduleEntryWidget({
    Key? key,
    required this.scheduleEntry,
    required this.onScheduleEntryTap,
    this.renderedWidth,
    this.renderedHeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color = scheduleEntryTypeToColor(context, scheduleEntry.type);
    var textColor = color.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    final width = renderedWidth;
    final height = renderedHeight;
    if (width != null && height != null) {
      return _buildCard(context, width, height, color, textColor);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildCard(
          context,
          constraints.maxWidth,
          constraints.maxHeight,
          color,
          textColor,
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    double width,
    double height,
    Color color,
    Color textColor,
  ) {
    final isVeryCompact = height < 18 || width < 48;
    final isCompact = !isVeryCompact && (height < 34 || width < 70);
    final denseMobile = width <= 80;
    final isDense = isCompact || denseMobile || isVeryCompact;
    final borderRadius = BorderRadius.circular(8);

    final baseStyle = textStyleScheduleEntryWidgetTitle(
      context,
    ).copyWith(color: textColor);
    final baseFontSize = baseStyle.fontSize ?? 14.0;
    final fontSize = isVeryCompact
        ? math.max(12.5, baseFontSize - 1.0)
        : (isDense ? math.max(13.5, baseFontSize - 0.5) : baseFontSize);
    final horizontalPadding = isDense ? 1.35 : 4.0;
    final verticalPadding = isDense ? 1.2 : 3.0;

    final estimatedLineHeight = fontSize * 1.08;
    final availableTextHeight = (height - (verticalPadding * 2)).clamp(
      0.0,
      3000.0,
    );
    final lineBudget = estimatedLineHeight <= 0
        ? 1
        : (availableTextHeight / estimatedLineHeight).floor().clamp(1, 12);
    final maxLines = isDense ? lineBudget.clamp(1, 8) : lineBudget;

    final textStyle = baseStyle.copyWith(
      fontSize: fontSize,
      fontWeight: isDense ? FontWeight.w500 : baseStyle.fontWeight,
      height: 1.08,
    );

    final shadowOpacity = isDense ? 0.0 : 0.14;
    final borderWidth = isDense ? 0.5 : 0.6;
    final overflow = isDense ? TextOverflow.clip : TextOverflow.ellipsis;

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
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
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
  }
}
