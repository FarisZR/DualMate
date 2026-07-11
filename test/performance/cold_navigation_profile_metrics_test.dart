import '../../integration_test/support/cold_navigation_profile_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
