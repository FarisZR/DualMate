import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ImportantEventTile extends StatelessWidget {
  static final Map<String, DateFormat> _dateFormats = <String, DateFormat>{};
  static final Map<String, DateFormat> _timeFormats = <String, DateFormat>{};

  final ImportantEvent event;
  final EdgeInsets contentPadding;
  final VisualDensity? visualDensity;
  final double dotSize;
  final TextStyle? titleStyle;
  final Color? dotColor;
  final bool showProfessor;

  const ImportantEventTile({
    Key? key,
    required this.event,
    required this.contentPadding,
    this.visualDensity,
    this.dotSize = 12,
    this.titleStyle,
    this.dotColor,
    this.showProfessor = true,
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
      leading: _EventDot(
        color: dotColor ?? _eventColor(context, event),
        size: dotSize,
      ),
      isThreeLine: _showsProfessor,
      title: Text(event.title, style: resolvedTitleStyle),
      subtitle: _buildSubtitle(context),
    );
  }

  bool get _showsProfessor {
    return showProfessor &&
        event.type == ScheduleEntryType.Exam &&
        event.professor.trim().isNotEmpty;
  }

  Widget _buildSubtitle(BuildContext context) {
    if (!_showsProfessor) {
      return Text(_formatEventDate(context, event));
    }

    final professorStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatEventDate(context, event)),
        Text(
          event.professor,
          key: const Key('important_event_professor_text'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: professorStyle,
        ),
      ],
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
    final dateFormat = _dateFormats.putIfAbsent(
      locale,
      () => DateFormat('dd/MM/yyyy', locale),
    );
    if (event.isSingleDay) {
      final dateText = dateFormat.format(event.start);
      if (event.hasTime) {
        final timeText = _timeFormats
            .putIfAbsent(locale, () => DateFormat.Hm(locale))
            .format(event.start);
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
