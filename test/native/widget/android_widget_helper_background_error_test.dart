import 'package:dualmate/native/widget/android_widget_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.fariszr.dualmate/widget');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('requestWidgetRefresh swallows MissingPluginException in background',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException('not attached in background engine');
    });

    final helper = AndroidWidgetHelper();

    await helper.requestWidgetRefresh();
  });

  test('disableWidget swallows generic exceptions', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw Exception('bridge unavailable');
    });

    final helper = AndroidWidgetHelper();

    await helper.disableWidget();
  });
}
