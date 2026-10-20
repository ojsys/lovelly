import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/session.dart';
import '../../config/app_config.dart';
import '../../router/routes.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../match/match_controller.dart';

/// Shown after the moderation system or a moderator ends a call (SF-2). Not in the canvas.
class SafetyEndedScreen extends ConsumerWidget {
  const SafetyEndedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(matchControllerProvider.notifier);
    final mode = ref.read(matchControllerProvider).mode;
    return OnboardingScaffold(
      step: 0,
      content: [
        const _Badge(icon: KIcon.shield, color: KColors.gold),
        OnboardingHeader(
          title: 'This ${mode == MatchMode.text ? 'chat' : 'call'} was ended\nfor safety',
          lead: const Text(
            'Our safety system stopped it because of content that breaks our Community '
            'Guidelines. Our team will review what happened.',
          ),
        ),
      ],
      footer: [
        PrimaryButton(
          label: 'Meet someone new',
          onPressed: () {
            controller.start(mode);
            context.pushReplacement(Routes.searching);
          },
        ),
        const SizedBox(height: KSpacing.md),
        TextButton(
          onPressed: () {
            controller.end();
            context.go(Routes.home);
          },
          style: TextButton.styleFrom(
            foregroundColor: KColors.text,
            minimumSize: const Size.fromHeight(44),
            textStyle: KType.button,
          ),
          child: const Text('Back to home'),
        ),
      ],
    );
  }
}

/// SF-6: a moderator (or the safety system, pending review) suspended this account.
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(sessionProvider).value?.status;
    final until = status?.suspendedUntil?.toLocal();
    final when = until == null
        ? null
        : '${MaterialLocalizations.of(context).formatMediumDate(until)}, '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(until))}';
    return OnboardingScaffold(
      step: 0,
      content: [
        const _Badge(icon: KIcon.shield, color: KColors.danger),
        OnboardingHeader(
          title: 'Account suspended',
          lead: Text(
            when == null
                ? 'Your account is paused while our team reviews it. You can’t match or chat '
                      'until then.'
                : 'You can’t match or chat until $when, after a report broke our Community '
                      'Guidelines.',
          ),
        ),
      ],
      footer: [
        PrimaryButton(
          label: 'Check again',
          onPressed: () => ref.read(sessionProvider.notifier).refresh(),
        ),
        const SizedBox(height: KSpacing.md),
        TextButton(
          onPressed: () => launchUrl(Links.guidelines),
          style: TextButton.styleFrom(
            foregroundColor: KColors.muted,
            minimumSize: const Size.fromHeight(44),
            textStyle: KType.button,
          ),
          child: const Text('Read the Community Guidelines'),
        ),
      ],
    );
  }
}

/// Shows unseen notices (moderator warnings) once, as a dialog (no design).
class NoticeListener extends ConsumerStatefulWidget {
  const NoticeListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NoticeListener> createState() => _NoticeListenerState();
}

class _NoticeListenerState extends ConsumerState<NoticeListener> {
  bool _showing = false;

  Future<void> _show() async {
    final notices = ref.read(sessionProvider).value?.status?.notices ?? const [];
    if (_showing || notices.isEmpty) return;
    _showing = true;
    final notice = notices.first;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: KColors.surface,
        title: Text(notice.title, style: KType.cardTitle),
        content: Text(notice.body, style: KType.lead.copyWith(color: KColors.muted)),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('I understand')),
        ],
      ),
    );
    await ref.read(sessionProvider.notifier).noticeSeen(notice.id);
    _showing = false;
    if (mounted) _show();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (_, _) => _show());
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
    return widget.child;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final KIcon icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(KRadius.field),
      ),
      child: Center(child: KIconView(icon, size: 30, color: color)),
    ),
  );
}
