import 'dart:async';

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/widgets/error_display.dart';
import 'package:dualmate/date_management/model/date_entry.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/date_management/model/important_event_section.dart';
import 'package:dualmate/date_management/ui/viewmodels/date_management_view_model.dart';
import 'package:dualmate/date_management/ui/widgets/date_detail_bottom_sheet.dart';
import 'package:dualmate/date_management/ui/widgets/date_filter_options.dart';
import 'package:dualmate/date_management/ui/widgets/dates_agenda_layout.dart';
import 'package:dualmate/date_management/ui/widgets/dates_agenda_row.dart';
import 'package:dualmate/date_management/ui/widgets/dates_empty_state.dart';
import 'package:dualmate/date_management/ui/widgets/dates_render_data.dart';
import 'package:dualmate/date_management/ui/widgets/dh_mine_dates_table.dart';
import 'package:dualmate/date_management/ui/widgets/important_event_section_heading.dart';
import 'package:dualmate/schedule/ui/widgets/select_source_dialog.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/schedule_entry_detail_bottom_sheet.dart';
import 'package:dualmate/ui/banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:kiwi/kiwi.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';

class DateManagementPage extends StatefulWidget {
  @override
  State<DateManagementPage> createState() => _DateManagementPageState();
}

class _DatesLoadingIndicatorTransition extends StatefulWidget {
  final bool showLoading;

  const _DatesLoadingIndicatorTransition({required this.showLoading});

  @override
  State<_DatesLoadingIndicatorTransition> createState() =>
      _DatesLoadingIndicatorTransitionState();
}

class _DatesLoadingIndicatorTransitionState
    extends State<_DatesLoadingIndicatorTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hideController;
  late final Animation<double> _opacity;
  late bool _retainLoading;
  bool _tickerEnabled = true;
  bool _pendingHide = false;

  @override
  void initState() {
    super.initState();
    _retainLoading = widget.showLoading;
    _hideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addStatusListener(_handleAnimationStatus);
    _opacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _hideController, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled == tickerEnabled) return;

    _tickerEnabled = tickerEnabled;
    if (tickerEnabled && _pendingHide) {
      _pendingHide = false;
      _hideController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant _DatesLoadingIndicatorTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showLoading) {
      _retainLoading = true;
      _pendingHide = false;
      _hideController
        ..stop()
        ..value = 0;
      return;
    }

    if (!_retainLoading) return;
    if (_tickerEnabled) {
      _pendingHide = false;
      _hideController.forward(from: 0);
    } else {
      _pendingHide = true;
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_retainLoading) return;
    setState(() {
      _retainLoading = false;
    });
  }

  @override
  void dispose() {
    _hideController
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_retainLoading) {
      return const SizedBox(
        key: ValueKey<String>('dates_loading_indicator_hidden'),
      );
    }
    return FadeTransition(
      opacity: _opacity,
      child: const LinearProgressIndicator(
        key: ValueKey<String>('dates_loading_indicator'),
      ),
    );
  }
}

class _DateManagementPageState extends State<DateManagementPage> {
  static const Duration _initialLoadDelay = Duration(milliseconds: 320);
  // Keep one row prepared so 120 Hz scrolling does not build every row at the
  // viewport edge without restoring the old 560 px cold-load layout cost.
  static const double _importantEventsCacheExtent = 140;

  final ScrollController _raplaScrollController = ScrollController();
  Timer? _initializeTimer;
  Timer? _renderDataTimeTimer;
  bool _raplaAutoloadScheduled = false;

