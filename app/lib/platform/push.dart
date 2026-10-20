import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Push notifications (FR-17). Firebase only runs when the app is built with
/// --dart-define=PUSH=fcm (and the Firebase config files are present).
abstract interface class PushService {
  /// Asks permission, gets this install's token and keeps it registered via [register].
  Future<void> start(Future<void> Function(String platform, String token) register);

  /// Data of notifications the user tapped (opened the app from).
  Stream<Map<String, String>> get opened;
}

class NoopPushService implements PushService {
  @override
  Future<void> start(Future<void> Function(String platform, String token) register) async {}

  @override
  Stream<Map<String, String>> get opened => const Stream.empty();
}

class FirebasePushService implements PushService {
  final _opened = StreamController<Map<String, String>>.broadcast();
  bool _started = false;

  @override
  Stream<Map<String, String>> get opened => _opened.stream;

  @override
  Future<void> start(Future<void> Function(String platform, String token) register) async {
    if (_started) return;
    _started = true;
    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final platform = Platform.isIOS ? 'ios' : 'android';
    // The backend sends to registration tokens (FCM v1 `message.token`). firebase_messaging
    // 17 deprecates these calls in favour of installation-ID registration; moving needs the
    // backend to switch too, so it's a follow-up rather than a silent change.
    // ignore: deprecated_member_use
    final token = await messaging.getToken();
    if (token != null) await register(platform, token);
    // ignore: deprecated_member_use
    messaging.onTokenRefresh.listen((t) => register(platform, t));
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _opened.add(_strings(m.data)));
    final initial = await messaging.getInitialMessage();
    if (initial != null) _opened.add(_strings(initial.data));
  }

  static Map<String, String> _strings(Map<String, dynamic> data) =>
      data.map((k, v) => MapEntry(k, '$v'));
}

final pushServiceProvider = Provider<PushService>(
  (ref) =>
      const String.fromEnvironment('PUSH') == 'fcm' ? FirebasePushService() : NoopPushService(),
);
