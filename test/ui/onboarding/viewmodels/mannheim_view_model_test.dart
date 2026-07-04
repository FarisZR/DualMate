import 'package:dualmate/common/logging/crash_reporting.dart'
    as crash_reporting;
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/service/mannheim/mannheim_course_service.dart';
import 'package:dualmate/ui/onboarding/viewmodels/mannheim_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    crash_reporting.reportExceptionImpl = (_, __) async {};
  });

  tearDown(() {
    crash_reporting.reportExceptionImpl =
        crash_reporting.reportExceptionToSentry;
  });

  test('loads Mannheim courses from the configured loader', () async {
    final viewModel = MannheimViewModel(
      _FakeScheduleSourceProvider(),
      loadCoursesFromSource: (_) async => [
        _course('WWI23B'),
        _course('WWI23A'),
      ],
    );

    await pumpEventQueue();

    expect(viewModel.loadingState, LoadCoursesState.Loaded);
    expect(viewModel.courses.map((course) => course.name), [
      'WWI23B',
      'WWI23A',
    ]);
    expect(viewModel.filteredCourses, viewModel.courses);
  });

  test('filters Mannheim courses case-insensitively', () async {
    final viewModel = MannheimViewModel(
      _FakeScheduleSourceProvider(),
      loadCoursesFromSource: (_) async => [
        _course('WWI23A'),
        _course('TINF23AI2'),
        _course('wrsw23ST1'),
      ],
    );

    await pumpEventQueue();
    viewModel.setSearchQuery('wi');

    expect(viewModel.filteredCourses.map((course) => course.name), ['WWI23A']);

    viewModel.setSearchQuery('ST');

    expect(viewModel.filteredCourses.map((course) => course.name), [
      'wrsw23ST1',
    ]);
  });

  test('toggles selected course and validity', () async {
    final course = _course('WWI23A');
    final viewModel = MannheimViewModel(
      _FakeScheduleSourceProvider(),
      loadCoursesFromSource: (_) async => [course],
    );

    await pumpEventQueue();

    expect(viewModel.isValid, isFalse);

    viewModel.setSelectedCourse(course);

    expect(viewModel.selectedCourse, course);
    expect(viewModel.isValid, isTrue);

    viewModel.setSelectedCourse(course);

    expect(viewModel.selectedCourse, isNull);
    expect(viewModel.isValid, isFalse);
  });

  test('saving selected Mannheim course delegates to schedule setup', () async {
    final course = _course('WWI23A');
    final sourceProvider = _FakeScheduleSourceProvider();
    final viewModel = MannheimViewModel(
      sourceProvider,
      loadCoursesFromSource: (_) async => [course],
    );

    await pumpEventQueue();
    viewModel.setSelectedCourse(course);
    await viewModel.save();

    expect(sourceProvider.savedCourse, course);
  });

  test('saving without a selected course does not change setup', () async {
    final sourceProvider = _FakeScheduleSourceProvider();
    final viewModel = MannheimViewModel(
      sourceProvider,
      loadCoursesFromSource: (_) async => [_course('WWI23A')],
    );

    await pumpEventQueue();
    await viewModel.save();

    expect(sourceProvider.savedCourse, isNull);
  });

  test(
    'failed course loading enters failure state and clears courses',
    () async {
      final viewModel = MannheimViewModel(
        _FakeScheduleSourceProvider(),
        loadCoursesFromSource: (_) async => throw StateError('offline'),
      );

      await pumpEventQueue();

      expect(viewModel.loadingState, LoadCoursesState.Failed);
      expect(viewModel.courses, isEmpty);
      expect(viewModel.filteredCourses, isEmpty);
    },
  );
}

MannheimCourse _course(String profileName) {
  return MannheimCourse.fromProfileName(profileName);
}

class _FakeScheduleSourceProvider implements ScheduleSourceProvider {
  MannheimCourse? savedCourse;

  @override
  Future<void> setupForMannheim(MannheimCourse selectedCourse) async {
    savedCourse = selectedCourse;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
