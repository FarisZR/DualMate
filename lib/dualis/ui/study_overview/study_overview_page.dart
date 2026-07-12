import 'dart:math' as math;

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/dualis/model/module.dart';
import 'package:dualmate/dualis/model/study_grades.dart';
import 'package:dualmate/dualis/ui/viewmodels/study_grades_view_model.dart';
import 'package:dualmate/dualis/ui/widgets/dualis_sliver_content_transition.dart';
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableLayout = _OverviewTableLayout.fromWidth(
            constraints.maxWidth,
          );

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(child: buildGpaCredits(context)),
              SliverToBoxAdapter(child: buildModulesTitle(context)),
              PropertyChangeConsumer<StudyGradesViewModel, String>(
                properties: const ['allModules', 'isLoadingAllModules'],
                builder:
                    (
                      BuildContext context,
                      StudyGradesViewModel? model,
                      Set<String>? properties,
                    ) {
                      if (model == null) {
                        return const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        );
                      }

                      final showLoading =
                          model.isLoadingAllModules && model.allModules.isEmpty;
                      return DualisSliverContentTransition(
                        showLoading: showLoading,
                        contentKey: model.allModules,
                        loadingBuilder: (_) => const SliverToBoxAdapter(
                          child: _OverviewModulesLoadingPlaceholder(
                            key: ValueKey<String>('dualis_modules_loading'),
                          ),
                        ),
                        contentBuilder: (_) => _OverviewModulesSliver(
                          key: ValueKey<String>(
                            'dualis_modules_ready_${model.allModules.length}',
                          ),
                          modules: model.allModules,
                          tableLayout: tableLayout,
                        ),
                      );
                    },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildGpaCredits(BuildContext context) {
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
            properties: const ['studyGrades', 'isLoadingStudyGrades'],
            builder:
                (
                  BuildContext context,
                  StudyGradesViewModel? model,
                  Set<String>? properties,
                ) {
                  if (model == null) return const SizedBox.shrink();

                  final summary = _OverviewSummaryValues.from(
                    model.studyGrades,
                  );
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: model.isLoadingStudyGrades
                        ? const _OverviewSummaryLoadingPlaceholder(
                            key: ValueKey<String>(
                              'dualis_overview_summary_loading',
                            ),
                          )
                        : _OverviewSummary(
                            key: const ValueKey<String>(
                              'dualis_overview_summary',
                            ),
                            values: summary,
                          ),
                  );
                },
          ),
        ],
      ),
    );
  }

  Widget buildModulesTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 48, 0, 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          L.of(context).dualisOverviewModuleGrades,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

class _OverviewSummaryValues {
  final String totalGpa;
  final String mainModulesGpa;
  final String credits;

  const _OverviewSummaryValues({
    required this.totalGpa,
    required this.mainModulesGpa,
    required this.credits,
  });

  factory _OverviewSummaryValues.from(StudyGrades grades) {
    return _OverviewSummaryValues(
      totalGpa: grades.gpaTotal.toString(),
      mainModulesGpa: grades.gpaMainModules.toString(),
      credits: '${grades.creditsGained} / ${grades.creditsTotal}',
    );
  }
}

class _OverviewSummary extends StatelessWidget {
  final _OverviewSummaryValues values;

  const _OverviewSummary({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final displayStyle = Theme.of(context).textTheme.displaySmall;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _OverviewMetricRow(
            value: values.totalGpa,
            label: L.of(context).dualisOverviewGpaTotalModules,
            valueStyle: displayStyle,
          ),
        ),
        _OverviewMetricRow(
          value: values.mainModulesGpa,
          label: L.of(context).dualisOverviewGpaMainModules,
          valueStyle: displayStyle,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _OverviewMetricRow(
            value: values.credits,
            label: L.of(context).dualisOverviewCredits,
            valueStyle: displayStyle,
          ),
        ),
      ],
    );
  }
}

class _OverviewMetricRow extends StatelessWidget {
  final String value;
  final String label;
  final TextStyle? valueStyle;

