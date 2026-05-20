import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/dualis/ui/viewmodels/study_grades_view_model.dart';
import 'package:dualmate/dualis/ui/widgets/grade_state_icon.dart';
import 'package:flutter/material.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';

class StudyOverviewPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<StudyGradesViewModel>(context, listen: false);

    return RefreshIndicator(
      onRefresh: () => viewModel.refreshData(force: true),
      child: SizedBox(
        height: double.infinity,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          scrollDirection: Axis.vertical,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              buildGpaCredits(context),
              buildModules(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildGpaCredits(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            L.of(context).dualisOverview,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          PropertyChangeConsumer<StudyGradesViewModel, String>(
            properties: const ["studyGrades", "isLoadingStudyGrades"],
            builder: (
              BuildContext context,
              StudyGradesViewModel? model,
              Set<String>? properties,
            ) {
              if (model == null) return const SizedBox.shrink();
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: model.isLoadingStudyGrades
                    ? const _OverviewSummaryLoadingPlaceholder(
                        key:
                            ValueKey<String>('dualis_overview_summary_loading'),
                      )
                    : Column(
                        key: const ValueKey<String>('dualis_overview_summary'),
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                            child: Row(
                              textBaseline: TextBaseline.alphabetic,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              children: <Widget>[
                                Text(
                                  model.studyGrades.gpaTotal.toString(),
                                  style:
                                      Theme.of(context).textTheme.displaySmall,
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 0, 0),
                                  child: Text(
                                    L.of(context).dualisOverviewGpaTotalModules,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            textBaseline: TextBaseline.alphabetic,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            children: <Widget>[
                              Text(
                                model.studyGrades.gpaMainModules.toString(),
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                                child: Text(
                                  L.of(context).dualisOverviewGpaMainModules,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                            child: Row(
                              textBaseline: TextBaseline.alphabetic,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              children: <Widget>[
                                Text(
                                  "${model.studyGrades.creditsGained} / ${model.studyGrades.creditsTotal}",
                                  style:
                                      Theme.of(context).textTheme.displaySmall,
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 0, 0),
                                  child: Text(
                                    L.of(context).dualisOverviewCredits,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildModules(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text(
              L.of(context).dualisOverviewModuleGrades,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          PropertyChangeConsumer<StudyGradesViewModel, String>(
            properties: const ["allModules", "isLoadingAllModules"],
            builder: (
              BuildContext context,
              StudyGradesViewModel? model,
              Set<String>? properties,
            ) {
              if (model == null) return const SizedBox.shrink();
              final showLoading =
                  model.isLoadingAllModules && model.allModules.isEmpty;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: showLoading
                    ? const _OverviewModulesLoadingPlaceholder(
                        key: ValueKey<String>('dualis_modules_loading'),
                      )
                    : SizedBox(
                        key: ValueKey<String>(
                          'dualis_modules_ready_${model.allModules.length}',
                        ),
                        child: buildModulesDataTable(context, model),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Padding buildProgressIndicator() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget buildModulesDataTable(
    BuildContext context,
    StudyGradesViewModel model,
  ) {
    var dataRows = <DataRow>[];

    for (var module in model.allModules) {
      dataRows.add(
        DataRow(
          cells: <DataCell>[
            DataCell(Text(module.name)),
            DataCell(Text(module.credits)),
            DataCell(Text(module.grade)),
            DataCell(GradeStateIcon(state: module.state)),
          ],
        ),
      );
    }

    return DataTable(
      columnSpacing: 10,
      headingRowHeight: 50,
      rows: dataRows,
      columns: buildDataTableColumns(context),
    );
  }

  List<DataColumn> buildDataTableColumns(BuildContext context) {
    return <DataColumn>[
      DataColumn(
        label: Text(L.of(context).dualisOverviewModuleColumnHeader),
        numeric: false,
      ),
      DataColumn(
        label: Text(L.of(context).dualisOverviewCreditsColumnHeader),
        numeric: true,
      ),
      DataColumn(
        label: Text(L.of(context).dualisOverviewGradeColumnHeader),
        numeric: true,
      ),
      DataColumn(
        label: const Text(""),
        numeric: true,
        tooltip: L.of(context).dualisOverviewPassedColumnHeader,
      ),
    ];
  }
}

class _OverviewSummaryLoadingPlaceholder extends StatelessWidget {
  const _OverviewSummaryLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: const [
          _MetricLoadingRow(),
          SizedBox(height: 8),
          _MetricLoadingRow(),
          SizedBox(height: 8),
          _MetricLoadingRow(),
        ],
      ),
    );
  }
}

class _MetricLoadingRow extends StatelessWidget {
  const _MetricLoadingRow();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.78);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 86,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewModulesLoadingPlaceholder extends StatelessWidget {
  const _OverviewModulesLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.78);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        children: List.generate(5, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }),
      ),
    );
  }
}
