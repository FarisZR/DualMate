import 'package:dualmate/date_management/ui/widgets/dates_render_data.dart';
import 'package:dualmate/date_management/ui/widgets/important_event_tile.dart';
import 'package:flutter/material.dart';

/// One lazily-built row of a flattened Rapla section.
class ImportantEventSectionRow extends StatelessWidget {
  final RaplaListItem item;

  const ImportantEventSectionRow({Key? key, required this.item})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tile = ImportantEventTile(
      renderData: item.data!,
      contentPadding: _contentPadding,
      visualDensity: _visualDensity,
      dotSize: _dotSize,
      titleStyle: _titleStyle(context),
      dotColor: item.isHeader && item.isExamSection
          ? const Color(0xffff0000)
          : null,
      showProfessor: !item.isHeader,
    );
    final content = item.showDividerAfter
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[tile, const Divider(height: 1)],
          )
        : tile;

    return Padding(
      padding: EdgeInsets.only(
        top: item.rowIndex == 0 && item.sectionIndex > 0 ? _sectionGap : 0,
      ),
      child: DecoratedBox(
        key: ValueKey<String>(
          'rapla_section_${item.sectionIndex}_row_${item.rowIndex}',
        ),
        decoration: BoxDecoration(
          color: _sectionBackground(context),
          borderRadius: _borderRadius,
        ),
        child: Material(type: MaterialType.transparency, child: content),
      ),
    );
  }

  EdgeInsets get _contentPadding {
    if (item.isHeader) {
      return const EdgeInsets.fromLTRB(16, 4, 16, 4);
    }
    if (item.position == ImportantEventRowPosition.single) {
      return const EdgeInsets.fromLTRB(16, 2, 16, 2);
    }
    if (item.position == ImportantEventRowPosition.middle ||
        item.position == ImportantEventRowPosition.bottom) {
      return const EdgeInsets.fromLTRB(28, 0, 16, 0);
    }
    return const EdgeInsets.fromLTRB(16, 4, 16, 4);
  }

  VisualDensity? get _visualDensity {
    if (item.isHeader) return null;
    if (item.position == ImportantEventRowPosition.single) {
      return const VisualDensity(vertical: -3);
    }
    if (item.position == ImportantEventRowPosition.middle ||
        item.position == ImportantEventRowPosition.bottom) {
      return const VisualDensity(vertical: -2);
    }
    return null;
  }

  double get _dotSize {
    if (item.isHeader) return 12;
    if (item.position == ImportantEventRowPosition.single ||
        item.position == ImportantEventRowPosition.top) {
      return 12;
    }
    return 10;
  }

  TextStyle? _titleStyle(BuildContext context) {
    if (!item.isHeader) return null;
    return (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
        .copyWith(fontWeight: FontWeight.w600);
  }

  Color _sectionBackground(BuildContext context) {
    if (item.isExamSection) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final opacity = isDark ? 0.22 : 0.12;
      return const Color(0xffff0000).withValues(alpha: opacity);
    }

    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  BorderRadius get _borderRadius {
    switch (item.position) {
      case ImportantEventRowPosition.single:
        return BorderRadius.circular(16);
      case ImportantEventRowPosition.top:
        return const BorderRadius.vertical(top: Radius.circular(16));
      case ImportantEventRowPosition.middle:
        return BorderRadius.zero;
      case ImportantEventRowPosition.bottom:
        return const BorderRadius.vertical(bottom: Radius.circular(16));
    }
  }

  static const double _sectionGap = 12;
}
