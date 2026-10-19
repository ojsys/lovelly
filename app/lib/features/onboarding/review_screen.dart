import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api.dart';
import '../../auth/session.dart';
import '../../config/app_config.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';

/// Selfie in manual review, or rejected (FR-4, SF-3). Not in the canvas.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final rejected = session.value?.verification?.selfie == SelfieEnum.rejected;
    final controller = ref.read(sessionProvider.notifier);
    return OnboardingScaffold(
      step: 3,
      content: [
        _StatusIcon(
          icon: rejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
          color: rejected ? KColors.danger : KColors.gold,
        ),
        OnboardingHeader(
          title: rejected ? 'We couldn’t verify you' : 'We’re checking\nyour selfie',
          lead: Text(
            rejected
                ? 'Our team couldn’t confirm your selfie. Contact support and we’ll help you '
                      'finish signing up.'
                : 'A person on our team is taking a look. You can start meeting people as soon '
                      'as it’s approved.',
          ),
        ),
      ],
      footer: [
        if (rejected)
          PrimaryButton(label: 'Contact support', onPressed: () => launchUrl(Links.support))
        else
          PrimaryButton(
            label: 'Check again',
            busy: session.isLoading,
            onPressed: controller.refresh,
          ),
        const SizedBox(height: KSpacing.md),
        TextButton(
          onPressed: controller.signOut,
          style: TextButton.styleFrom(
            foregroundColor: KColors.muted,
            minimumSize: const Size.fromHeight(44),
            textStyle: KType.button,
          ),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// FR-3: shown after an under-18 date of birth. The account is gone and the number blocked.
class RemovedScreen extends ConsumerWidget {
  const RemovedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingScaffold(
      step: 0,
      content: const [
        _StatusIcon(icon: Icons.block_rounded, color: KColors.danger),
        OnboardingHeader(
          title: 'Account removed',
          lead: Text(
            'Korram is only for people 18 and over, so we’ve removed this account and '
            'this phone number can’t be used to sign up.',
          ),
        ),
      ],
      footer: [
        TextButton(
          onPressed: () => launchUrl(Links.support),
          style: TextButton.styleFrom(
            foregroundColor: KColors.muted,
            minimumSize: const Size.fromHeight(44),
            textStyle: KType.button,
          ),
          child: const Text('Think this is a mistake? Contact support'),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: KColors.surface,
          borderRadius: BorderRadius.circular(KRadius.field),
        ),
        child: Icon(icon, size: 30, color: color),
      ),
    );
  }
}
