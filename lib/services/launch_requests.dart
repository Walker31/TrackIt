import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Why the app was opened from outside: a home-screen widget button, or
/// text shared to it (a bank SMS shared from Messages).
sealed class LaunchRequest {
  const LaunchRequest();

  static LaunchRequest? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    return switch (map['action']) {
      'add_expense' => const AddExpenseRequest(),
      'workout' => const OpenWorkoutRequest(),
      'shared_text' when map['text'] is String => SharedTextRequest(
        map['text']! as String,
      ),
      _ => null,
    };
  }
}

class AddExpenseRequest extends LaunchRequest {
  const AddExpenseRequest();
}

class OpenWorkoutRequest extends LaunchRequest {
  const OpenWorkoutRequest();
}

class SharedTextRequest extends LaunchRequest {
  final String text;
  const SharedTextRequest(this.text);
}

/// Listens on Android's `trackit/launch` channel (see MainActivity.kt).
/// Other platforms never send anything.
class LaunchRequests {
  static const _channel = MethodChannel('trackit/launch');
  static final _controller = StreamController<LaunchRequest>.broadcast();
  static bool _listening = false;

  /// Requests that arrive while the app is running.
  static Stream<LaunchRequest> get stream {
    if (!_listening) {
      _listening = true;
      if (_supported) {
        _channel.setMethodCallHandler((call) async {
          if (call.method != 'onRequest') return;
          final r = LaunchRequest.fromMap(
            (call.arguments as Map?)?.cast<Object?, Object?>(),
          );
          if (r != null) _controller.add(r);
        });
      }
    }
    return _controller.stream;
  }

  /// The request that started the app, once.
  static Future<LaunchRequest?> takeInitial() async {
    if (!_supported) return null;
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>(
        'takeLaunchRequest',
      );
      return LaunchRequest.fromMap(map);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('LaunchRequests: $e');
      return null;
    }
  }

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
