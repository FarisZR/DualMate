import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/cold_navigation_profile_metrics.dart';

void main() {
  test('reports independent build, raster, and combined frame budgets', () {
    final summary = summarizeFrameDurations(
      buildDurationsUs: const [1000, 9000, 17000, 51000],
      rasterDurationsUs: const [2000, 8000, 34000, 4000],
      interactionDurationUs: 220000,
      finalStateReached: true,
      intermediateFramesRendered: true,
      isAnimated: true,
    );

    expect(summary['frame_count'], 4);
    expect(summary['interaction_duration_us'], 220000);
    expect(summary['expected_final_state_reached'], isTrue);
    expect(summary['intermediate_frames_rendered'], isTrue);

    final build = summary['ui_build']! as Map<String, dynamic>;
    expect(build['p95_us'], 51000);
    expect(build['p99_us'], 51000);
    expect(build['worst_us'], 51000);
    expect(build['over_8_33ms_count'], 3);
    expect(build['over_8_33ms_pct'], 75);
    expect(build['over_16_67ms_count'], 2);
    expect(build['over_33ms_count'], 1);
    expect(build['over_50ms_count'], 1);

    final raster = summary['raster']! as Map<String, dynamic>;
    expect(raster['over_8_33ms_count'], 1);
    expect(raster['over_16_67ms_count'], 1);
    expect(raster['over_33ms_count'], 1);
    expect(raster['over_50ms_count'], 0);

    final combined = summary['combined']! as Map<String, dynamic>;
    expect(combined['over_8_33ms_count'], 3);
    expect(combined['over_16_67ms_count'], 2);
    expect(combined['over_33ms_count'], 2);
    expect(combined['over_50ms_count'], 1);
  });

  test('handles a zero-frame interaction without inventing percentiles', () {
    final summary = summarizeFrameDurations(
      buildDurationsUs: const [],
      rasterDurationsUs: const [],
      interactionDurationUs: 0,
      finalStateReached: false,
      intermediateFramesRendered: false,
      isAnimated: false,
    );

    expect(summary['frame_count'], 0);
    expect(summary['expected_final_state_reached'], isFalse);
    final combined = summary['combined']! as Map<String, dynamic>;
    expect(combined['p95_us'], 0);
    expect(combined['p99_us'], 0);
    expect(combined['worst_us'], 0);
    expect(combined['over_8_33ms_pct'], 0);
  });

  test('assignFramesToScenario selects only frames within the boundary', () {
    final timings = [
      const RecordedFrameTiming(
        timestampMicroseconds: 1000,
        buildDurationUs: 5000,
        rasterDurationUs: 4000,
      ),
      const RecordedFrameTiming(
        timestampMicroseconds: 2000,
        buildDurationUs: 9000,
        rasterDurationUs: 8000,
      ),
      const RecordedFrameTiming(
        timestampMicroseconds: 3000,
        buildDurationUs: 7000,
        rasterDurationUs: 6000,
      ),
      const RecordedFrameTiming(
        timestampMicroseconds: 5000,
        buildDurationUs: 3000,
        rasterDurationUs: 2000,
      ),
    ];

    final boundary = const ScenarioTimingBoundary(
      startMicroseconds: 1500,
      endMicroseconds: 4500,
    );

    final selected = assignFramesToScenario(
      allTimings: timings,
      boundary: boundary,
    );

    expect(selected.length, 2);
    expect(selected[0].timestampMicroseconds, 2000);
    expect(selected[1].timestampMicroseconds, 3000);
  });

  test(
    'longestConsecutiveMissedFrames finds the longest run above budget',
    () {
      final durations = [5000, 9000, 10000, 5000, 12000, 11000, 9000, 5000];
      expect(
        longestConsecutiveMissedFrames(durations, frameBudget120HzUs),
        3,
      );

      expect(longestConsecutiveMissedFrames([5000, 5000], frameBudget120HzUs), 0);
      expect(longestConsecutiveMissedFrames([], frameBudget120HzUs), 0);
    },
  );
}
