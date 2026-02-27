import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/widgets/error_display.dart';
import 'package:dualmate/common/util/date_utils.dart';
import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/ui/viewmodels/date_management_view_model.dart';
import 'package:dualmate/date_management/ui/widgets/date_detail_bottom_sheet.dart';
import 'package:dualmate/date_management/ui/widgets/date_filter_options.dart';
import 'package:dualmate/date_management/ui/widgets/dates_empty_state.dart';
import 'package:dualmate/date_management/ui/widgets/important_event_section_card.dart';
import 'package:dualmate/schedule/ui/widgets/select_source_dialog.dart';
import 'package:dualmate/ui/banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:kiwi/kiwi.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';

class DateManagementPage extends StatefulWidget {
  @override
  State<DateManagementPage> createState() => _DateManagementPageState();
}

class _DateManagementPageState extends State<DateManagementPage> {
  final ScrollController _raplaScrollController = ScrollController();
  bool _raplaAutoloadScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var viewModel =
          Provider.of<DateManagementViewModel>(context, listen: false);
      SchedulerBinding.instance.scheduleTask<void>(
        viewModel.initialize,
        Priority.idle,
        debugLabel: 'dates.initialize',
      );
    });
  }

  @override
  void dispose() {
    _raplaScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DateManagementViewModel viewModel =
        Provider.of<DateManagementViewModel>(context, listen: false);

    return PropertyChangeProvider<DateManagementViewModel, String>(
      value: viewModel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (viewModel.useDhMineForDates)
            DateFilterOptions(viewModel: viewModel),
          Stack(
            children: <Widget>[
              const Divider(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: (viewModel.isLoading ||
                        (!viewModel.useDhMineForDates &&
                            viewModel.isLoadingNextRaplaPage &&
                            viewModel.importantEventSections.isEmpty))
                    ? const LinearProgressIndicator()
                    : Container(),
              ),
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
          PropertyChangeConsumer<DateManagementViewModel, String>(
            properties: const [
              "allDates",
              "importantEventSections",
              "useDhMineForDates",
              "raplaUrlValid",
              "bothSourcesUnconfigured",
              "isLoading",
              "isLoadingNextRaplaPage",
              "nextRaplaPageFailed",
              "hasMoreRaplaPages",
              "showOutOfStudyEvents",
              "currentDateDatabase",
              "currentSelectedYear",
            ],
            builder: (
              BuildContext context,
              DateManagementViewModel? model,
              Set<String>? properties,
            ) {
              if (model == null) return Container();
              return _buildContent(model, context);
            },
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

    if (model.bothSourcesUnconfigured) {
      return DatesEmptyState(
        onSetupCompleted: () async {
          if (!mounted) return;
          await model.updateDates();
        },
      );
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
            if (!mounted) return;
            await model.updateDates();
          },
        ),
      );
    }

    return _buildImportantEventsList(model, context);
  }

  Widget _buildImportantEventsList(
    DateManagementViewModel model,
    BuildContext context,
  ) {
    var sections = model.importantEventSections;
    if (sections.isEmpty) {
      _scheduleRaplaAutoload(model);
      return ListView(
        controller: _raplaScrollController,
        padding: const EdgeInsets.all(16),
        children: [
          if (!model.isLoading && !model.isLoadingNextRaplaPage)
            Center(
              child: Text(
                L.of(context).dateManagementRaplaEmpty,
              ),
            ),
          _buildRaplaFooter(model, context),
        ],
      );
    }

    var itemCount = sections.length + 1;
    _scheduleRaplaAutoload(model);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          model.loadNextRaplaPage();
        }
        return false;
      },
      child: ListView.separated(
        controller: _raplaScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        cacheExtent: 1400,
        itemBuilder: (context, index) {
          if (index < sections.length) {
            final section = sections[index];
            final sectionKey = section.header?.start.toIso8601String() ??
                (section.events.isNotEmpty
                    ? section.events.first.start.toIso8601String()
                    : 'section_$index');
            return RepaintBoundary(
              child: ImportantEventSectionCard(
                key: ValueKey('section_$sectionKey'),
                section: section,
              ),
            );
          }
          return _buildRaplaFooter(model, context);
        },
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemCount: itemCount,
      ),
    );
  }

  void _scheduleRaplaAutoload(DateManagementViewModel model) {
    if (_raplaAutoloadScheduled) {
      return;
    }
    _raplaAutoloadScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _raplaAutoloadScheduled = false;
      if (!mounted) return;
      if (!_raplaScrollController.hasClients) return;
      if (model.isLoadingNextRaplaPage ||
          model.nextRaplaPageFailed ||
          !model.hasMoreRaplaPages) {
        return;
      }

      final position = _raplaScrollController.position;
      if (position.maxScrollExtent <= 0 ||
          position.pixels >= position.maxScrollExtent - 200) {
        model.loadNextRaplaPage();
      }
    });
  }

  Widget _buildRaplaFooter(
    DateManagementViewModel model,
    BuildContext context,
  ) {
    if (model.isLoadingNextRaplaPage) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (model.nextRaplaPageFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: FilledButton(
            onPressed: model.loadNextRaplaPage,
            child: Text(L.of(context).retry),
          ),
        ),
      );
    }

    if (!model.hasMoreRaplaPages) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Text(L.of(context).noMoreEvents)),
      );
    }

    return const SizedBox(height: 12);
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
