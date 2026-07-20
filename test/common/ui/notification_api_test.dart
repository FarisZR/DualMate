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

  test('class reminder channel state is checked independently', () async {
    final api = NotificationApi(
      classReminderChannelChecker: (_) async => false,
    );

    expect(await api.areClassRemindersEnabled(), isFalse);
  });

  test('default checker detects a disabled Android reminder channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'getNotificationChannels') return null;
          return [
            <String, Object?>{
              'id': NotificationApi.classReminderChannelId,
              'name': 'Class reminders',
              'description': '',
              'groupId': null,
              'showBadge': true,
              'importance': Importance.none.value,
              'playSound': false,
              'sound': null,
              'enableVibration': true,
              'vibrationPattern': null,
              'enableLights': false,
              'ledColor': 0,
              'audioAttributesUsage': AudioAttributesUsage.notification.value,
            },
          ];
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    expect(await NotificationApi().areClassRemindersEnabled(), isFalse);
  });

  test('default checker allows a reminder channel not created yet', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getNotificationChannels') return <Object?>[];
          return null;
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    expect(await NotificationApi().areClassRemindersEnabled(), isTrue);
  });

  test('class reminder settings use the dedicated channel opener', () async {
    var opens = 0;
    final api = NotificationApi(
      classReminderSettingsOpener: () async {
        opens++;
        return true;
      },
    );

    expect(await api.openClassReminderSettings(), isTrue);
    expect(opens, 1);
  });

  test('pending class notification requests are exposed as IDs only', () async {
    final api = NotificationApi(
      pendingNotificationIdsLoader: (_) async => {-42, -7},
    );

    expect(await api.pendingNotificationIds(), {-42, -7});
  });

  test(
    'pending notification IDs use an empty safe default on platform failure',
    () async {
      final api = NotificationApi(
        pendingNotificationIdsLoader: (_) async {
          throw PlatformException(code: 'pending-failed');
        },
      );

      expect(await api.pendingNotificationIds(), isEmpty);
    },
  );

  test(
    'pending notification IDs use an empty safe default without a plugin',
    () async {
      final api = NotificationApi(
        pendingNotificationIdsLoader: (_) async {
          throw MissingPluginException('not registered');
        },
      );

      expect(await api.pendingNotificationIds(), isEmpty);
    },
  );

  test('class reminder battery settings use the dedicated opener', () async {
    var opens = 0;
    final api = NotificationApi(
      classReminderBatterySettingsOpener: () async {
        opens++;
        return true;
      },
    );

    expect(await api.openClassReminderBatterySettings(), isTrue);
    expect(opens, 1);
  });

  test('class reminder battery settings swallow platform failures', () async {
    final api = NotificationApi(
      classReminderBatterySettingsOpener: () async {
        throw PlatformException(code: 'settings-unavailable');
      },
    );

    expect(await api.openClassReminderBatterySettings(), isFalse);
  });

  test(
    'void notification API has no pending IDs or battery settings',
    () async {
      final api = VoidNotificationApi();

      expect(await api.pendingNotificationIds(), isEmpty);
      expect(await api.openClassReminderBatterySettings(), isFalse);
    },
  );

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
