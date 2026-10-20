import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import 'onboarding_repository.dart';
import 'token_store.dart';

/// Where the user is in onboarding. The server decides up to `done` (`next_step`);
/// the permissions step (screen 17) is device-side and tracked locally.
enum OnboardingStep {
  signedOut,
  phone,
  basics,
  selfie,
  review,
  permissions,
  done,
  removed,

  /// SF-6: a moderator suspended the account (or SF-3 pending review after verification).
  suspended,
}

class SessionState {
  const SessionState(this.step, {this.verification, this.status});

  final OnboardingStep step;
  final VerificationState? verification;

  /// Account status and unseen notices (warnings), for verified users.
  final AccountStatus? status;
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
      final step = await _stepFor(verification);
      if (step == OnboardingStep.done || step == OnboardingStep.permissions) {
        final status = await _repo.status();
        final suspended = status.status == StatusEnum.suspended;
        return SessionState(
          suspended ? OnboardingStep.suspended : step,
          verification: verification,
          status: status,
        );
      }
      return SessionState(step, verification: verification);
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

  /// Marks a notice (e.g. a warning) as seen so it shows only once.
  Future<void> noticeSeen(String id) async {
    await _repo.noticeSeen(id);
    final current = state.value;
    if (current?.status == null) return;
    final s = current!.status!;
    state = AsyncData(
      SessionState(
        current.step,
        verification: current.verification,
        status: AccountStatus(
          status: s.status,
          suspendedUntil: s.suspendedUntil,
          notices: [...s.notices.where((n) => n.id != id)],
        ),
      ),
    );
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
