import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory(
    Platform.environment['SCREENSHOT_OUTPUT_DIR'] ??
        'screenshots/timetable-customization',
  )..createSync(recursive: true);
  Process? recording;
  final serial = Platform.environment['ANDROID_SERIAL'];
  const remoteVideo = '/sdcard/dualmate-timetable-loading.mp4';
  Future<void> finishRecording() async {
    final process = recording;
    if (process == null) return;
    recording = null;
    await process.exitCode;
    final pull = await Process.run('adb', [
      '-s',
      serial!,
      'pull',
      remoteVideo,
      '${directory.path}/loading-demo.mp4',
    ]);
    if (pull.exitCode != 0)
      throw StateError('Video capture failed: ${pull.stderr}');
    await Process.run('adb', ['-s', serial, 'shell', 'rm', remoteVideo]);
  }

  try {
    if (serial != null && Platform.environment['RECORD_UI_VIDEO'] == 'true') {
      await Process.run('adb', [
        '-s',
        serial,
        'shell',
        'rm',
        '-f',
        remoteVideo,
      ]);
      recording = await Process.start('adb', [
        '-s',
        serial,
        'shell',
        'screenrecord',
        '--size',
        '504x1122',
        '--bit-rate',
        '1500000',
        '--time-limit',
        '30',
        remoteVideo,
      ]);
    }
    await integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        await File('${directory.path}/$name.png').writeAsBytes(bytes);
        return true;
      },
      // integrationDriver calls exit(), so finally alone cannot export video.
      responseDataCallback: (_) => finishRecording(),
      writeResponseOnFailure: true,
    );
  } finally {
    await finishRecording();
  }
}
