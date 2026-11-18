import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../features/common/account.dart' show routeForTarget;
import 'api.dart';
import 'inbox_alerts.dart';
import 'session.dart';

/// Firebase push notifications — notifications arrive even when the app is closed.
///
/// Turned on by building with the Firebase project's values (Firebase console → Project settings → General,
/// under "Your apps"):
///   --dart-define=FIREBASE_PROJECT_ID=lavish-…  --dart-define=FIREBASE_SENDER_ID=1234567890
///   --dart-define=FIREBASE_API_KEY=AIza…        --dart-define=FIREBASE_ANDROID_APP_ID=1:123:android:abc
///   --dart-define=FIREBASE_IOS_APP_ID=1:123:ios:def   (iPhone builds; also needs the APNs key in Firebase)
/// and on the server PUSH_DRIVER=fcm + FIREBASE_CREDENTIALS (see lavish_backend .env).
/// Without these the app still shows notifications while it is open (inbox_alerts.dart).
class PushService {
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

  static bool _ready = false;
  static String? token;
  static StreamSubscription<String>? _refresh;

  /// Called when a push notification is tapped: the app route to open.
  static void Function(String route)? onOpen;

  static String get _appId => defaultTargetPlatform == TargetPlatform.iOS ? _iosAppId : _androidAppId;
  static bool get configured => !kIsWeb && _projectId.isNotEmpty && _apiKey.isNotEmpty && _senderId.isNotEmpty && _appId.isNotEmpty;

  static Future<void> init() async {
    if (!configured || _ready) return;
    try {
      await Firebase.initializeApp(options: FirebaseOptions(apiKey: _apiKey, appId: _appId, messagingSenderId: _senderId, projectId: _projectId));
      // App open: Firebase doesn't show the notification itself, so we do (once).
      FirebaseMessaging.onMessage.listen((m) => InboxAlerts.show(m.data['nid']?.toString() ?? '', m.notification?.title ?? 'Lavish', m.notification?.body ?? '', _target(m.data)));
      FirebaseMessaging.onMessageOpenedApp.listen(_opened);
      _ready = true;
    } catch (e) {
      debugPrint('Firebase not started: $e');
    }
  }

  /// After sign-in: ask permission, send this phone's token to the server, keep it up to date.
  static Future<void> register() async {
    if (!_ready) return;
    try {
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      final initial = await m.getInitialMessage(); // the app was opened by tapping a notification
      if (initial != null) _opened(initial);
      // The classic FCM registration token: what the server's HTTP v1 sender (FcmPushSender) targets.
      // ignore: deprecated_member_use
      token = await m.getToken();
      session.deviceToken = token;
      if (token != null) await _send(token!);
      _refresh?.cancel();
      // ignore: deprecated_member_use
      _refresh = m.onTokenRefresh.listen((t) {
        token = t;
        session.deviceToken = t;
        _send(t);
      });
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  /// Signing out: stop sending to this phone.
  static Future<void> unregister() async {
    _refresh?.cancel();
    if (!_ready) return;
    try {
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    token = null;
  }

  static Future<void> _send(String t) =>
      api.post('/auth/devices', {'token': t, 'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'}).catchError((_) => null);

  static Map? _target(Map<String, dynamic> data) => data['screen'] == null ? null : {'screen': data['screen'], 'id': data['id']};

  static void _opened(RemoteMessage m) => onOpen?.call(routeForTarget(_target(m.data)) ?? '/notifications');
}