  DatesRenderData? _datesRenderData;
  DateManagementViewModel? _renderedModel;
  List<ImportantEventSection>? _renderedSections;
  List<DateEntry>? _renderedDateEntries;
  String? _renderedLocale;
  int? _renderedDateEntriesKeyIndex;
  int _renderDataTimeVersion = 0;
  int? _renderedTimeVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTimer?.cancel();
      _initializeTimer = Timer(_initialLoadDelay, () {
        if (!mounted) return;
        var viewModel = Provider.of<DateManagementViewModel>(
          context,
          listen: false,
        );
        SchedulerBinding.instance.scheduleTask<void>(
          viewModel.initialize,
          Priority.idle,
          debugLabel: 'dates.initialize',
        );
      });
    });
  }

  @override
  void dispose() {
    _initializeTimer?.cancel();
    _renderDataTimeTimer?.cancel();
    _raplaScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DateManagementViewModel viewModel = Provider.of<DateManagementViewModel>(
      context,
      listen: false,
    );

    return PropertyChangeProvider<DateManagementViewModel, String>(
      value: viewModel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PropertyChangeConsumer<DateManagementViewModel, String>(
            properties: const [
              "useDhMineForDates",
              "isLoading",
              "isLoadingNextRaplaPage",
              "importantEventSections",
            ],
            builder:
                (
                  BuildContext context,
                  DateManagementViewModel? model,
                  Set<String>? properties,
                ) {
                  final headerModel = model ?? viewModel;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (headerModel.useDhMineForDates)
                        DateFilterOptions(viewModel: headerModel),
                      Stack(
                        children: <Widget>[
                          const Divider(),
                          _DatesLoadingIndicatorTransition(
                            showLoading:
                                headerModel.isLoading ||
                                (!headerModel.useDhMineForDates &&
                                    headerModel.isLoadingNextRaplaPage &&
                                    headerModel.importantEventSections.isEmpty),
                          ),
                        ],
                      ),
                    ],
                  );
                },
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
              "currentDateDatabase",
              "currentSelectedYear",
            ],
            builder:
                (
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

  Widget _buildContent(DateManagementViewModel model, BuildContext context) {
    final renderData = _getRenderData(model, context);
    if (model.useDhMineForDates) {
      return RefreshIndicator(
        onRefresh: () => model.updateDates(),
        child: DhMineDatesTable(
          key: ValueKey<String>('dhmine_dates_${model.dateEntriesKeyIndex}'),
          entries: renderData.dateEntries,
          dataKeyIndex: model.dateEntriesKeyIndex,
          onEntryTap: (entry) {
            showDateEntryDetailBottomSheet(context, entry.entry);
          },
        ),
      );
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

    return RefreshIndicator(
      onRefresh: () => model.updateDates(),
      child: _buildImportantEventsList(model, context, renderData),
    );
  }

  DatesRenderData _getRenderData(
    DateManagementViewModel model,
    BuildContext context,
  ) {
    final locale = L.of(context).locale.languageCode;
    final isCurrent =
        _datesRenderData != null &&
        identical(_renderedModel, model) &&
        identical(_renderedSections, model.importantEventSections) &&
        identical(_renderedDateEntries, model.allDates) &&
        _renderedLocale == locale &&
        _renderedDateEntriesKeyIndex == model.dateEntriesKeyIndex &&
        _renderedTimeVersion == _renderDataTimeVersion;
    if (isCurrent) return _datesRenderData!;

    final now = DateTime.now();
    final renderData = DatesRenderData.prepare(
      sections: model.importantEventSections,
      entries: model.allDates,
      locale: locale,
      now: now,
    );
    _datesRenderData = renderData;
    _renderedModel = model;
    _renderedSections = model.importantEventSections;
    _renderedDateEntries = model.allDates;
    _renderedLocale = locale;
    _renderedDateEntriesKeyIndex = model.dateEntriesKeyIndex;
    _renderedTimeVersion = _renderDataTimeVersion;
    _scheduleRenderDataTimeUpdate(renderData.nextPastStateChange, now);
    return renderData;
  }

  void _scheduleRenderDataTimeUpdate(DateTime? nextChange, DateTime now) {
    _renderDataTimeTimer?.cancel();
    if (nextChange == null) return;

    final delay = nextChange.difference(now) + const Duration(milliseconds: 1);
    _renderDataTimeTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _renderDataTimeVersion++;
      });
    });
  }

  Widget _buildImportantEventsList(
    DateManagementViewModel model,
    BuildContext context,
    DatesRenderData renderData,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final theme = Theme.of(context);
        final layoutSpec = DatesAgendaLayoutSpec.resolve(
          availableWidth: constraints.maxWidth,
          textScaler: textScaler,
        );

        if (renderData.raplaItems.isEmpty) {
          _scheduleRaplaAutoload(model);
          return ListView(
            controller: _raplaScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: layoutSpec.listHorizontalInset,
              vertical: layoutSpec.listVerticalPadding,
            ),
            children: [
              if (!model.isLoading && !model.isLoadingNextRaplaPage)
                Center(child: Text(L.of(context).dateManagementRaplaEmpty)),
              _buildRaplaFooter(model, context),
            ],
          );
        }

        _scheduleRaplaAutoload(model);
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
              model.loadNextRaplaPage();
            }
            return false;
          },
          child: ListView.builder(
            key: const Key('rapla_dates_list'),
            controller: _raplaScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: layoutSpec.listHorizontalInset,
              vertical: layoutSpec.listVerticalPadding,
            ),
            scrollCacheExtent: ScrollCacheExtent.pixels(
              _importantEventsCacheExtent,
            ),
            addAutomaticKeepAlives: false,
            addSemanticIndexes: false,
            findChildIndexCallback: renderData.indexForKey,
            itemBuilder: (context, index) {
              if (index < renderData.raplaItems.length) {
                final item = renderData.raplaItems[index];
                final child = switch (item.kind) {
                  RaplaListItemKind.sectionHeading =>
                    ImportantEventSectionHeading(
                      data: item.heading!,
                      layoutSpec: layoutSpec,
                      isFirst: index == 0,
                      resolvedTheme: theme,
                    ),
                  RaplaListItemKind.eventRow => ImportantEventAgendaRow(
                    data: item.row!,
                    layoutSpec: layoutSpec,
                    isInExamWeek:
                        item.sectionKind == ImportantEventSectionKind.examWeek,
                    onTap: () => _showImportantEventDetailBottomSheet(
                      context,
                      item.row!.event.event,
                    ),
                    resolvedTheme: theme,
                  ),
                };
                return KeyedSubtree(
                  key: ValueKey<String>(item.stableKey),
                  child: index == 0
                      ? KeyedSubtree(
                          key: const Key('dates_rapla_first_item'),
                          child: child,
                        )
                      : child,
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildRaplaFooter(model, context),
              );
            },
            itemCount: renderData.raplaItems.length + 1,
          ),
        );
      },
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
      builder: (context) => DateDetailBottomSheet(dateEntry: entry),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
    );
  }

  Widget buildErrorDisplay(BuildContext context) {
    return PropertyChangeConsumer<DateManagementViewModel, String>(
      properties: const ["updateFailed"],
      builder:
          (
            BuildContext context,
            DateManagementViewModel? model,
            Set<String>? properties,
          ) => ErrorDisplay(show: model?.updateFailed ?? false),
    );
  }

  void _showImportantEventDetailBottomSheet(
    BuildContext context,
    ImportantEvent event,
  ) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (context) => ScheduleEntryDetailBottomSheet(
        scheduleEntry: event.toScheduleEntry(),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
    );
  }
}
