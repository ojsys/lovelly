import 'package:flutter/widgets.dart';
import 'package:korram/api/api.dart';
import 'package:korram/auth/onboarding_repository.dart';
import 'package:korram/auth/token_store.dart';
import 'package:korram/platform/permissions.dart';
import 'package:korram/platform/selfie_camera.dart';
import 'package:korram/platform/social_sign_in.dart';

class FakeTokenStore implements TokenStore {
  ({String access, String refresh})? tokens;
  final flags = <String, bool>{};

  @override
  Future<({String access, String refresh})?> readTokens() async => tokens;

  @override
  Future<void> writeTokens({required String access, required String refresh}) async =>
      tokens = (access: access, refresh: refresh);

  @override
  Future<bool> readFlag(String name) async => flags[name] ?? false;

  @override
  Future<void> writeFlag(String name, bool value) async => flags[name] = value;

  @override
  Future<void> clear() async {
    tokens = null;
    flags.clear();
  }
}

VerificationState vstate({
  NextStepEnum next = NextStepEnum.basics,
  SelfieEnum selfie = SelfieEnum.none,
  int attemptsLeft = 3,
}) => VerificationState(
  phoneVerified: next != NextStepEnum.phone,
  basicsDone: next != NextStepEnum.phone && next != NextStepEnum.basics,
  selfie: selfie,
  attemptsLeft: attemptsLeft,
  isVerified: next == NextStepEnum.done,
  nextStep: next,
);

const session = Session(access: 'a', refresh: 'r', nextStep: NextStepEnum.basics);

/// Scriptable stand-in for the backend. Each call is recorded in [calls].
class FakeOnboardingRepository implements OnboardingRepository {
  final calls = <String>[];
  VerificationState state = vstate();
  ApiFailure? requestCodeError;
  ApiFailure? verifyCodeError;
  ApiFailure? basicsError;
  final selfieResults = <VerificationState>[];

  @override
  Future<OtpRequestResponse> requestCode(String phone, ChannelEnum channel) async {
    calls.add('requestCode $phone ${channel.json}');
    if (requestCodeError case final e?) throw e;
    return const OtpRequestResponse(
      phone: '+2348031234542',
      masked: '+234 803 ••• ••42',
      resendIn: 60,
    );
  }

  @override
  Future<Session> verifyCode(String phone, String code) async {
    calls.add('verifyCode $phone $code');
    if (verifyCodeError case final e?) throw e;
    return session;
  }

  @override
  Future<Session> socialSignIn(ProviderEnum provider, String idToken) async {
    calls.add('socialSignIn ${provider.json}');
    state = vstate(next: NextStepEnum.phone);
    return const Session(access: 'a', refresh: 'r', nextStep: NextStepEnum.phone);
  }

  @override
  Future<VerificationState> verification() async {
    calls.add('verification');
    return state;
  }

  @override
  Future<VerificationState> setBasics({
    required String firstName,
    required DateTime dob,
    required GenderEnum gender,
  }) async {
    calls.add('setBasics $firstName ${dob.toIso8601String().substring(0, 10)} ${gender.json}');
    if (basicsError case final e?) throw e;
    return state = vstate(next: NextStepEnum.selfie);
  }

  @override
  Future<VerificationState> submitSelfie({required String front, required String left}) async {
    calls.add('submitSelfie $front $left');
    return state = selfieResults.removeAt(0);
  }
}

class FakePermissionGateway implements PermissionGateway {
  final grants = <DevicePermission, GrantState>{};
  GrantState Function(DevicePermission) onRequest = (_) => GrantState.granted;
  bool openedSettings = false;

  @override
  Future<GrantState> status(DevicePermission p) async => grants[p] ?? GrantState.notAsked;

  @override
  Future<GrantState> request(DevicePermission p) async => grants[p] = onRequest(p);

  @override
  Future<void> openSettings() async => openedSettings = true;
}

class FakeSelfieCamera implements SelfieCamera {
  var shots = 0;
  var open_ = false;

  @override
  Future<void> open() async => open_ = true;

  @override
  Widget preview() => const SizedBox.expand(key: Key('camera-preview'));

  @override
  Future<String> capture() async => '/tmp/pose${++shots}.jpg';

  @override
  Future<void> close() async => open_ = false;
}

class FakeSocialSignIn implements SocialSignIn {
  @override
  bool get enabled => true;

  @override
  Future<String> idToken(ProviderEnum provider) async => 'fake:${provider.json}';
}
