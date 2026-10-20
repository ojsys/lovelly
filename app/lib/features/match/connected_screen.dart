import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';
import 'match_controller.dart';

/// Interim voice / video match screen until the call screens (04, 05) arrive in M3.
/// Lets Next and End (FR-12) work end to end now.
class ConnectedScreen extends ConsumerWidget {
  const ConnectedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(matchControllerProvider, (prev, next) {
      if (next.phase == MatchPhase.searching && prev?.phase == MatchPhase.matched) {
        context.pushReplacement(Routes.searching); // peer pressed Next, or we did
      } else if (next.phase == MatchPhase.idle) {
        context.go(Routes.home);
      }
    });
    final state = ref.watch(matchControllerProvider);
    final controller = ref.read(matchControllerProvider.notifier);
    final peer = state.peer;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.end();
      },
      child: OnboardingScaffold(
        step: 0,
        content: [
          Text(state.mode.tag.toUpperCase(), style: KType.label.copyWith(color: KColors.muted)),
          OnboardingHeader(
            title: 'Connected to\n${peer?.title ?? ''}',
            lead: Text(
              [
                if (peer?.city.isNotEmpty ?? false) peer!.city,
                if (peer?.sharedInterests.isNotEmpty ?? false)
                  'Both like ${peer!.sharedInterests.join(', ')}',
                'Calls arrive in the next update.',
              ].join(' · '),
            ),
          ),
        ],
        footer: [
          PrimaryButton(label: 'Next person', onPressed: controller.next),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: controller.end, child: const Text('End')),
        ],
      ),
    );
  }
}
