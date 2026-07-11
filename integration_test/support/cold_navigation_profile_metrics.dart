const int frameBudget120HzUs = 8333;
const int frameBudget60HzUs = 16667;
const int frameBudget30HzUs = 33333;
const int frameBudget20HzUs = 50000;

/// Records a single [FrameTiming]'s key data alongside its wall-clock
/// timestamp so frames can be attributed to scenarios after all timing
/// batches have been flushed.
class RecordedFrameTiming {
  final int timestampMicroseconds;
  final int buildDurationUs;
  final int rasterDurationUs;

  const RecordedFrameTiming({
    required this.timestampMicroseconds,
    required this.buildDurationUs,
    required this.rasterDurationUs,
  });

  factory RecordedFrameTiming.fromFrameTiming(
    dynamic frameTiming,
  ) {
    return RecordedFrameTiming(
      timestampMicroseconds: frameTiming.timestampMicroseconds as int,
      buildDurationUs:
          (frameTiming.buildDuration as Duration).inMicroseconds,
      rasterDurationUs:
          (frameTiming.rasterDuration as Duration).inMicroseconds,
    );
  }
}

/// Boundary of a single measured scenario in wall-clock time.
class ScenarioTimingBoundary {
  final int startMicroseconds;
  final int endMicroseconds;

  const ScenarioTimingBoundary({
    required this.startMicroseconds,
    required this.endMicroseconds,
  });

  bool contains(int timestampUs) =>
      timestampUs >= startMicroseconds && timestampUs < endMicroseconds;
}

/// Selects the [RecordedFrameTiming]s whose timestamps fall within [boundary].
///
/// This replaces the old list-position slicing that broke when Flutter batched
/// frame-timing delivery.  After all scenarios have run and the frame-timing
/// callback has been drained, each frame is assigned to the scenario whose
/// wall-clock window produced it.
List<RecordedFrameTiming> assignFramesToScenario({
  required List<RecordedFrameTiming> allTimings,
  required ScenarioTimingBoundary boundary,
}) {
  return allTimings
      .where((timing) => boundary.contains(timing.timestampMicroseconds))
      .toList(growable: false);
}

Map<String, dynamic> summarizeFrameDurations({
  required Iterable<int> buildDurationsUs,
  required Iterable<int> rasterDurationsUs,
  required int interactionDurationUs,
  required bool finalStateReached,
  required bool intermediateFramesRendered,
  required bool isAnimated,
}) {
  final build = List<int>.unmodifiable(buildDurationsUs);
  final raster = List<int>.unmodifiable(rasterDurationsUs);
  final combined = List<int>.generate(
    build.length > raster.length ? build.length : raster.length,
    (index) {
      final buildDuration = index < build.length ? build[index] : 0;
      final rasterDuration = index < raster.length ? raster[index] : 0;
      return buildDuration > rasterDuration ? buildDuration : rasterDuration;
    },
    growable: false,
  );

  return <String, dynamic>{
    'frame_count': combined.length,
    'interaction_duration_us': interactionDurationUs,
    'expected_final_state_reached': finalStateReached,
    'is_animated': isAnimated,
    'intermediate_frames_rendered': intermediateFramesRendered,
    'ui_build': _durationSummary(build),
    'raster': _durationSummary(raster),
    'combined': _durationSummary(combined),
  };
}

Map<String, dynamic> _durationSummary(List<int> durationsUs) {
  final sorted = List<int>.of(durationsUs)..sort();
  final overBudgetCount = _countOver(sorted, frameBudget120HzUs);
  final pctOverBudget = sorted.isEmpty
      ? 0.0
      : (overBudgetCount / sorted.length * 100);

  return <String, dynamic>{
    'durations_us': durationsUs,
    'p95_us': _percentile(sorted, 0.95),
    'p99_us': _percentile(sorted, 0.99),
    'worst_us': sorted.isEmpty ? 0 : sorted.last,
    'over_8_33ms_count': overBudgetCount,
    'over_8_33ms_pct': pctOverBudget.round(),
    'over_16_67ms_count': _countOver(sorted, frameBudget60HzUs),
    'over_33ms_count': _countOver(sorted, frameBudget30HzUs),
    'over_50ms_count': _countOver(sorted, frameBudget20HzUs),
    'consecutive_missed_frames': longestConsecutiveMissedFrames(
      durationsUs,
      frameBudget120HzUs,
    ),
  };
}

int _percentile(List<int> sorted, double percentile) {
  if (sorted.isEmpty) return 0;
  final index = ((sorted.length - 1) * percentile).round();
  return sorted[index];
}

int _countOver(Iterable<int> values, int budgetUs) {
  return values.where((duration) => duration > budgetUs).length;
}

/// Computes the longest run of consecutive over-budget frames from the
/// original temporal ordering.
int longestConsecutiveMissedFrames(
  List<int> durationsInTemporalOrder,
  int budgetUs,
) {
  var longest = 0;
  var current = 0;
  for (final duration in durationsInTemporalOrder) {
    if (duration > budgetUs) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 0;
    }
  }
  return longest;
}
