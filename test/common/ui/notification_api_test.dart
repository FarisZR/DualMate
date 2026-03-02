import 'dart:async';

import 'package:dualmate/common/ui/notification_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        throw PlatformException(
          code: 'permission-error',
          message: 'boom',
        );
      },
    );

    await api.initialize(requestRuntimePermission: true);
    await Future<void>.delayed(Duration.zero);
  });
}
