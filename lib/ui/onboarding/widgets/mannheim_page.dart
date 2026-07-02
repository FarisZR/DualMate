import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/service/mannheim/mannheim_course_service.dart';
import 'package:dualmate/ui/onboarding/viewmodels/mannheim_view_model.dart';
import 'package:dualmate/ui/onboarding/viewmodels/onboarding_view_model_base.dart';
import 'package:flutter/material.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

class MannheimPage extends StatefulWidget {
  @override
  _MannheimPageState createState() => _MannheimPageState();
}

class _MannheimPageState extends State<MannheimPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
          child: Center(
            child: Text(
              L.of(context).onboardingMannheimTitle,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
          child: Divider(),
        ),
        Text(
          L.of(context).onboardingMannheimDescription,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 32, 0, 0),
            child: SelectMannheimCourseWidget(),
          ),
        ),
      ],
    );
  }
}

class SelectMannheimCourseWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PropertyChangeConsumer<OnboardingStepViewModel, String>(
      builder:
          (
            BuildContext context,
            OnboardingStepViewModel? model,
            Set<String>? _,
          ) {
            if (model == null) return Container();
            var viewModel = model as MannheimViewModel;

            switch (viewModel.loadingState) {
              case LoadCoursesState.Loading:
                return _buildLoadingIndicator();
              case LoadCoursesState.Loaded:
                return _buildLoadedCourses(context, viewModel);
              case LoadCoursesState.Failed:
                return _buildLoadingError(context, viewModel);
            }
          },
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildLoadedCourses(
    BuildContext context,
    MannheimViewModel viewModel,
  ) {
    final courses = viewModel.filteredCourses;

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: L.of(context).onboardingMannheimSearchHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onChanged: viewModel.setSearchQuery,
            ),
          ),
          Expanded(
            child: courses.isEmpty
                ? _buildEmptyState(context, viewModel)
                : _buildCourseList(context, viewModel, courses),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList(
    BuildContext context,
    MannheimViewModel viewModel,
    List<MannheimCourse> courses,
  ) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: courses.length,
      itemBuilder: (BuildContext context, int index) =>
          _buildCourseListTile(viewModel, courses[index], context),
    );
  }

  Widget _buildCourseListTile(
    MannheimViewModel viewModel,
    MannheimCourse course,
    BuildContext context,
  ) {
    var isSelected = viewModel.selectedCourse == course;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: ValueKey("mannheim-course-${course.scheduleId}"),
        trailing: isSelected
            ? Icon(Icons.check, color: Theme.of(context).colorScheme.secondary)
            : null,
        title: Text(
          course.name,
          style: isSelected
              ? TextStyle(color: Theme.of(context).colorScheme.secondary)
              : null,
        ),
        subtitle: course.title.isEmpty ? null : Text(course.title),
        onTap: () => viewModel.setSelectedCourse(course),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, MannheimViewModel viewModel) {
    final message = viewModel.courses.isEmpty
        ? L.of(context).onboardingMannheimNoCourses
        : L.of(context).onboardingMannheimNoSearchResults;

    return Center(child: Text(message, textAlign: TextAlign.center));
  }

  Widget _buildLoadingError(BuildContext context, MannheimViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(L.of(context).onboardingMannheimLoadCoursesFailed),
          Padding(
            padding: const EdgeInsets.all(16),
            child: IconButton(
              onPressed: viewModel.loadCourses,
              tooltip: L.of(context).onboardingMannheimRetry,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
    );
  }
}
