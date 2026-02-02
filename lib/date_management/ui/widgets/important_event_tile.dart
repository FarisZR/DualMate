import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ImportantEventTile extends StatelessWidget {
  final ImportantEvent event;
  final EdgeInsets contentPadding;
  final VisualDensity? visualDensity;
  final double dotSize;
  final TextStyle? titleStyle;

  const ImportantEventTile({
    Key? key,
    required this.event,
    required this.contentPadding,
    this.visualDensity,
    this.dotSize = 12,
    this.titleStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final resolvedTitleStyle = titleStyle ??
        (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
          decoration: event.end.isBefore(DateTime.now())
              ? TextDecoration.lineThrough
              : null,
        );

    return ListTile(
      contentPadding: contentPadding,
      visualDensity: visualDensity,
      leading: _EventDot(color: _eventColor(context, event), size: dotSize),
      title: Text(event.title, style: resolvedTitleStyle),
      subtitle: Text(_formatEventDate(context, event)),
    );
  }

  Color _eventColor(BuildContext context, ImportantEvent event) {
    switch (event.type) {
      case ScheduleEntryType.Exam:
        return const Color(0xffff0000);
      case ScheduleEntryType.SpecialEvent:
        return const Color(0xffc0e2ff);
      case ScheduleEntryType.PublicHoliday:
        return const Color(0xffcbcbcb);
      default:
        return Theme.of(context).disabledColor;
    }
  }

  String _formatEventDate(BuildContext context, ImportantEvent event) {
    final locale = L.of(context).locale.languageCode;
    final dateFormat = DateFormat('dd/MM/yyyy', locale);
    if (event.isSingleDay) {
      final dateText = dateFormat.format(event.start);
      if (event.hasTime) {
        final timeText = DateFormat.Hm(locale).format(event.start);
        return "$dateText · $timeText";
      }
      return dateText;
    }

    final startDate = dateFormat.format(event.start);
    final endDate = dateFormat.format(event.end);
    return "$startDate - $endDate";
  }
}

class _EventDot extends StatelessWidget {
  final Color color;
  final double size;

  const _EventDot({Key? key, required this.color, required this.size})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
