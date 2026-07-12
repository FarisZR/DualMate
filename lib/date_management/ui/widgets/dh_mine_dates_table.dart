import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/date_management/ui/widgets/dates_render_data.dart';
import 'package:flutter/material.dart';

/// Lazy replacement for the eager DataTable used by the DH-Mine dates view.
class DhMineDatesTable extends StatelessWidget {
  final List<DateEntryRenderData> entries;
  final ValueChanged<DateEntryRenderData> onEntryTap;
  final int dataKeyIndex;

  const DhMineDatesTable({
    Key? key,
    required this.entries,
    required this.onEntryTap,
    required this.dataKeyIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = DateTableColumnWidths.forAvailableWidth(
          constraints.maxWidth,
        );
        return ListView.builder(
          key: const Key('dhmine_dates_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: entries.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _DateTableHeader(widths: widths);
            }

            final entry = entries[index - 1];
            return _DateTableEntryRow(
              key: ValueKey<String>(
                'dhmine_date_row_${dataKeyIndex}_${index - 1}',
              ),
              entry: entry,
              widths: widths,
              onTap: () => onEntryTap(entry),
            );
          },
        );
      },
    );
  }
}

class _DateTableHeader extends StatelessWidget {
  final DateTableColumnWidths widths;

  const _DateTableHeader({required this.widths});

  @override
  Widget build(BuildContext context) {
    final labels = L.of(context);
    final style = Theme.of(context).textTheme.labelLarge;
    return SizedBox(
      key: const Key('dhmine_dates_header'),
      height: 56,
      child: _DateTableCells(
        widths: widths,
        description: Text(
          labels.dateManagementTableHeaderDescription,
          style: style,
        ),
        date: Text(labels.dateManagementTableHeaderDate, style: style),
      ),
    );
  }
}

class _DateTableEntryRow extends StatelessWidget {
  final DateEntryRenderData entry;
  final DateTableColumnWidths widths;
  final VoidCallback onTap;

  const _DateTableEntryRow({
    Key? key,
    required this.entry,
    required this.widths,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dataTextStyle =
        Theme.of(context).dataTableTheme.dataTextStyle ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    final descriptionStyle = entry.isPast
        ? dataTextStyle.copyWith(decoration: TextDecoration.lineThrough)
        : dataTextStyle;
    final dateStyle =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle();

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: _DateTableCells(
            widths: widths,
            description: Text(
              entry.entry.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: descriptionStyle,
            ),
            date: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(entry.dateText, style: dateStyle),
                if (entry.timeText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(entry.timeText!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTableCells extends StatelessWidget {
  final DateTableColumnWidths widths;
  final Widget description;
  final Widget date;

  const _DateTableCells({
    required this.widths,
    required this.description,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: widths.description,
          child: Padding(
            padding: const EdgeInsets.only(left: 24),
            child: description,
          ),
        ),
        const SizedBox(width: DateTableColumnWidths.columnSpacing),
        SizedBox(
          width: widths.date,
          child: Padding(
            padding: const EdgeInsets.only(right: 24),
            child: date,
          ),
        ),
      ],
    );
  }
}
