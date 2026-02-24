import 'package:dualmate/native/widget/android_widget_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidWidgetHelper.platform, null);
  });

  test('requestWidgetRefresh swallows MissingPluginException', () async {
    final helper = AndroidWidgetHelper();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      AndroidWidgetHelper.platform,
      (MethodCall _) async {
        throw MissingPluginException('No handler in background isolate');
      },
    );

    await helper.requestWidgetRefresh();
  });

  test('requestWidgetRefresh swallows PlatformException', () async {
    final helper = AndroidWidgetHelper();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      AndroidWidgetHelper.platform,
      (MethodCall _) async {
        throw PlatformException(code: 'channel_error');
      },
    );

    await helper.requestWidgetRefresh();
  });
}
