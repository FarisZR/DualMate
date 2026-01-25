import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/widgets/error_display.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/date_management/ui/viewmodels/date_management_view_model.dart';
import 'package:dualmate/date_management/ui/widgets/date_detail_bottom_sheet.dart';
import 'package:dualmate/date_management/ui/widgets/date_filter_options.dart';
import 'package:dualmate/schedule/ui/widgets/select_source_dialog.dart';
import 'package:dualmate/ui/banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiwi/kiwi.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';

class DateManagementPage extends StatefulWidget {
  @override
  State<DateManagementPage> createState() => _DateManagementPageState();
}

class _DateManagementPageState extends State<DateManagementPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var viewModel =
          Provider.of<DateManagementViewModel>(context, listen: false);
      viewModel.reloadUseDhMineSetting();
    });
  }

  @override
  Widget build(BuildContext context) {
    DateManagementViewModel viewModel =
        Provider.of<DateManagementViewModel>(context);

    return PropertyChangeProvider<DateManagementViewModel, String>(
      value: viewModel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DateFilterOptions(viewModel: viewModel),
          Stack(
            children: <Widget>[
              const Divider(),
              AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: viewModel.isLoading
                      ? const LinearProgressIndicator()
                      : Container()),
            ],
          ),
          _buildBody(viewModel, context),
        ],
      ),
    );
  }

  Expanded _buildBody(DateManagementViewModel viewModel, BuildContext context) {
    return Expanded(
      child: Stack(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: PropertyChangeConsumer<DateManagementViewModel, String>(
              builder: (
                BuildContext context,
                DateManagementViewModel? model,
                Set<String>? properties,
              ) {
                if (model == null) return Container();
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    key: ValueKey(viewModel.dateSearchParameters.toString()),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildContent(model, context),
                    ],
                  ),
                );
              },
            ),
          ),
          Align(
            child: buildErrorDisplay(context),
            alignment: Alignment.bottomCenter,
          ),
        ],
      ),
    );
  }

  Widget _buildAllDatesDataTable(
    DateManagementViewModel model,
    BuildContext context,
  ) {
    return DataTable(
      key: ValueKey(model.dateEntriesKeyIndex),
      rows: _buildDataTableRows(model, context),
      columns: <DataColumn>[
        DataColumn(
          label: Text(L.of(context).dateManagementTableHeaderDescription),
        ),
        DataColumn(
          label: Text(L.of(context).dateManagementTableHeaderDate),
        ),
      ],
    );
  }

  List<DataRow> _buildDataTableRows(
    DateManagementViewModel model,
    BuildContext context,
  ) {
    var dataRows = <DataRow>[];
    for (DateEntry dateEntry in model.allDates) {
      dataRows.add(
        DataRow(
          cells: <DataCell>[
            DataCell(
                Text(dateEntry.description,
                    style: dateEntry.end.isBefore(DateTime.now())
                        ? TextStyle(decoration: TextDecoration.lineThrough)
                        : null), onTap: () {
              showDateEntryDetailBottomSheet(context, dateEntry);
            }),
            DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      DateFormat(
                              'dd/MM/yyyy', L.of(context).locale.languageCode)
                          .format(dateEntry.start),
                      style: Theme.of(context).textTheme.bodyLarge ??
                          const TextStyle(),
                    ),
                    // When the date entry has a time of 00:00 don't show it.
                    // It means the date entry is for the whole day
                    isAtMidnight(dateEntry.start)
                        ? Container()
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                            child: Text(
                              DateFormat.Hm(L.of(context).locale.languageCode)
                                  .format(dateEntry.start),
                            ),
                          ),
                  ],
                ), onTap: () {
              showDateEntryDetailBottomSheet(context, dateEntry);
            }),
          ],
        ),
      );
    }

    return dataRows;
  }

  Widget _buildContent(DateManagementViewModel model, BuildContext context) {
    if (model.useDhMineForDates) {
      return _buildAllDatesDataTable(model, context);
    }

    if (!model.raplaUrlValid) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: BannerWidget(
          message: L.of(context).dateManagementRaplaMissing,
          buttonText: L.of(context).scheduleEmptyStateSetUrl.toUpperCase(),
          onButtonTap: () async {
            await SelectSourceDialog(
              KiwiContainer().resolve(),
              KiwiContainer().resolve(),
            ).show(context);
          },
        ),
      );
    }

    return _buildImportantEventsList(model.importantEventSections, context);
  }

  Widget _buildImportantEventsList(
    List<ImportantEventSection> sections,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sections.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                L.of(context).dateManagementRaplaEmpty,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemBuilder: (context, index) {
              var section = sections[index];
              return _buildSectionCard(section, context);
            },
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemCount: sections.length,
          ),
      ],
    );
  }

  Widget _buildSectionCard(
    ImportantEventSection section,
    BuildContext context,
  ) {
    var children = <Widget>[];
    if (section.header == null && section.events.isNotEmpty) {
      for (var event in section.events) {
        children.add(_buildEventTile(event, context));
      }
    } else {
      if (section.header != null) {
        children.add(_buildSectionHeader(section.header!, context));
      }

      if (section.events.isNotEmpty) {
        if (section.header != null) {
          children.add(const Divider(height: 1));
        }
        for (var event in section.events) {
          children.add(_buildNestedEventTile(event, context));
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

  Widget _buildSectionHeader(ImportantEvent event, BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      leading: _buildEventDot(context, event),
      title: Text(
        event.title,
        style: (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
            .copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_formatEventDate(context, event)),
    );
  }

  Widget _buildEventTile(ImportantEvent event, BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      leading: _buildEventDot(context, event),
      title: Text(
        event.title,
        style: event.end.isBefore(DateTime.now())
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(_formatEventDate(context, event)),
    );
  }

  Widget _buildNestedEventTile(ImportantEvent event, BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(28, 0, 16, 0),
      visualDensity: const VisualDensity(vertical: -2),
      leading: _buildEventDot(context, event, size: 10),
      title: Text(
        event.title,
        style: (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
            .copyWith(
          decoration: event.end.isBefore(DateTime.now())
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
      subtitle: Text(_formatEventDate(context, event)),
    );
  }

  Widget _buildEventDot(
    BuildContext context,
    ImportantEvent event, {
    double size = 12,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _eventColor(context, event),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _sectionBackground(
    BuildContext context,
    ImportantEventSection section,
  ) {
    if (_isExamSection(section)) {
      var isDark = Theme.of(context).brightness == Brightness.dark;
      var opacity = isDark ? 0.22 : 0.12;
      return const Color(0xffff0000).withOpacity(opacity);
    }

    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF2F2F2);
  }

  bool _isExamSection(ImportantEventSection section) {
    if (section.events.any((event) => event.type == ScheduleEntryType.Exam)) {
      return true;
    }

    var title = section.header?.title.toLowerCase() ?? '';
    return title.contains('klausur');
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
    var locale = L.of(context).locale.languageCode;
    var dateFormat = DateFormat('dd/MM/yyyy', locale);
    if (event.isSingleDay) {
      var dateText = dateFormat.format(event.start);
      if (event.hasTime) {
        var timeText = DateFormat.Hm(locale).format(event.start);
        return "$dateText · $timeText";
      }
      return dateText;
    }

    var startDate = dateFormat.format(event.start);
    var endDate = dateFormat.format(event.end);
    return "$startDate - $endDate";
  }

  void showDateEntryDetailBottomSheet(BuildContext context, DateEntry entry) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      builder: (context) => DateDetailBottomSheet(
        dateEntry: entry,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
    );
  }

  Widget buildErrorDisplay(BuildContext context) {
    return PropertyChangeConsumer<DateManagementViewModel, String>(
      properties: const ["updateFailed"],
      builder: (BuildContext context, DateManagementViewModel? model,
              Set<String>? properties) =>
          ErrorDisplay(
        show: model?.updateFailed ?? false,
      ),
    );
  }
}
