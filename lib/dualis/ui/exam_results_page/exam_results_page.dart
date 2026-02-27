import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/util/platform_util.dart';
import 'package:dualmate/dualis/model/exam_grade.dart';
import 'package:dualmate/dualis/ui/viewmodels/study_grades_view_model.dart';
import 'package:flutter/material.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

class ExamResultsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Text(
                L.of(context).dualisExamResultsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Text(L.of(context).dualisExamResultsSemesterSelect),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 0, 0),
                    child: PropertyChangeConsumer<StudyGradesViewModel, String>(
                      properties: const [
                        "currentSemesterName",
                        "allSemesterNames",
                      ],
                      builder: (
                        BuildContext context,
                        StudyGradesViewModel? model,
                        Set<String>? properties,
                      ) {
                        if (model == null) return Container();
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
                                (n) => DropdownMenuItem<String>(
                                  child: Text(n),
                                  value: n,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
            PropertyChangeConsumer<StudyGradesViewModel, String>(
              properties: const [
                "currentSemester",
                "isLoadingCurrentSemester",
              ],
              builder: (
                BuildContext context,
                StudyGradesViewModel? model,
                Set<String>? properties,
              ) =>
                  model == null
                      ? Container()
                      : buildModulesColumn(context, model),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildModulesColumn(
      BuildContext context, StudyGradesViewModel viewModel) {
    final showLoading = viewModel.isLoadingCurrentSemester &&
        viewModel.currentSemester.modules.isEmpty;

    return AnimatedSwitcher(
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        List<Widget> children = previousChildren;
        if (currentChild != null) {
          children = children.toList()..add(currentChild);
        }
        return Stack(
          children: children,
          alignment: Alignment.topCenter,
        );
      },
      child: showLoading
          ? const _SemesterLoadingPlaceholder(
              key: ValueKey<String>('dualis_semester_loading'),
            )
          : Column(
              key: ValueKey("semester_${viewModel.currentSemester.name}"),
              children: buildModulesDataTables(context, viewModel),
            ),
      duration: const Duration(milliseconds: 200),
    );
  }

  List<Widget> buildModulesDataTables(
      BuildContext context, StudyGradesViewModel viewModel) {
    var dataTables = <Widget>[];

    var isFirstModule = true;
    for (var module in viewModel.currentSemester.modules) {
      dataTables.add(DataTable(
        horizontalMargin: 24,
        columnSpacing: 0,
        dataRowHeight: 45,
        headingRowHeight: 65,
        rows: buildModuleDataRows(context, module),
        columns: buildModuleColumns(context, module,
            displayGradeHeader: isFirstModule),
      ));
      isFirstModule = false;
    }
    return dataTables;
  }

  List<DataRow> buildModuleDataRows(BuildContext context, var module) {
    var dataRows = <DataRow>[];

    for (var exam in module.exams) {
      dataRows.add(
        DataRow(
          cells: <DataCell>[
            DataCell(Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  exam.name ?? "",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  exam.semester ?? "",
                  style: Theme.of(context).textTheme.bodySmall,
                  textScaleFactor: exam.semester == "" ? 0 : 1,
                ),
              ],
            )),
            DataCell.empty,
            DataCell(Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
              child: _examGradeToWidget(context, exam.grade),
            )),
          ],
        ),
      );
    }
    return dataRows;
  }

  Widget _examGradeToWidget(BuildContext context, ExamGrade grade) {
    switch (grade.state) {
      case ExamGradeState.NotGraded:
        return Text("");
      case ExamGradeState.Graded:
        return Text(grade.gradeValue);
      case ExamGradeState.Passed:
        return Text(L.of(context).examPassed);
      case ExamGradeState.Failed:
        return Text(L.of(context).examNotPassed);
    }
  }

  List<DataColumn> buildModuleColumns(BuildContext context, var module,
      {var displayGradeHeader = false}) {
    var displayWidth = MediaQuery.of(context).size.width;

    if (PlatformUtil.isTablet()) {
      displayWidth -= 250;
    }

    return <DataColumn>[
      DataColumn(
        label: ConstrainedBox(
          constraints: BoxConstraints.expand(
            width: displayWidth * 0.5 -
                24, // Subtract the horizontal padding of the DataTable
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 10, 16),
              child: Text(
                (module.name ?? ""),
                style: Theme.of(context).textTheme.titleSmall,
                softWrap: true,
              ),
            ),
          ),
        ),
        numeric: false,
      ),
      DataColumn(
        label: ConstrainedBox(
          constraints: BoxConstraints.expand(
            width: displayWidth * 0.25,
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 10, 16),
              child: Text(
                  "${L.of(context).dualisExamResultsCreditsColumnHeader}:  ${module.credits}"),
            ),
          ),
        ),
        numeric: true,
      ),
      DataColumn(
        label: ConstrainedBox(
          constraints: BoxConstraints.expand(
            width: displayWidth * 0.25,
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
              child: Text(
                displayGradeHeader
                    ? L.of(context).dualisExamResultsGradeColumnHeader
                    : "",
              ),
            ),
          ),
        ),
        numeric: true,
      ),
    ];
  }
}

class _SemesterLoadingPlaceholder extends StatelessWidget {
  const _SemesterLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.78);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: List.generate(4, (index) {
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
