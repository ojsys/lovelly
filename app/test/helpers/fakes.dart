import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:korram/api/api.dart';
import 'package:korram/auth/onboarding_repository.dart';
import 'package:korram/auth/token_store.dart';
import 'package:korram/features/call/call_engine.dart';
import 'package:korram/features/friends/friends_repository.dart';
import 'package:korram/features/wallet/wallet_repository.dart';
import 'package:korram/platform/invite_source.dart';
import 'package:korram/platform/push.dart';
import 'package:korram/platform/store_billing.dart';
import 'package:korram/platform/device_id.dart';
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

  AccountStatus accountStatus = const AccountStatus(
    status: StatusEnum.active,
    suspendedUntil: null,
    notices: [],
  );
  ApiFailure? reportError;

  @override
  Future<AccountStatus> status() async {
    calls.add('status');
    return accountStatus;
  }

  @override
  Future<void> noticeSeen(String id) async => calls.add('noticeSeen $id');

  @override
  Future<void> report(
    String? sessionId,
    ReasonEnum reason, {
    required bool block,
    String? chatId,
  }) async {
    calls.add('report ${sessionId ?? 'chat:$chatId'} ${reason.json} block=$block');
    if (reportError case final e?) throw e;
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

class FakeDeviceIdSource implements DeviceIdSource {
  @override
  Future<String?> deviceId() async => 'test-device-0001';
}

FriendSummary friendSummary(String name, {String city = 'Accra'}) =>
    FriendSummary(firstName: name, age: 27, city: city, verified: true, photoUrl: null);

FriendRow friendRow(
  String chatId,
  String name, {
  bool online = false,
  int unread = 0,
  String? last,
}) => FriendRow(
  chatId: chatId,
  friend: friendSummary(name),
  online: online,
  lastMessage: last == null
      ? null
      : LastMessage(body: last, kind: 'text', mine: false, sentAt: DateTime.now()),
  unread: unread,
);

class FakeFriendsRepository implements FriendsRepository {
  final calls = <String>[];
  Friends friendsData = const Friends(friends: [], requests: []);
  ChatHistory history_ = ChatHistory(
    friend: friendSummary('Kwame'),
    messages: const [],
    more: false,
  );
  MyProfile profileData = const MyProfile(
    firstName: 'Ada',
    age: 27,
    city: 'Enugu',
    bio: 'Builder by day.',
    interests: [Interest(slug: 'afrobeats', label: 'Afrobeats')],
    languages: ['english'],
    photos: [],
    isVerified: true,
  );
  ApiFailure? photoError;
  ApiFailure? requestError;

  @override
  Future<Friends> friends() async => friendsData;

  @override
  Future<void> request(String sessionId) async {
    calls.add('request $sessionId');
    if (requestError case final e?) throw e;
  }

  @override
  Future<void> accept(String requestId) async => calls.add('accept $requestId');

  @override
  Future<void> decline(String requestId) async => calls.add('decline $requestId');

  @override
  Future<ChatHistory> history(String chatId, {String? before}) async {
    calls.add('history $chatId${before == null ? '' : ' before'}');
    return history_;
  }

  @override
  Future<MyProfile> profile() async => profileData;

  @override
  Future<MyProfile> updateProfile(PatchedProfileUpdateRequest body) async {
    calls.add('update ${body.toJson()}');
    return profileData;
  }

  @override
  Future<MyProfile> addPhoto(String path) async {
    calls.add('addPhoto $path');
    if (photoError case final e?) throw e;
    return profileData;
  }

  @override
  Future<MyProfile> deletePhoto(String id) async {
    calls.add('deletePhoto $id');
    return profileData;
  }

  List<Interest>? catalogue;

  @override
  Future<List<Interest>> interests() async =>
      catalogue ??
      const [
        Interest(slug: 'afrobeats', label: 'Afrobeats'),
        Interest(slug: 'football', label: 'Football'),
        Interest(slug: 'tech', label: 'Tech'),
        Interest(slug: 'poetry', label: 'Poetry'),
        Interest(slug: 'food', label: 'Food'),
        Interest(slug: 'movies', label: 'Movies'),
      ];

  @override
  Future<void> registerDevice(String platform, String token) async =>
      calls.add('registerDevice $platform $token');
}

class FakePushService implements PushService {
  final opened_ = StreamController<Map<String, String>>.broadcast();
  bool started = false;

  @override
  Stream<Map<String, String>> get opened => opened_.stream;

  @override
  Future<void> start(Future<void> Function(String platform, String token) register) async {
    started = true;
    await register('android', 'fcm-test-token');
  }
}

const giftCatalogue = [
  Gift(slug: 'heart', name: 'Heart', cost: 5),
  Gift(slug: 'coffee', name: 'Coffee', cost: 10),
  Gift(slug: 'jollof', name: 'Jollof', cost: 20),
  Gift(slug: 'star', name: 'Star', cost: 30),
  Gift(slug: 'talking_drum', name: 'Talking drum', cost: 50),
  Gift(slug: 'vibes', name: 'Vibes', cost: 80),
  Gift(slug: 'crown', name: 'Crown', cost: 150),
  Gift(slug: 'diamond', name: 'Diamond', cost: 300),
];

const coinPacks = [
  Pack(productId: 'coins_100', coins: 100, bonus: 0, label: 'Starter', tag: ''),
  Pack(productId: 'coins_550', coins: 550, bonus: 50, label: '+50 bonus', tag: 'Popular'),
  Pack(productId: 'coins_1200', coins: 1200, bonus: 200, label: '+200 bonus', tag: ''),
  Pack(productId: 'coins_3000', coins: 3000, bonus: 700, label: '+700 bonus', tag: 'Best value'),
];

/// Server side of coins in tests: a balance the fakes keep consistent.
class FakeWalletRepository implements WalletRepository {
  final calls = <String>[];
  int balance = 240;
  int spentToday = 0;
  Checkin checkin = const Checkin(claimedToday: false, day: 3, coins: 10);
  List<LedgerEntry> entries = [];
  PurchaseStatusEnum purchaseStatus = PurchaseStatusEnum.credited;
  ApiFailure? giftError;
  ApiFailure? verifyError;

  Wallet get _wallet => Wallet(balance: balance, spentToday: spentToday, checkin: checkin);

  @override
  Future<Wallet> wallet() async => _wallet;

  @override
  Future<Ledger> ledger({String? before}) async {
    calls.add('ledger${before == null ? '' : ' before'}');
    return Ledger(entries: before == null ? entries : const [], more: false);
  }

  @override
  Future<Wallet> claimDaily() async {
    calls.add('claimDaily');
    if (!checkin.claimedToday) {
      balance += checkin.coins;
      checkin = Checkin(claimedToday: true, day: checkin.day, coins: checkin.coins);
    }
    return _wallet;
  }

  @override
  Future<List<Pack>> packs() async => coinPacks;

  @override
  Future<Invite> invite() async => const Invite(
    code: 'ADA23456',
    link: 'https://example.com/korram/i/ADA23456',
    coins: 50,
    rewarded: 0,
  );

  @override
  Future<void> redeemInvite(String code) async => calls.add('redeem $code');

  @override
  Future<List<Gift>> gifts() async => giftCatalogue;

  @override
  Future<GiftSent> sendGift(String gift, String key, {String? sessionId, String? chatId}) async {
    calls.add('gift $gift ${sessionId ?? 'chat:$chatId'}');
    if (giftError case final e?) throw e;
    final g = giftCatalogue.firstWhere((x) => x.slug == gift);
    balance -= g.cost;
    return GiftSent(id: 'g1', gift: g, balance: balance);
  }

  @override
  Future<PurchaseResult> verifyPurchase(String store, String productId, String token) async {
    calls.add('verify $store $productId $token');
    if (verifyError case final e?) throw e;
    if (purchaseStatus == PurchaseStatusEnum.credited) {
      balance += coinPacks.firstWhere((p) => p.productId == productId).coins;
    }
    return PurchaseResult(status: purchaseStatus, balance: balance);
  }
}

class FakeStoreBilling implements StoreBilling {
  final purchases_ = StreamController<StorePurchase>.broadcast();
  final finished = <String>[];
  final bought = <String>[];
  bool storeAvailable = true;

  @override
  Future<bool> available() async => storeAvailable;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => [
    for (final (id, price) in [
      ('coins_100', '₦1,500'),
      ('coins_550', '₦7,500'),
      ('coins_1200', '₦15,000'),
      ('coins_3000', '₦35,000'),
    ])
      if (ids.contains(id)) StoreProduct(id, price),
  ];

  @override
  Future<void> buy(String productId, {required String accountId}) async =>
      bought.add('$productId for $accountId');

  @override
  Stream<StorePurchase> get purchases => purchases_.stream;

  /// What the store reports after its purchase sheet.
  void complete(String productId, {StorePurchaseStatus status = StorePurchaseStatus.purchased}) =>
      purchases_.add(
        StorePurchase(
          productId: productId,
          store: 'google',
          token: 'tok-$productId',
          status: status,
        ),
      );

  @override
  Future<void> finish(StorePurchase purchase) async => finished.add(purchase.token);
}

class FakeInviteSource implements InviteSource {
  String? value;

  @override
  Future<String?> code() async => value;
}
