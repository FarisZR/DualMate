import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final path =
        Platform.environment['TIMETABLE_PERF_OUTPUT'] ??
        'build/timetable-performance/report.json';
    await File(path).parent.create(recursive: true);
    await File(path)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  },
);
