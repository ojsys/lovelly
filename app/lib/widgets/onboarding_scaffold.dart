import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Layout shared by onboarding screens 14–17: back button + 4-step bar, content, and a
/// footer pinned to the bottom (it scrolls with the content on short screens).
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.content,
    this.footer = const [],
    this.onBack,
    this.gap = KSpacing.xl,
  });

  /// 1–4, or 0 to hide the bar.
  final int step;
  final List<Widget> content;
  final List<Widget> footer;

  /// Null hides the back button.
  final VoidCallback? onBack;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewPaddingOf(context);
    const base = KSpacing.onboardingScreen;
    final padding = EdgeInsets.fromLTRB(
      base.left,
      math.max(base.top, insets.top + KSpacing.sm),
      base.right,
      math.max(base.bottom, insets.bottom + KSpacing.lg),
    );
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight - padding.vertical),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        if (onBack != null) ...[
                          KBackButton(onPressed: onBack!),
                          const SizedBox(width: KSpacing.lg),
                        ],
                        if (step > 0) Expanded(child: StepBar(step: step)),
                      ],
                    ),
                  ),
                  for (final child in content) ...[SizedBox(height: gap), child],
                  const Spacer(),
                  if (footer.isNotEmpty) SizedBox(height: gap),
                  ...footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class KBackButton extends StatelessWidget {
  const KBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: Material(
        color: KColors.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: const SizedBox.square(
            dimension: 44,
            child: Icon(Icons.arrow_back_rounded, size: 20, color: KColors.text),
          ),
        ),
      ),
    );
  }
}

/// "Step n of 4" progress bar.
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.step, this.of = 4});

  final int step;
  final int of;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $step of $of',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 1; i <= of; i++) ...[
            if (i > 1) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: i <= step ? KColors.coral : KColors.surface2,
                  borderRadius: BorderRadius.circular(KRadius.xs),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Title + optional lead paragraph (onboarding headers).
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({super.key, required this.title, this.lead, this.small = false});

  final String title;
  final Widget? lead;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: small ? KType.titleSmall : KType.title),
        if (lead != null) ...[
          SizedBox(height: small ? KSpacing.sm : 10),
          DefaultTextStyle.merge(
            style: KType.lead.copyWith(color: KColors.muted),
            child: lead!,
          ),
        ],
      ],
    );
  }
}

/// Uppercase field label ("6-DIGIT CODE").
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: KType.label.copyWith(color: KColors.muted));
}

/// Small centred note under the primary button.
class FootNote extends StatelessWidget {
  const FootNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: KType.small.copyWith(color: KColors.muted),
  );
}

/// Primary button that shows a spinner while [busy].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: KColors.disabledText),
            )
          : Text(label),
    );
  }
}
