/// End-to-end: the app's real session controller, repository, generated client and
/// auth interceptor against the running dev API (`make up`). Codes are read from the
/// fake SMS provider's log lines.
///
///   flutter test --tags e2e
@Tags(['e2e'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korram/api/api.dart';
import 'package:korram/auth/onboarding_repository.dart';
import 'package:korram/auth/session.dart';
import 'package:korram/auth/token_store.dart';

import '../helpers/fakes.dart';
import 'support.dart';

void main() {
  late ProviderContainer container;
  late FakeTokenStore store;

  setUp(() {
    store = FakeTokenStore();
    container = ProviderContainer(overrides: [tokenStoreProvider.overrideWithValue(store)]);
  });
  tearDown(() => container.dispose());

  OnboardingRepository repo() => container.read(onboardingRepositoryProvider);
  Future<SessionState> session() => container.read(sessionProvider.future);

  Future<void> signIn(String phone) async {
    await session();
    final sent = await repo().requestCode(phone, ChannelEnum.sms);
    expect(sent.masked, startsWith('+234 803'));
    await container
        .read(sessionProvider.notifier)
        .signedIn(await repo().verifyCode(sent.phone, await codeFor(phone)));
  }

  test('FR-1..FR-4: new number to verified', () async {
    expect((await session()).step, OnboardingStep.signedOut);

    await signIn(newPhone());
    expect((await session()).step, OnboardingStep.basics);

    await repo().setBasics(firstName: 'Ada', dob: DateTime(1999, 3, 14), gender: GenderEnum.woman);
    await container.read(sessionProvider.notifier).refresh();
    expect((await session()).step, OnboardingStep.selfie);

    final pose = await jpeg();
    final result = await repo().submitSelfie(front: pose, left: pose);
    expect(result.selfie, SelfieEnum.passed);
    expect(result.isVerified, isTrue);

    await container.read(sessionProvider.notifier).refresh();
    expect((await session()).step, OnboardingStep.permissions);
    await container.read(sessionProvider.notifier).finishPermissions();
    expect((await session()).step, OnboardingStep.done);
  });

  test('expired access token is refreshed transparently', () async {
    await signIn(newPhone());
    await store.writeTokens(access: 'not-a-valid-token', refresh: store.tokens!.refresh);

    final state = await repo().verification();
    expect(state.nextStep, NextStepEnum.basics);
    expect(store.tokens!.access, isNot('not-a-valid-token'));
  });

  test('FR-3: under 18 removes the account and blocks the number', () async {
    final phone = newPhone();
    await signIn(phone);

    await expectLater(
      repo().setBasics(
        firstName: 'Kid',
        dob: DateTime(DateTime.now().year - 15),
        gender: GenderEnum.man,
      ),
      throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'underage')),
    );
    await store.clear();
    await expectLater(
      repo().requestCode(phone, ChannelEnum.sms),
      throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'phone_denied')),
    );
  });
}
