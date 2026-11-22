import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/services/launch_requests.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('trackit/launch');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('maps the native requests', () {
    expect(
      LaunchRequest.fromMap({'action': 'add_expense'}),
      isA<AddExpenseRequest>(),
    );
    expect(
      LaunchRequest.fromMap({'action': 'workout'}),
      isA<OpenWorkoutRequest>(),
    );
    final shared = LaunchRequest.fromMap({
      'action': 'shared_text',
      'text': 'Rs.10 debited',
    });
    expect((shared! as SharedTextRequest).text, 'Rs.10 debited');
    expect(LaunchRequest.fromMap({'action': 'shared_text'}), isNull);
    expect(LaunchRequest.fromMap({'action': 'other'}), isNull);
    expect(LaunchRequest.fromMap(null), isNull);
  });

  test('takes the request that started the app', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'takeLaunchRequest');
      return {'action': 'add_expense'};
    });
    expect(await LaunchRequests.takeInitial(), isA<AddExpenseRequest>());
  });

  test('no native side means no request', () async {
    expect(await LaunchRequests.takeInitial(), isNull);
  });

  test('requests while running arrive on the stream', () async {
    final next = LaunchRequests.stream.first;
    await messenger.handlePlatformMessage(
      'trackit/launch',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onRequest', {
          'action': 'shared_text',
          'text': 'INR 99 spent at Cafe',
        }),
      ),
      (_) {},
    );
    final r = await next;
    expect((r as SharedTextRequest).text, 'INR 99 spent at Cafe');
  });
}
