import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korram/app.dart';
import 'package:korram/auth/onboarding_repository.dart';
import 'package:korram/auth/token_store.dart';
import 'package:korram/platform/permissions.dart';
import 'package:korram/platform/selfie_camera.dart';
import 'package:korram/platform/social_sign_in.dart';

import 'fakes.dart';

class TestApp {
  final store = FakeTokenStore();
  final repo = FakeOnboardingRepository();
  final permissions = FakePermissionGateway();
  final camera = FakeSelfieCamera();
  late ProviderContainer container;

  /// Signs the fake device in, landing on the step [repo.state] says.
  void signedIn() => store.tokens = (access: 'a', refresh: 'r');
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
      ],
      child: const KorramApp(),
    ),
  );
  await tester.pumpAndSettle();
  app.container = ProviderScope.containerOf(tester.element(find.byType(KorramApp)));
  return app;
}
