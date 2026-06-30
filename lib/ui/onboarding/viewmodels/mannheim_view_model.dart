import 'dart:async';

import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/service/mannheim/mannheim_course_scraper.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:dualmate/ui/onboarding/viewmodels/onboarding_view_model_base.dart';

typedef MannheimCourseLoader = Future<List<Course>> Function();

enum LoadCoursesState { Loading, Loaded, Failed }

class MannheimViewModel extends OnboardingStepViewModel {
  final ScheduleSourceProvider _scheduleSourceProvider;
  final MannheimCourseLoader _loadCoursesFromSource;

  LoadCoursesState _loadingState = LoadCoursesState.Loading;
  LoadCoursesState get loadingState => _loadingState;

  Course? _selectedCourse;
  Course? get selectedCourse => _selectedCourse;

  List<Course> _courses = [];
  List<Course> get courses => _courses;

  MannheimViewModel(
    this._scheduleSourceProvider, {
    MannheimCourseLoader? loadCoursesFromSource,
  }) : _loadCoursesFromSource =
           loadCoursesFromSource ?? MannheimCourseScraper().loadCourses {
    setIsValid(false);
    loadCourses();
  }

  Future<void> loadCourses() async {
    _loadingState = LoadCoursesState.Loading;
    notifyListeners("loadingState");

    try {
      await Future.delayed(Duration(seconds: 1));
      _courses = await _loadCoursesFromSource();
      _loadingState = LoadCoursesState.Loaded;
    } catch (ex, trace) {
      _courses = [];
      _loadingState = LoadCoursesState.Failed;
      if (!isExpectedScheduleFetchFailure(ex)) {
        unawaited(reportException(ex, trace));
      }
    }

    notifyListeners("loadingState");
    notifyListeners("courses");
  }

  void setSelectedCourse(Course course) {
    if (_selectedCourse == course) {
      _selectedCourse = null;
    } else {
      _selectedCourse = course;
    }

    setIsValid(_selectedCourse != null);
  }

  @override
  Future<void> save() async {
    if (_selectedCourse == null) {
      return;
    }
    await _scheduleSourceProvider.setupForMannheim(_selectedCourse!);
  }
}
