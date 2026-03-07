import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/dualis/ui/exam_results_page/exam_results_page.dart';
import 'package:dualmate/dualis/ui/login/dualis_login_page.dart';
import 'package:dualmate/dualis/ui/study_overview/study_overview_page.dart';
import 'package:dualmate/dualis/ui/viewmodels/study_grades_view_model.dart';
import 'package:dualmate/ui/pager_widget.dart';
import 'package:flutter/material.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';

class DualisPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    StudyGradesViewModel viewModel =
        Provider.of<StudyGradesViewModel>(context, listen: false);

    return PropertyChangeProvider<StudyGradesViewModel, String>(
      value: viewModel,
      child: PropertyChangeConsumer<StudyGradesViewModel, String>(
        properties: const ["loginState"],
        builder: (
          BuildContext context,
          StudyGradesViewModel? model,
          Set<String>? properties,
        ) {
          final current = model ?? viewModel;
          final child = current.loginState == LoginState.LoggedIn
              ? PagerWidget(
                  key: const ValueKey<String>('dualis_logged_in_pager'),
                  pagesId: "dualis_pager",
                  pages: <PageDefinition>[
                    PageDefinition(
                      text: L.of(context).pageDualisOverview,
                      icon: const Icon(Icons.dashboard),
                      builder: (BuildContext context) => StudyOverviewPage(),
                    ),
                    PageDefinition(
                      text: L.of(context).pageDualisExams,
                      icon: const Icon(Icons.book),
                      builder: (BuildContext context) => ExamResultsPage(),
                    ),
                  ],
                )
              : const DualisLoginPage(
                  key: ValueKey<String>('dualis_login_page'),
                );

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: child,
          );
        },
      ),
    );
  }
}
