import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../api/api.dart';
import '../config/app_config.dart';

class SocialSignInCancelled implements Exception {}

/// Gets a Google / Apple ID token for `POST auth/social` (FR-2).
abstract interface class SocialSignIn {
  bool get enabled;
  Future<String> idToken(ProviderEnum provider);
}

class ConfiguredSocialSignIn implements SocialSignIn {
  bool _googleReady = false;

  @override
  bool get enabled => AppConfig.socialSignIn != 'off';

  @override
  Future<String> idToken(ProviderEnum provider) async {
    if (AppConfig.socialSignIn == 'fake') {
      // Matches the backend's FakeIdentityProvider; a new identity each time.
      return 'fake:${provider.json}-${Random().nextInt(1 << 32)}';
    }
    return switch (provider) {
      ProviderEnum.google => _google(),
      _ => _apple(),
    };
  }

  Future<String> _google() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(serverClientId: AppConfig.googleServerClientId);
      _googleReady = true;
    }
    try {
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw SocialSignInCancelled();
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw SocialSignInCancelled();
      rethrow;
    }
  }

  Future<String> _apple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(scopes: const []);
      final token = credential.identityToken;
      if (token == null) throw SocialSignInCancelled();
      return token;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw SocialSignInCancelled();
      rethrow;
    }
  }
}

final socialSignInProvider = Provider<SocialSignIn>((ref) => ConfiguredSocialSignIn());
