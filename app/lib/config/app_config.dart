import 'dart:io';

/// Build-time configuration, set with --dart-define.
abstract final class AppConfig {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// The dev API from `make up`. The Android emulator reaches the host at 10.0.2.2.
  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    return Platform.isAndroid ? 'http://10.0.2.2:8100' : 'http://127.0.0.1:8100';
  }

  /// Google / Apple sign-in: `fake` (dev, uses the backend's fake identity provider),
  /// `real` (needs OAuth client setup) or `off`.
  static const socialSignIn = String.fromEnvironment('SOCIAL_SIGN_IN', defaultValue: 'fake');

  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
}

/// Placeholder links until the real pages exist (docs/questions.md).
abstract final class Links {
  static final terms = Uri.parse('https://example.com/lovelly/terms');
  static final guidelines = Uri.parse('https://example.com/lovelly/community-guidelines');
  static final support = Uri.parse('https://example.com/lovelly/support');
}
