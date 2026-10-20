import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:korram/api/api.dart';
import 'package:korram/auth/onboarding_repository.dart';
import 'package:korram/auth/token_store.dart';
import 'package:korram/features/call/call_engine.dart';
import 'package:korram/platform/permissions.dart';
import 'package:korram/platform/selfie_camera.dart';
import 'package:korram/platform/social_sign_in.dart';
import 'package:korram/realtime/realtime_client.dart';

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

/// An unsigned JWT whose payload carries `user_id` (the app reads its own id from it).
String fakeJwt(String userId) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'user_id': userId})}.sig';
}

/// Records what the app sends and lets tests push server events.
class FakeRealtimeClient extends RealtimeClient {
  FakeRealtimeClient() : super(store: FakeTokenStore(), refreshToken: () async {});

  final sent = <RealtimeEvent>[];
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  Future<void> start() async {}

  @override
  void send(RealtimeEvent event) => sent.add(event);

  void emit(RealtimeEvent event) => _events.add(event);

  void reconnected() => _connection.add(true);

  List<String> get types => [for (final e in sent) e['type'] as String];
}

Map<String, dynamic> matchFound({
  String mode = 'text',
  String session = 's1',
  String name = 'Kwame',
  List<String> shared = const ['Football', 'Tech'],
}) => {
  'type': 'match.found',
  'session_id': session,
  'mode': mode,
  'peer': {
    'first_name': name,
    'age': 27,
    'city': 'Accra',
    'shared_interests': shared,
    'shared_languages': ['english', 'pidgin'],
    'verified': true,
  },
  'room_name': 'room',
  'media_token': mode == 'text' ? null : 'tok',
  'media_url': mode == 'text' ? null : 'ws://lk.test',
};

Map<String, dynamic> chatMessage(
  String id,
  String body, {
  String sender = 'peer',
  String session = 's1',
  bool flagged = false,
  String reason = '',
}) => {
  'type': 'chat.message',
  'session_id': session,
  'message': {
    'id': id,
    'sender_id': sender,
    'body': body,
    'kind': 'text',
    'sent_at': DateTime(2026, 10, 20, 14, 14).toUtc().toIso8601String(),
    'seen_at': null,
    'flagged': flagged,
    'flag_reason': reason,
  },
};

/// Stands in for LiveKit: records what the app asks for; tests drive remote state.
class FakeCallEngine extends CallEngine {
  final joins = <({String url, String token, bool camera})>[];
  int leaves = 0;

  @override
  Future<void> join({required String url, required String token, required bool camera}) async {
    joins.add((url: url, token: token, camera: camera));
    cameraOn = camera;
    speakerOn = camera;
    link = CallLink.connected;
    notifyListeners();
  }

  @override
  Future<void> leave() async {
    leaves++;
    link = CallLink.idle;
    notifyListeners();
  }

  @override
  Future<void> setMic(bool on) async {
    micOn = on;
    notifyListeners();
  }

  @override
  Future<void> setCamera(bool on) async {
    cameraOn = on;
    notifyListeners();
  }

  @override
  Future<void> setSpeaker(bool on) async {
    speakerOn = on;
    notifyListeners();
  }

  @override
  Widget remoteVideo() => const SizedBox.expand(key: Key('remote-video'));

  @override
  Widget localVideo() => const SizedBox.expand(key: Key('local-video'));

  void remote({bool? video, double? level}) {
    if (video != null) remoteVideoOn = video;
    if (level != null) remoteAudioLevel = level;
    notifyListeners();
  }

  void setLink(CallLink value) {
    link = value;
    notifyListeners();
  }

  /// LiveKit gave up reconnecting.
  void lose() {
    setLink(CallLink.lost);
    onLost?.call();
  }
}
