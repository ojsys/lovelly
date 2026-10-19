import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import 'onboarding_repository.dart';
import 'token_store.dart';

/// Where the user is in onboarding. The server decides up to `done` (`next_step`);
/// the permissions step (screen 17) is device-side and tracked locally.
enum OnboardingStep { signedOut, phone, basics, selfie, review, permissions, done, removed }

class SessionState {
  const SessionState(this.step, {this.verification});

  final OnboardingStep step;
  final VerificationState? verification;
}

const _permissionsDone = 'permissions_done';

class SessionController extends AsyncNotifier<SessionState> {
  TokenStore get _store => ref.read(tokenStoreProvider);
  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  @override
  Future<SessionState> build() async {
    ref.listen(signedOutSignalProvider, (_, _) => signOut());
    if (await _store.readTokens() == null) return const SessionState(OnboardingStep.signedOut);
    return _load();
  }

  Future<SessionState> _load() async {
    try {
      final verification = await _repo.verification();
      return SessionState(await _stepFor(verification), verification: verification);
    } on ApiFailure catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _store.clear();
        return const SessionState(OnboardingStep.signedOut);
      }
      rethrow;
    }
  }

  Future<OnboardingStep> _stepFor(VerificationState v) async => switch (v.nextStep) {
    NextStepEnum.phone => OnboardingStep.phone,
    NextStepEnum.basics => OnboardingStep.basics,
    NextStepEnum.selfie => OnboardingStep.selfie,
    NextStepEnum.review => OnboardingStep.review,
    NextStepEnum.done || NextStepEnum.$unknown =>
      await _store.readFlag(_permissionsDone) ? OnboardingStep.done : OnboardingStep.permissions,
  };

  /// Reloads the server state (after a step completes, or "Check again").
  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<void> signedIn(Session session) async {
    await _store.writeTokens(access: session.access, refresh: session.refresh);
    await refresh();
  }

  Future<void> finishPermissions() async {
    await _store.writeFlag(_permissionsDone, true);
    await refresh();
  }

  /// FR-3: the server removed the account (under 18).
  Future<void> removed() async {
    await _store.clear();
    state = const AsyncData(SessionState(OnboardingStep.removed));
  }

  Future<void> signOut() async {
    await _store.clear();
    state = const AsyncData(SessionState(OnboardingStep.signedOut));
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
