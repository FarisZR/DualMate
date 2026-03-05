import 'package:dualmate/common/ui/app_launch_dialogs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exact alarm dialog is never auto-shown on app launch', () {
    expect(shouldShowExactAlarmDialogForLaunchCount(0), isFalse);
    expect(shouldShowExactAlarmDialogForLaunchCount(1), isFalse);
    expect(shouldShowExactAlarmDialogForLaunchCount(8), isFalse);
  });
}
