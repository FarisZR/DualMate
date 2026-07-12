import 'dart:math' as math;

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/dualis/model/exam.dart';
import 'package:dualmate/dualis/model/exam_grade.dart';
import 'package:dualmate/dualis/model/module.dart';
import 'package:dualmate/dualis/model/semester.dart';
import 'package:dualmate/dualis/ui/viewmodels/study_grades_view_model.dart';
import 'package:dualmate/dualis/ui/widgets/dualis_sliver_content_transition.dart';
import 'package:flutter/material.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';

class ExamResultsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<StudyGradesViewModel>(context, listen: false);

    return RefreshIndicator(
      onRefresh: () => viewModel.refreshData(force: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableLayout = _ExamTableLayout.fromWidth(constraints.maxWidth);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Text(
                    L.of(context).dualisExamResultsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _SemesterSelector()),
              PropertyChangeConsumer<StudyGradesViewModel, String>(
                properties: const [
                  'currentSemester',
                  'isLoadingCurrentSemester',
                ],
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
                          model.isLoadingCurrentSemester &&
                          model.currentSemester.modules.isEmpty;
                      return DualisSliverContentTransition(
                        showLoading: showLoading,
                        contentKey: model.currentSemester,
                        duration: const Duration(milliseconds: 200),
                        loadingBuilder: (_) => const SliverToBoxAdapter(
                          child: _SemesterLoadingPlaceholder(
                            key: ValueKey<String>('dualis_semester_loading'),
                          ),
                        ),
                        contentBuilder: (context) => _ExamResultsSliver(
                          data: _ExamResultsRenderData.from(
                            model.currentSemester,
                            L.of(context),
                          ),
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
}

class _SemesterSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Text(L.of(context).dualisExamResultsSemesterSelect),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: PropertyChangeConsumer<StudyGradesViewModel, String>(
              properties: const ['currentSemesterName', 'allSemesterNames'],
              builder:
                  (
                    BuildContext context,
                    StudyGradesViewModel? model,
                    Set<String>? properties,
                  ) {
                    if (model == null) return const SizedBox.shrink();
                    return DropdownButton<String>(
                      onChanged: (value) {
                        if (value != null) {
                          model.loadSemester(value);
                        }
                      },
                      value: model.currentSemesterName.isEmpty
                          ? null
                          : model.currentSemesterName,
                      items: model.allSemesterNames
                          .map(
                            (name) => DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamTableLayout {
  final double examWidth;
  final double creditsWidth;
  final double gradeWidth;
  final double tableWidth;

  const _ExamTableLayout({
    required this.examWidth,
    required this.creditsWidth,
    required this.gradeWidth,
    required this.tableWidth,
  });

  factory _ExamTableLayout.fromWidth(double width) {
    final contentWidth = math.max(0.0, width - 48).toDouble();
    return _ExamTableLayout(
      examWidth: contentWidth * 0.5,
      creditsWidth: contentWidth * 0.25,
      gradeWidth: contentWidth * 0.25,
      tableWidth: width,
    );
  }
}

class _ExamResultsRenderData {
  final List<_ExamModuleRenderData> modules;
  final List<int> moduleStarts;
  final int childCount;

  const _ExamResultsRenderData({
    required this.modules,
    required this.moduleStarts,
    required this.childCount,
  });

  factory _ExamResultsRenderData.from(Semester semester, L localizations) {
    final modules = <_ExamModuleRenderData>[];
    final moduleStarts = <int>[];
    var childCount = 0;

    for (
      var moduleIndex = 0;
      moduleIndex < semester.modules.length;
      moduleIndex += 1
    ) {
      final module = semester.modules[moduleIndex];
      moduleStarts.add(childCount);
      modules.add(
        _ExamModuleRenderData.from(
          module,
          localizations,
          displayGradeHeader: moduleIndex == 0,
        ),
      );
      childCount += module.exams.length + 1;
    }

    return _ExamResultsRenderData(
      modules: modules,
      moduleStarts: moduleStarts,
      childCount: childCount,
    );
  }

  int moduleIndexFor(int itemIndex) {
    var low = 0;
    var high = moduleStarts.length - 1;
    while (low <= high) {
      final middle = (low + high) ~/ 2;
      if (moduleStarts[middle] <= itemIndex) {
        if (middle == moduleStarts.length - 1 ||
            moduleStarts[middle + 1] > itemIndex) {
          return middle;
        }
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return 0;
  }
}

class _ExamModuleRenderData {
  final String name;
  final String creditsHeader;
  final List<_ExamRowRenderData> rows;
  final bool displayGradeHeader;

  const _ExamModuleRenderData({
    required this.name,
    required this.creditsHeader,
    required this.rows,
    required this.displayGradeHeader,
  });

  factory _ExamModuleRenderData.from(
    Module module,
    L localizations, {
    required bool displayGradeHeader,
  }) {
    return _ExamModuleRenderData(
      name: module.name,
      creditsHeader:
          '${localizations.dualisExamResultsCreditsColumnHeader}:  ${module.credits}',
      rows: module.exams
          .map((exam) => _ExamRowRenderData.from(exam, localizations))
          .toList(growable: false),
      displayGradeHeader: displayGradeHeader,
    );
  }
}

class _ExamRowRenderData {
  final String name;
  final String semester;
  final String grade;

  const _ExamRowRenderData({
    required this.name,
    required this.semester,
    required this.grade,
  });

  factory _ExamRowRenderData.from(Exam exam, L localizations) {
    final grade = switch (exam.grade.state) {
      ExamGradeState.NotGraded => '',
      ExamGradeState.Graded => exam.grade.gradeValue,
      ExamGradeState.Passed => localizations.examPassed,
      ExamGradeState.Failed => localizations.examNotPassed,
    };

    return _ExamRowRenderData(
      name: exam.name,
      semester: exam.semester,
      grade: grade,
    );
  }
}

class _ExamResultsSliver extends StatelessWidget {
  final _ExamResultsRenderData data;
  final _ExamTableLayout tableLayout;

  const _ExamResultsSliver({required this.data, required this.tableLayout});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final moduleIndex = data.moduleIndexFor(index);
          final module = data.modules[moduleIndex];
          final rowIndex = index - data.moduleStarts[moduleIndex];

          if (rowIndex == 0) {
            return _ExamModuleHeader(
              key: ValueKey<String>('dualis_exam_module_header_$moduleIndex'),
              module: module,
              tableLayout: tableLayout,
            );
          }

          return _ExamRow(
            key: ValueKey<String>(
              'dualis_exam_row_${moduleIndex}_${rowIndex - 1}',
            ),
            row: module.rows[rowIndex - 1],
            tableLayout: tableLayout,
          );
        },
        childCount: data.childCount,
        addAutomaticKeepAlives: false,
      ),
    );
  }
}

class _ExamModuleHeader extends StatelessWidget {
  final _ExamModuleRenderData module;
  final _ExamTableLayout tableLayout;

  const _ExamModuleHeader({
    super.key,
    required this.module,
    required this.tableLayout,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SizedBox(
        height: 65,
        width: tableLayout.tableWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.titleSmall!,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                SizedBox(
                  width: tableLayout.examWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10, bottom: 16),
                    child: Text(
                      module.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  width: tableLayout.creditsWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10, bottom: 16),
                    child: Text(module.creditsHeader),
                  ),
                ),
                SizedBox(
                  width: tableLayout.gradeWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        module.displayGradeHeader
                            ? L.of(context).dualisExamResultsGradeColumnHeader
                            : '',
                      ),
                    ),
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

class _ExamRow extends StatelessWidget {
  final _ExamRowRenderData row;
  final _ExamTableLayout tableLayout;

  const _ExamRow({super.key, required this.row, required this.tableLayout});

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
          constraints: const BoxConstraints(minHeight: 45, maxHeight: 72),
          child: SizedBox(
            width: tableLayout.tableWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: tableLayout.examWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            row.name,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (row.semester.isNotEmpty)
                            Text(
                              row.semester,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: tableLayout.creditsWidth),
                  SizedBox(
                    width: tableLayout.gradeWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(row.grade),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SemesterLoadingPlaceholder extends StatelessWidget {
  const _SemesterLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.78);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: List<Widget>.generate(4, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 54,
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
