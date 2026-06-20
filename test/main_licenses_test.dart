import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'DHBWStudentInformationApp AGPL license asset is bundled and loadable',
    () async {
      final license = await rootBundle.loadString(
        'assets/licenses/DHBWStudentInformationApp_LICENSE.txt',
      );

      expect(license, contains('GNU AFFERO GENERAL PUBLIC LICENSE'));
      expect(license, contains('Version 3, 19 November 2007'));
      expect(license, contains('END OF TERMS AND CONDITIONS'));
    },
  );
}
