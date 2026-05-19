import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/date_management/ui/widgets/important_event_tile.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';

class ImportantEventSectionCard extends StatelessWidget {
  final ImportantEventSection section;

  const ImportantEventSectionCard({
    Key? key,
    required this.section,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSingleEventSection =
        section.header == null && section.events.length == 1;
    final children = <Widget>[];

    if (section.header == null && section.events.isNotEmpty) {
      for (var event in section.events) {
        children.add(_buildEventTile(event, isSingleEventSection));
      }
    } else {
      if (section.header != null) {
        children.add(
          _buildSectionHeader(
            section.header!,
            context,
            _isExamSection(section),
          ),
        );
      }

      if (section.events.isNotEmpty) {
        if (section.header != null) {
          children.add(const Divider(height: 1));
        }
        for (var event in section.events) {
          children.add(_buildNestedEventTile(event));
        }
      }
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: _sectionBackground(context, section),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader(
    ImportantEvent event,
    BuildContext context,
    bool isExamSection,
  ) {
    return ImportantEventTile(
      event: event,
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      showProfessor: false,
      titleStyle: (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
          .copyWith(fontWeight: FontWeight.w600),
      dotColor: isExamSection ? const Color(0xffff0000) : null,
    );
  }

  Widget _buildEventTile(ImportantEvent event, bool compact) {
    return ImportantEventTile(
      event: event,
      contentPadding: compact
          ? const EdgeInsets.fromLTRB(16, 2, 16, 2)
          : const EdgeInsets.fromLTRB(16, 4, 16, 4),
      visualDensity: compact ? const VisualDensity(vertical: -3) : null,
    );
  }

  Widget _buildNestedEventTile(ImportantEvent event) {
    return ImportantEventTile(
      event: event,
      contentPadding: const EdgeInsets.fromLTRB(28, 0, 16, 0),
      visualDensity: const VisualDensity(vertical: -2),
      dotSize: 10,
    );
  }

  Color _sectionBackground(
    BuildContext context,
    ImportantEventSection section,
  ) {
    if (_isExamSection(section)) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final opacity = isDark ? 0.22 : 0.12;
      return const Color(0xffff0000).withValues(alpha: opacity);
    }

    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  bool _isExamSection(ImportantEventSection section) {
    if (section.events.any((event) => event.type == ScheduleEntryType.Exam)) {
      return true;
    }

    final title = section.header?.title.toLowerCase() ?? '';
    return title.contains('klausur');
  }
}
