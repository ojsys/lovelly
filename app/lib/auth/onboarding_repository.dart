import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';

/// Onboarding calls (PRD: Auth and Onboarding endpoints). Errors surface as [ApiFailure].
class OnboardingRepository {
  OnboardingRepository(this._api);

  final KorramApi _api;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<OtpRequestResponse> requestCode(String phone, ChannelEnum channel) => _call(
    () => _api.auth.authOtpRequestCreate(
      body: OtpRequestRequest(phone: phone, channel: channel),
    ),
  );

  Future<Session> verifyCode(String phone, String code) => _call(
    () => _api.auth.authOtpVerifyCreate(
      body: OtpVerifyRequest(phone: phone, code: code),
    ),
  );

  Future<Session> socialSignIn(ProviderEnum provider, String idToken) => _call(
    () => _api.auth.authSocialCreate(
      body: SocialSignInRequest(provider: provider, idToken: idToken),
    ),
  );

  Future<VerificationState> verification() => _call(() => _api.me.meVerificationRetrieve());

  Future<VerificationState> setBasics({
    required String firstName,
    required DateTime dob,
    required GenderEnum gender,
  }) => _call(
    () => _api.me.meBasicsUpdate(
      body: BasicsRequest(firstName: firstName, dob: dob, gender: gender, adultConfirmed: true),
    ),
  );

  Future<VerificationState> submitSelfie({required String front, required String left}) =>
      _call(() => _api.me.meSelfieCreate(poseFront: File(front), poseLeft: File(left)));
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(apiProvider)),
);
