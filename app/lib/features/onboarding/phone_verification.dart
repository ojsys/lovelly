import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../auth/onboarding_repository.dart';

/// The number being verified and when each channel may send again (FR-1).
class PhoneVerificationState {
  const PhoneVerificationState({this.phone, this.masked, this.resendAt = const {}});

  final String? phone;
  final String? masked;
  final Map<ChannelEnum, DateTime> resendAt;
}

class PhoneVerification extends Notifier<PhoneVerificationState> {
  /// Overridable clock for tests.
  DateTime Function() now = DateTime.now;

  @override
  PhoneVerificationState build() => const PhoneVerificationState();

  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  /// Sends a code; throws [ApiFailure]. A rate-limit reply still updates the countdown.
  Future<void> send(String rawPhone, {ChannelEnum channel = ChannelEnum.sms}) async {
    try {
      final res = await _repo.requestCode(rawPhone, channel);
      state = PhoneVerificationState(
        phone: res.phone,
        masked: res.masked,
        resendAt: {
          ...(res.phone == state.phone ? state.resendAt : const {}),
          channel: now().add(Duration(seconds: res.resendIn)),
        },
      );
    } on ApiFailure catch (e) {
      if (e.code == 'otp_too_soon' && e.retryAfter != null) {
        state = PhoneVerificationState(
          phone: state.phone,
          masked: state.masked,
          resendAt: {
            ...state.resendAt,
            channel: now().add(Duration(seconds: e.retryAfter!)),
          },
        );
      }
      rethrow;
    }
  }

  Future<Session> verify(String code) => _repo.verifyCode(state.phone!, code);
}

final phoneVerificationProvider = NotifierProvider<PhoneVerification, PhoneVerificationState>(
  PhoneVerification.new,
);
