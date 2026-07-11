import 'dart:ui' show FrameTiming;

const int frameBudget120HzUs = 8333;
const int frameBudget60HzUs = 16667;
const int frameBudget30HzUs = 33333;
const int frameBudget20HzUs = 50000;

/// Typed, serializable subset of [FrameTiming].
///
/// Keeping this conversion typed ensures Flutter API changes fail at compile
/// time instead of surfacing only during a physical-device profile run.
class RecordedFrameTiming {
  final int frameNumber;
  final int buildDurationUs;
  final int rasterDurationUs;

  const RecordedFrameTiming({
    required this.frameNumber,
    required this.buildDurationUs,
    required this.rasterDurationUs,
  });

  factory RecordedFrameTiming.fromFrameTiming(FrameTiming timing) {
    return RecordedFrameTiming(
      frameNumber: timing.frameNumber,
      buildDurationUs: timing.buildDuration.inMicroseconds,
      rasterDurationUs: timing.rasterDuration.inMicroseconds,
    );
  }
}

List<RecordedFrameTiming> recordFrameTimings(Iterable<FrameTiming> timings) {
  return timings
      .map(RecordedFrameTiming.fromFrameTiming)
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
    'over_8_33ms_pct': pctOverBudget,
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
