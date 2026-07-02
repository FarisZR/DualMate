import 'dart:async';

import 'package:dualmate/common/logging/crash_reporting.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/service/mannheim/mannheim_course_service.dart';
import 'package:dualmate/ui/onboarding/viewmodels/onboarding_view_model_base.dart';

typedef MannheimCourseLoader = Future<List<MannheimCourse>> Function();

enum LoadCoursesState { Loading, Loaded, Failed }

class MannheimViewModel extends OnboardingStepViewModel {
  final ScheduleSourceProvider _scheduleSourceProvider;
  final MannheimCourseLoader _loadCoursesFromSource;

  LoadCoursesState _loadingState = LoadCoursesState.Loading;
  LoadCoursesState get loadingState => _loadingState;

  MannheimCourse? _selectedCourse;
  MannheimCourse? get selectedCourse => _selectedCourse;

  List<MannheimCourse> _courses = [];
  List<MannheimCourse> get courses => _courses;

  String _searchQuery = "";
  String get searchQuery => _searchQuery;

  List<MannheimCourse> get filteredCourses {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _courses;

    return _courses
        .where((course) => course.name.toLowerCase().contains(query))
        .toList();
  }

  MannheimViewModel(
    this._scheduleSourceProvider, {
    MannheimCourseLoader? loadCoursesFromSource,
  }) : _loadCoursesFromSource =
           loadCoursesFromSource ?? MannheimCourseService().loadCourses {
    setIsValid(false);
    loadCourses();
  }

  Future<void> loadCourses() async {
    _loadingState = LoadCoursesState.Loading;
    notifyListeners("loadingState");

    try {
      _courses = await _loadCoursesFromSource();
      _loadingState = LoadCoursesState.Loaded;
    } catch (ex, trace) {
      _courses = [];
      _loadingState = LoadCoursesState.Failed;
      unawaited(reportException(ex, trace));
    }

    notifyListeners("loadingState");
    notifyListeners("courses");
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners("searchQuery");
    notifyListeners("filteredCourses");
  }

  void setSelectedCourse(MannheimCourse course) {
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
