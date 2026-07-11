import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

const String _reportKey = 'cold_navigation_profile';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      final profile = _asStringMap(data?[_reportKey]);
      if (profile == null) {
        throw StateError(
          'Missing $_reportKey report data. Available keys: '
          '${data?.keys.join(', ') ?? '<none>'}.',
        );
      }

      final outputDirectory = Directory(
        Platform.environment['PERF_OUTPUT_DIR'] ??
            'build/cold_navigation_profile/latest',
      );
      final timelineDirectory = Directory(
        '${outputDirectory.path}${Platform.pathSeparator}timelines',
      );
      await timelineDirectory.create(recursive: true);

      final scenarios = _asStringMap(profile['scenarios']);
      if (scenarios == null || scenarios.isEmpty) {
        throw StateError('The cold-navigation report contains no scenarios.');
      }

      final failures = <String>[];
      for (final entry in scenarios.entries) {
        final scenario = _asStringMap(entry.value);
        if (scenario == null) {
          failures.add('${entry.key}: invalid scenario data');
          continue;
        }

        final timelineKey = scenario['timeline_key'];
        final timeline = timelineKey is String && data != null
            ? data[timelineKey]
            : null;
        if (timeline is Map<String, dynamic>) {
          final timelineFile = File(
            '${timelineDirectory.path}${Platform.pathSeparator}${entry.key}.json',
          );
          await timelineFile.writeAsString(
            const JsonEncoder.withIndent('  ').convert(timeline),
          );
          scenario['timeline_file'] = timelineFile.path;
        }

        if (scenario['expected_final_state_reached'] != true) {
          failures.add('${entry.key}: expected final state was not reached');
        }
        if (scenario['is_animated'] == true &&
            scenario['intermediate_frames_rendered'] != true) {
          failures.add(
            '${entry.key}: animation did not render an intermediate frame',
          );
        }
        // Issue 1: A measured transition with zero frames must invalidate
        // the run, not be silently reported as smooth.
        final frameCount = scenario['frame_count'];
        if (frameCount is int && frameCount == 0) {
          failures.add(
            '${entry.key}: zero frames were assigned to this scenario '
            '(frame attribution failure)',
          );
        }
      }

      final report = <String, dynamic>{
        'run_id': Platform.environment['PERF_RUN_ID'] ?? 'manual',
        'recorded_at_utc': DateTime.now().toUtc().toIso8601String(),
        'profile': profile,
      };
      final reportFile = File(
        '${outputDirectory.path}${Platform.pathSeparator}report.json',
      );
      await reportFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
      );

      if (failures.isNotEmpty) {
        throw StateError(
          'Cold-navigation profile did not complete valid visible transitions. '
          'See ${reportFile.path}.\n${failures.join('\n')}',
        );
      }
    },
  );
}

Map<String, dynamic>? _asStringMap(Object? value) {
  if (value is! Map) return null;
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
