import 'package:dualmate/date_management/ui/widgets/dates_render_data.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';

class ImportantEventTile extends StatelessWidget {
  final ImportantEventRenderData renderData;
  final EdgeInsets contentPadding;
  final VisualDensity? visualDensity;
  final double dotSize;
  final TextStyle? titleStyle;
  final Color? dotColor;
  final bool showProfessor;

  const ImportantEventTile({
    Key? key,
    required this.renderData,
    required this.contentPadding,
    this.visualDensity,
    this.dotSize = 12,
    this.titleStyle,
    this.dotColor,
    this.showProfessor = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final preparedData = renderData;
    final resolvedTitleStyle =
        titleStyle ??
        (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
          decoration: preparedData.isPast ? TextDecoration.lineThrough : null,
        );

    return ListTile(
      contentPadding: contentPadding,
      visualDensity: visualDensity,
      leading: _EventDot(
        color: dotColor ?? _eventColor(context, preparedData),
        size: dotSize,
      ),
      isThreeLine: _showsProfessor,
      title: Text(preparedData.event.title, style: resolvedTitleStyle),
      subtitle: _buildSubtitle(context, preparedData),
    );
  }

  bool get _showsProfessor {
    return showProfessor &&
        renderData.event.type == ScheduleEntryType.Exam &&
        renderData.event.professor.trim().isNotEmpty;
  }

  Widget _buildSubtitle(
    BuildContext context,
    ImportantEventRenderData preparedData,
  ) {
    if (!_showsProfessor) {
      return Text(preparedData.dateText);
    }

    final professorStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(preparedData.dateText),
        Text(
          preparedData.event.professor,
          key: const Key('important_event_professor_text'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: professorStyle,
        ),
      ],
    );
  }

  Color _eventColor(BuildContext context, ImportantEventRenderData data) {
    switch (data.event.type) {
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
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
