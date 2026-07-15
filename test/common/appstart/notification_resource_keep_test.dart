import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release resource shrinking keeps the notification icon', () {
    final keepFile = File('android/app/src/main/res/raw/keep.xml');

    expect(keepFile.existsSync(), isTrue);
    expect(
      keepFile.readAsStringSync(),
      contains('tools:keep="@drawable/outline_event_note_24"'),
    );
  });
}
