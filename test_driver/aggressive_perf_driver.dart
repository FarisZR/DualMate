import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

const String _reportKey = 'aggressive_cold_navigation_frames';
const int _pixel8Pro120HzBudgetMicros = 8333;

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      final summary = data?[_reportKey];
      if (summary is! Map<String, dynamic>) {
        throw StateError('Missing $_reportKey frame summary.');
      }

      final outputFile = File('build/$_reportKey.summary.json');
      outputFile.parent.createSync(recursive: true);
      outputFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(summary),
      );
      final timeline = data?['aggressive_cold_navigation_timeline'];
      if (timeline is Map<String, dynamic>) {
        File(
          'build/aggressive_cold_navigation_timeline.json',
        ).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(timeline),
        );
      }

      final buildTimes = (summary['frame_build_times_us'] as List<dynamic>)
          .cast<int>();
      final rasterTimes = (summary['frame_raster_times_us'] as List<dynamic>)
          .cast<int>();
      final slowBuildFrames = buildTimes
          .where((duration) => duration > _pixel8Pro120HzBudgetMicros)
          .length;
      final slowRasterFrames = rasterTimes
          .where((duration) => duration > _pixel8Pro120HzBudgetMicros)
          .length;

      if (slowBuildFrames > 0 || slowRasterFrames > 0) {
        throw StateError(
          '120Hz frame budget missed: '
          'build=$slowBuildFrames raster=$slowRasterFrames. '
          'See ${outputFile.path}.',
        );
      }
    },
  );
}
