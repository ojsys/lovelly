import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovelly/api/api.dart';
import 'package:lovelly/app.dart';
import 'package:lovelly/config/clock.dart';
import 'package:lovelly/auth/onboarding_repository.dart';
import 'package:lovelly/auth/token_store.dart';
import 'package:lovelly/features/call/call_controller.dart';
import 'package:lovelly/features/call/call_engine.dart';
import 'package:lovelly/features/friends/friends_repository.dart';
import 'package:lovelly/features/friends/profile_screen.dart';
import 'package:lovelly/features/home/home_data.dart';
import 'package:lovelly/features/plus/plus_repository.dart';
import 'package:lovelly/features/wallet/coin_store_screen.dart';
import 'package:lovelly/features/wallet/wallet_repository.dart';
import 'package:lovelly/platform/invite_source.dart';
import 'package:lovelly/platform/push.dart';
import 'package:lovelly/platform/store_billing.dart';
import 'package:lovelly/platform/device_id.dart';
import 'package:lovelly/platform/permissions.dart';
import 'package:lovelly/platform/selfie_camera.dart';
import 'package:lovelly/platform/social_sign_in.dart';
import 'package:lovelly/realtime/realtime_client.dart';

import 'fakes.dart';

class TestApp {
  final store = FakeTokenStore();
  final repo = FakeOnboardingRepository();
  final permissions = FakePermissionGateway();
  final camera = FakeSelfieCamera();
  final realtime = FakeRealtimeClient();
  final engine = FakeCallEngine();
  final freshTokens = <String>[];
  final friends = FakeFriendsRepository();
  final push = FakePushService();
  final wallet = FakeWalletRepository();
  final plus = FakePlusRepository();
  final billing = FakeStoreBilling();
  final invites = FakeInviteSource();
  final shared = <String>[];
  String? pickedPhoto = '/tmp/picked.jpg';
  int online = 12480;
  MyProfile profile = const MyProfile(
    firstName: 'Ada',
    age: 27,
    city: 'Enugu',
    state: '',
    bio: 'Builder by day, amateur chef by night.',
    photos: [],
    interests: [
      Interest(slug: 'afrobeats', label: 'Afrobeats'),
      Interest(slug: 'football', label: 'Football'),
      Interest(slug: 'tech', label: 'Tech'),
    ],
    languages: ['english'],
    isVerified: true,
  );
  late ProviderContainer container;

  /// Signs the fake device in (as user "me"), landing on the step [repo.state] says.
  void signedIn() => store.tokens = (access: fakeJwt('me'), refresh: 'r');

  /// Signed in, verified and past the permissions step: lands on Home.
  void verified() {
    signedIn();
    store.flags['permissions_done'] = true;
    repo.state = vstate(next: NextStepEnum.done, selfie: SelfieEnum.passed);
    permissions.grants
      ..[DevicePermission.camera] = GrantState.granted
      ..[DevicePermission.microphone] = GrantState.granted;
  }
}

/// Pumps the full app with fakes, by default at the canvas frame size (390 × 844).
Future<TestApp> pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  void Function(TestApp app)? setUp,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final app = TestApp();
  setUp?.call(app);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(app.store),
        onboardingRepositoryProvider.overrideWithValue(app.repo),
        permissionGatewayProvider.overrideWithValue(app.permissions),
        selfieCameraProvider.overrideWith((ref) => app.camera),
        socialSignInProvider.overrideWithValue(FakeSocialSignIn()),
        realtimeClientProvider.overrideWithValue(app.realtime),
        deviceIdSourceProvider.overrideWithValue(FakeDeviceIdSource()),
        friendsRepositoryProvider.overrideWithValue(app.friends),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 20, 14, 14)),
        pushServiceProvider.overrideWithValue(app.push),
        walletRepositoryProvider.overrideWithValue(app.wallet),
        plusRepositoryProvider.overrideWithValue(app.plus),
        storeBillingProvider.overrideWithValue(app.billing),
        inviteSourceProvider.overrideWithValue(app.invites),
        shareProvider.overrideWithValue((text) async => app.shared.add(text)),
        photoPickerProvider.overrideWithValue(() async => app.pickedPhoto),
        callEngineProvider.overrideWithValue(app.engine),
        mediaTokenFetcherProvider.overrideWithValue((id) async {
          app.freshTokens.add(id);
          return const MediaToken(mediaToken: 'fresh', mediaUrl: 'ws://lk.test');
        }),
        myProfileProvider.overrideWith((ref) async => app.profile),
        onlineCountProvider.overrideWith((ref) => Stream.value(app.online)),
      ],
      child: const LovellyApp(),
    ),
  );
  await tester.pumpAndSettle();
  app.container = ProviderScope.containerOf(tester.element(find.byType(LovellyApp)));
  return app;
}
