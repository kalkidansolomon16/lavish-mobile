import 'package:flutter/foundation.dart';

/// Where the Lavish API lives. Override at build time:
///   flutter run --dart-define=API_URL=https://api.lavishmedicalspa.com/api/v1
/// Defaults: Android emulator → the PC's localhost (10.0.2.2); web/desktop → 127.0.0.1.
class AppConfig {
  static const _fromEnv = String.fromEnvironment('API_URL');

  static String get apiUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000/api/v1';
    return 'http://127.0.0.1:8000/api/v1';
  }

  static const appName = 'Lavish';

  /// Shown on the Welcome and Profile screens so testers can tell which build is installed.
  /// Keep in step with `version:` in pubspec.yaml.
  static const build = 5;
}