  const _OverviewMetricRow({
    required this.value,
    required this.label,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textBaseline: TextBaseline.alphabetic,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      children: <Widget>[
        Text(value, style: valueStyle),
        Padding(padding: const EdgeInsets.only(left: 16), child: Text(label)),
      ],
    );
  }
}

class _OverviewTableLayout {
  static const double horizontalMargin = 24;
  static const double columnSpacing = 10;
  static const double creditsWidth = 48;
  static const double gradeWidth = 48;
  static const double stateWidth = 32;

  final double moduleWidth;
  final double tableWidth;

  const _OverviewTableLayout({
    required this.moduleWidth,
    required this.tableWidth,
  });

  factory _OverviewTableLayout.fromWidth(double width) {
    final tableWidth = math.max(0.0, width).toDouble();
    final moduleWidth = math
        .max(
          0,
          tableWidth -
              (horizontalMargin * 2) -
              (columnSpacing * 3) -
              creditsWidth -
              gradeWidth -
              stateWidth,
        )
        .toDouble();
    return _OverviewTableLayout(
      moduleWidth: moduleWidth,
      tableWidth: tableWidth,
    );
  }
}

class _OverviewModulesSliver extends StatelessWidget {
  final List<Module> modules;
  final _OverviewTableLayout tableLayout;

  const _OverviewModulesSliver({
    super.key,
    required this.modules,
    required this.tableLayout,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return _OverviewTableHeader(
              key: const ValueKey<String>('dualis_overview_table_header'),
              tableLayout: tableLayout,
            );
          }

          final module = modules[index - 1];
          return _OverviewModuleRow(
            key: ValueKey<String>('dualis_overview_module_row_${index - 1}'),
            module: module,
            tableLayout: tableLayout,
          );
        },
        childCount: modules.length + 1,
        addAutomaticKeepAlives: false,
      ),
    );
  }
}

class _OverviewTableHeader extends StatelessWidget {
  final _OverviewTableLayout tableLayout;

  const _OverviewTableHeader({super.key, required this.tableLayout});

  @override
  Widget build(BuildContext context) {
    final localizations = L.of(context);
    return SizedBox(
      height: 50,
      width: tableLayout.tableWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _OverviewTableLayout.horizontalMargin,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: tableLayout.moduleWidth,
              child: Text(localizations.dualisOverviewModuleColumnHeader),
            ),
            const SizedBox(width: _OverviewTableLayout.columnSpacing),
            SizedBox(
              width: _OverviewTableLayout.creditsWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(localizations.dualisOverviewCreditsColumnHeader),
              ),
            ),
            const SizedBox(width: _OverviewTableLayout.columnSpacing),
            SizedBox(
              width: _OverviewTableLayout.gradeWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(localizations.dualisOverviewGradeColumnHeader),
              ),
            ),
            const SizedBox(width: _OverviewTableLayout.columnSpacing),
            SizedBox(
              width: _OverviewTableLayout.stateWidth,
              child: Tooltip(
                message: localizations.dualisOverviewPassedColumnHeader,
                child: const SizedBox(width: double.infinity, height: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewModuleRow extends StatelessWidget {
  final Module module;
  final _OverviewTableLayout tableLayout;

  const _OverviewModuleRow({
    super.key,
    required this.module,
    required this.tableLayout,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: Divider.createBorderSide(context)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, maxHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _OverviewTableLayout.horizontalMargin,
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: tableLayout.moduleWidth,
                  child: Text(
                    module.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: _OverviewTableLayout.columnSpacing),
                SizedBox(
                  width: _OverviewTableLayout.creditsWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(module.credits),
                  ),
                ),
                const SizedBox(width: _OverviewTableLayout.columnSpacing),
                SizedBox(
                  width: _OverviewTableLayout.gradeWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(module.grade),
                  ),
                ),
                const SizedBox(width: _OverviewTableLayout.columnSpacing),
                SizedBox(
                  width: _OverviewTableLayout.stateWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GradeStateIcon(state: module.state),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    final color = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.78);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
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
    final color = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.78);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        children: List<Widget>.generate(5, (index) {
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
