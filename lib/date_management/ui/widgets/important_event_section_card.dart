import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/ui/widgets/dates_render_data.dart';
import 'package:dualmate/date_management/ui/widgets/important_event_tile.dart';
import 'package:flutter/material.dart';

class ImportantEventSectionCard extends StatelessWidget {
  final ImportantEventSectionRenderData renderData;

  const ImportantEventSectionCard({Key? key, required this.renderData})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final section = renderData.section;
    final dataByEvent = <ImportantEvent, ImportantEventRenderData>{
      if (renderData.header != null)
        renderData.header!.event: renderData.header!,
      for (final event in renderData.events) event.event: event,
    };
    final isSingleEventSection =
        section.header == null && section.events.length == 1;
    final children = <Widget>[];

    if (section.header == null && section.events.isNotEmpty) {
      for (var event in section.events) {
        children.add(
          _buildEventTile(dataByEvent[event]!, isSingleEventSection),
        );
      }
    } else {
      if (section.header != null) {
        children.add(
          _buildSectionHeader(
            dataByEvent[section.header!]!,
            context,
            renderData.isExamSection,
          ),
        );
      }

      if (section.events.isNotEmpty) {
        if (section.header != null) {
          children.add(const Divider(height: 1));
        }
        for (var event in section.events) {
          children.add(_buildNestedEventTile(dataByEvent[event]!));
        }
      }
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: _sectionBackground(context, renderData.isExamSection),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader(
    ImportantEventRenderData renderData,
    BuildContext context,
    bool isExamSection,
  ) {
    return ImportantEventTile(
      renderData: renderData,
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      showProfessor: false,
      titleStyle: (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
          .copyWith(fontWeight: FontWeight.w600),
      dotColor: isExamSection ? const Color(0xffff0000) : null,
    );
  }

  Widget _buildEventTile(ImportantEventRenderData renderData, bool compact) {
    return ImportantEventTile(
      renderData: renderData,
      contentPadding: compact
          ? const EdgeInsets.fromLTRB(16, 2, 16, 2)
          : const EdgeInsets.fromLTRB(16, 4, 16, 4),
      visualDensity: compact ? const VisualDensity(vertical: -3) : null,
    );
  }

  Widget _buildNestedEventTile(ImportantEventRenderData renderData) {
    return ImportantEventTile(
      renderData: renderData,
      contentPadding: const EdgeInsets.fromLTRB(28, 0, 16, 0),
      visualDensity: const VisualDensity(vertical: -2),
      dotSize: 10,
    );
  }

  Color _sectionBackground(BuildContext context, bool isExamSection) {
    if (isExamSection) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final opacity = isDark ? 0.22 : 0.12;
      return const Color(0xffff0000).withValues(alpha: opacity);
    }

    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }
}
