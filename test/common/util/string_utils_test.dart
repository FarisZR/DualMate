import 'package:dualmate/common/util/string_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('String interpolation', () async {
    var format = "%0 %1!";
    var result = interpolate(format, ["Hello", "world"]);

    expect(result, "Hello world!");
  });
}
