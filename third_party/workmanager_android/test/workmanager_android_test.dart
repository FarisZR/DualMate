import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_android/workmanager_android.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkmanagerAndroid workmanager;
  late _PigeonMockHost host;

  setUp(() {
    workmanager = WorkmanagerAndroid();
    host = _PigeonMockHost();
    host.install();
  });

  tearDown(() {
    host.dispose();
  });

  test('unsupported Android-only operations throw', () {
    expect(
      () => workmanager.registerProcessingTask('task', 'name'),
      throwsA(isA<UnsupportedError>()),
    );

    expect(
      () => workmanager.printScheduledTasks(),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('registerOneOffTask sends expected request payload', () async {
    await workmanager.registerOneOffTask(
      'one-off-id',
      'syncNow',
      inputData: {
        'flag': true,
        'message': 'hello',
        'labels': ['a', 'b'],
      },
      initialDelay: const Duration(minutes: 2, seconds: 5),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 30),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      outOfQuotaPolicy: OutOfQuotaPolicy.dropWorkRequest,
      tag: 'sync-tag',
    );

    final request = host.firstRequest<OneOffTaskRequest>('registerOneOffTask');
    expect(request.uniqueName, 'one-off-id');
    expect(request.taskName, 'syncNow');
    expect(request.initialDelaySeconds, 125);
    expect(request.tag, 'sync-tag');
    expect(request.inputData?['flag'], true);
    expect(request.inputData?['message'], 'hello');
    expect(request.inputData?['labels'], ['a', 'b']);
    expect(request.existingWorkPolicy, ExistingWorkPolicy.replace);
    expect(request.outOfQuotaPolicy, OutOfQuotaPolicy.dropWorkRequest);
    expect(request.backoffPolicy?.backoffPolicy, BackoffPolicy.linear);
    expect(request.backoffPolicy?.backoffDelayMillis, 30000);
  });

  test('registerPeriodicTask converts durations and applies defaults',
      () async {
    await workmanager.registerPeriodicTask(
      'periodic-id',
      'syncEveryHour',
      inputData: {'type': 'periodic'},
      initialDelay: const Duration(seconds: 7),
      flexInterval: const Duration(minutes: 5),
    );

    final request =
        host.firstRequest<PeriodicTaskRequest>('registerPeriodicTask');
    expect(request.uniqueName, 'periodic-id');
    expect(request.taskName, 'syncEveryHour');
    expect(request.frequencySeconds, 900);
    expect(request.flexIntervalSeconds, 300);
    expect(request.initialDelaySeconds, 7);
    expect(request.inputData?['type'], 'periodic');
  });

  test('scheduling and cancellation APIs hit expected channels', () async {
    await workmanager.initialize(callbackDispatcher);
    await workmanager.registerOneOffTask('id-1', 'task-1');
    await workmanager.registerPeriodicTask(
      'id-2',
      'task-2',
      frequency: const Duration(minutes: 30),
    );
    await workmanager.cancelByUniqueName('id-1');
    await workmanager.cancelByTag('tag-1');
    await workmanager.cancelAll();

    final isScheduled = await workmanager.isScheduledByUniqueName('id-2');

    expect(isScheduled, isTrue);
    expect(host.messageFor('initialize'), isNotNull);
    expect(host.messageFor('registerOneOffTask'), isNotNull);
    expect(host.messageFor('registerPeriodicTask'), isNotNull);
    expect(host.messageFor('cancelByUniqueName'), isNotNull);
    expect(host.messageFor('cancelByTag'), isNotNull);
    expect(host.messageFor('cancelAll'), isNull);
    expect(host.messageFor('isScheduledByUniqueName'), isNotNull);
  });

  test('register methods reject unsupported inputData payload types', () {
    expect(
      () => workmanager.registerOneOffTask(
        'invalid-one-off',
        'task',
        inputData: {
          'badMap': {'nested': 'value'},
        },
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(
      () => workmanager.registerPeriodicTask(
        'invalid-periodic',
        'task',
        inputData: {
          'badList': [1, 2, 3],
        },
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('identifiers with supported special characters are forwarded', () async {
    const names = [
      'task-with-dash',
      'task_with_underscore',
      'task.with.dots',
    ];

    for (final name in names) {
      await workmanager.registerOneOffTask(name, name);
      final request =
          host.firstRequest<OneOffTaskRequest>('registerOneOffTask');
      expect(request.uniqueName, name);
      expect(request.taskName, name);
    }
  });

  test('extreme duration values are forwarded as expected seconds', () async {
    final cases = <Duration, int>{
      Duration.zero: 0,
      const Duration(seconds: 1): 1,
      const Duration(days: 365): 31536000,
    };

    for (final entry in cases.entries) {
      await workmanager.registerOneOffTask(
        'duration-${entry.value}',
        'duration-task',
        initialDelay: entry.key,
      );

      final request =
          host.firstRequest<OneOffTaskRequest>('registerOneOffTask');
      expect(request.initialDelaySeconds, entry.value);
    }
  });
}

class _PigeonMockHost {
  static const String _prefix =
      'dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerHostApi.';

  final _channels = <String, BasicMessageChannel<Object?>>{};
  final _messages = <String, Object?>{};

  void install() {
    _register('initialize', (_) async => <Object?>[]);
    _register('registerOneOffTask', (_) async => <Object?>[]);
    _register('registerPeriodicTask', (_) async => <Object?>[]);
    _register('cancelByUniqueName', (_) async => <Object?>[]);
    _register('cancelByTag', (_) async => <Object?>[]);
    _register('cancelAll', (_) async => <Object?>[]);
    _register('isScheduledByUniqueName', (_) async => <Object?>[true]);
  }

  Object? messageFor(String method) {
    return _messages[method];
  }

  T firstRequest<T>(String method) {
    final Object? message = _messages[method];
    final args = message as List<Object?>;
    return args.first as T;
  }

  void dispose() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in _channels.values) {
      messenger.setMockDecodedMessageHandler<Object?>(channel, null);
    }
    _channels.clear();
    _messages.clear();
  }

  void _register(
    String method,
    Future<Object?> Function(Object? message) handler,
  ) {
    final channelName = '$_prefix$method';
    final channel = BasicMessageChannel<Object?>(
      channelName,
      WorkmanagerHostApi.pigeonChannelCodec,
    );
    _channels[method] = channel;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(channel, (message) async {
      _messages[method] = message;
      return handler(message);
    });
  }
}
