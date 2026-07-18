import 'dart:async';

import 'package:dualmate/common/ui/notification_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialize does not wait for runtime permission completion', () async {
    final permissionCompleter = Completer<bool?>();
    var permissionRequested = false;

    final api = NotificationApi(
      pluginInitializer: (_, __, ___) async => true,
      runtimePermissionRequester: (_) {
        permissionRequested = true;
        return permissionCompleter.future;
      },
    );

    await api.initialize(requestRuntimePermission: true);

    expect(permissionRequested, isTrue);
    expect(permissionCompleter.isCompleted, isFalse);

    permissionCompleter.complete(true);
    await Future<void>.delayed(Duration.zero);
  });

  test('initialize skips runtime permission when disabled', () async {
    var permissionRequests = 0;

    final api = NotificationApi(
      pluginInitializer: (_, __, ___) async => true,
      runtimePermissionRequester: (_) async {
        permissionRequests++;
        return true;
      },
    );

    await api.initialize(requestRuntimePermission: false);

    expect(permissionRequests, 0);
  });

  test('initialize swallows runtime permission request failures', () async {
    final api = NotificationApi(
      pluginInitializer: (_, __, ___) async => true,
      runtimePermissionRequester: (_) async {
        throw PlatformException(code: 'permission-error', message: 'boom');
      },
    );

    await api.initialize(requestRuntimePermission: true);
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'class reminders use an exact alarm at the requested Berlin time',
    () async {
      tz_data.initializeTimeZones();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      MethodCall? recordedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            recordedCall = call;
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final scheduledTime = DateTime.now().add(const Duration(days: 1));

      await NotificationApi().scheduleExactNotification(
        id: -42,
        title: 'Recht starts in 30 minutes',
        body: 'The class begins at 08:30.',
        scheduledTime: scheduledTime,
        payload: '{"title":"Recht"}',
      );

      expect(recordedCall?.method, 'zonedSchedule');
      final arguments = recordedCall?.arguments as Map<Object?, Object?>;
      final expected = tz.TZDateTime.from(
        scheduledTime,
        tz.getLocation('Europe/Berlin'),
      );
      expect(arguments['id'], -42);
      expect(arguments['title'], 'Recht starts in 30 minutes');
      expect(arguments['scheduledDateTimeISO8601'], expected.toIso8601String());
      expect(arguments['timeZoneName'], 'Europe/Berlin');
      final platform = arguments['platformSpecifics'] as Map<Object?, Object?>;
      expect(platform['channelId'], 'class_reminders');
      expect(platform['scheduleMode'], 'exactAllowWhileIdle');
    },
  );
}
