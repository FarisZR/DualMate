import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/dualis/ui/exam_results_page/exam_results_page.dart';
import 'package:dualmate/dualis/ui/login/dualis_login_page.dart';
import 'package:dualmate/dualis/ui/study_overview/study_overview_page.dart';
import 'package:dualmate/dualis/ui/viewmodels/study_grades_view_model.dart';
import 'package:dualmate/ui/pager_widget.dart';
import 'package:flutter/material.dart';
import 'package:property_change_notifier/property_change_notifier.dart';
import 'package:provider/provider.dart';

class DualisPage extends StatefulWidget {
  final int sectionIndex;

  const DualisPage({super.key, required this.sectionIndex});

  @override
  State<DualisPage> createState() => _DualisPageState();
}

class _DualisPageState extends State<DualisPage> with WidgetsBindingObserver {
  ValueNotifier<int>? _currentEntryIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = Provider.of<ValueNotifier<int>>(context, listen: false);
    if (!identical(_currentEntryIndex, notifier)) {
      _currentEntryIndex?.removeListener(_handleSectionChanged);
      _currentEntryIndex = notifier;
      _currentEntryIndex?.addListener(_handleSectionChanged);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handleSectionChanged();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _currentEntryIndex?.removeListener(_handleSectionChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    _handleSectionChanged();
  }

  void _handleSectionChanged() {
    if (!mounted || _currentEntryIndex?.value != widget.sectionIndex) {
      return;
    }

    final viewModel = Provider.of<StudyGradesViewModel>(context, listen: false);
    viewModel.onPageVisible();
  }

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
          final child = switch (current.loginState) {
            LoginState.LoggedIn => PagerWidget(
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
              ),
            LoginState.RestoringSession => const _DualisSessionLoadingPage(
                key: ValueKey<String>('dualis_restoring_page'),
              ),
            _ => const DualisLoginPage(
                key: ValueKey<String>('dualis_login_page'),
              ),
          };

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: child,
          );
        },
      ),
    );
  }
}

class _DualisSessionLoadingPage extends StatelessWidget {
  const _DualisSessionLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}
