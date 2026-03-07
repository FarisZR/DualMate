import 'package:dualmate/common/ui/app_launch_dialogs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exact alarm dialog is deferred until second launch', () {
    expect(shouldShowExactAlarmDialogForLaunchCount(0), isFalse);
    expect(shouldShowExactAlarmDialogForLaunchCount(1), isTrue);
  });
}
