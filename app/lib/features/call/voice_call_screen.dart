import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../match/match_controller.dart';
import 'call_controller.dart';
import 'call_engine.dart';
import 'call_widgets.dart';
import 'icebreakers.dart';

/// 05 Voice call — design/screens/05-VoiceCall.dc.html (FR-13, FR-14).
class VoiceCallScreen extends ConsumerStatefulWidget {
  const VoiceCallScreen({super.key});

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen> with CallScreenLifecycle {
  @override
  Widget build(BuildContext context) {
    listenToCall(context);
    ref.listen(callControllerProvider, (prev, next) {
      if (next.video && !(prev?.video ?? false)) context.pushReplacement(Routes.videoCall);
    });
    final engine = ref.watch(callEngineProvider);
    final call = ref.watch(callControllerProvider);
    final peer = ref.watch(matchControllerProvider).peer;
    final controller = ref.read(callControllerProvider.notifier);
    final name = peer?.firstName ?? 'them';
    final insets = MediaQuery.viewPaddingOf(context);
    final likes = peer?.sharedInterests.isNotEmpty ?? false
        ? 'likes ${peer!.sharedInterests.map((i) => i.toLowerCase()).join(', ')}'
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.end();
      },
      child: Scaffold(
        body: ListenableBuilder(
          listenable: engine,
          builder: (context, _) => LayoutBuilder(
            builder: (context, viewport) {
              final padding = EdgeInsets.fromLTRB(
                20,
                math.max(52, insets.top + 8),
                20,
                math.max(36, insets.bottom + 12),
              );
              return SingleChildScrollView(
                padding: padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight - padding.vertical),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: KColors.surface,
                                borderRadius: BorderRadius.circular(KRadius.md),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: KColors.mint,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: KSpacing.sm),
                                  CallClock(
                                    since: call.startedAt,
                                    builder: (t) => Text(
                                      'Voice · $t',
                                      style: KType.body.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CallButton(
                              icon: KIcon.shield,
                              label: 'Report or block',
                              size: 44,
                              background: KColors.surface,
                              onPressed: () => openReport(call.sessionId),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        _Portrait(
                          initial: peer?.initial ?? '',
                          revealed: call.reveal == Reveal.revealed,
                        ),
                        const SizedBox(height: 16),
                        Text(peer?.title ?? '', style: KType.searchTitle),
                        const SizedBox(height: 4),
                        Text(
                          [if (peer?.city.isNotEmpty ?? false) peer!.city, ?likes].join(' · '),
                          textAlign: TextAlign.center,
                          style: KType.body.copyWith(color: KColors.muted),
                        ),
                        const SizedBox(height: 24),
                        _Waveform(level: engine.remoteAudioLevel),
                        const SizedBox(height: 8),
                        ReconnectingBanner(link: engine.link),
                        const SizedBox(height: 16),
                        _Icebreaker(
                          question: icebreakers[call.icebreaker],
                          onShuffle: controller.shuffleIcebreaker,
                        ),
                        const SizedBox(height: 24),
                        _RevealButton(state: call.reveal, name: name, onTap: controller.reveal),
                        const Spacer(),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CallButton(
                              icon: engine.micOn ? KIcon.mic : KIcon.micOff,
                              label: engine.micOn ? 'Mute microphone' : 'Unmute microphone',
                              size: 56,
                              pressed: !engine.micOn,
                              background: engine.micOn ? KColors.surface : KColors.text,
                              foreground: engine.micOn ? KColors.text : KColors.background,
                              onPressed: controller.toggleMic,
                            ),
                            CallButton(
                              icon: KIcon.speaker,
                              label: engine.speakerOn ? 'Speaker on' : 'Speaker off',
                              size: 56,
                              pressed: engine.speakerOn,
                              background: engine.speakerOn ? KColors.text : KColors.surface,
                              foreground: engine.speakerOn ? KColors.background : KColors.text,
                              onPressed: controller.toggleSpeaker,
                            ),
                            CallButton(
                              icon: KIcon.video,
                              label: call.upgrade == Upgrade.waiting
                                  ? 'Waiting for $name to accept video'
                                  : 'Switch to video',
                              size: 56,
                              background: call.upgrade == Upgrade.waiting
                                  ? KColors.lilacSoft
                                  : KColors.surface,
                              foreground: call.upgrade == Upgrade.waiting
                                  ? KColors.lilac
                                  : KColors.text,
                              onPressed: controller.requestVideo,
                            ),
                            CallButton(
                              icon: KIcon.arrowRight,
                              label: 'Next person',
                              size: 56,
                              background: KColors.lilac,
                              foreground: KColors.onCoral,
                              onPressed: controller.next,
                            ),
                            CallButton(
                              icon: KIcon.close,
                              label: 'End call',
                              size: 56,
                              background: KColors.danger,
                              foreground: KColors.white,
                              onPressed: controller.end,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The peer's photo, blurred until both agree to reveal (FR-13). Photos arrive in M5;
/// until then this is their initial.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.initial, required this.revealed});

  final String initial;
  final bool revealed;

  @override
  Widget build(BuildContext context) => Container(
    width: 180,
    height: 180,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: KColors.lilacSoft,
      shape: BoxShape.circle,
      border: Border.all(color: KColors.lilac, width: 2),
    ),
    child: ClipOval(
      child: Container(
        width: 140,
        height: 140,
        color: KColors.avatarIndigo,
        alignment: Alignment.center,
        child: Semantics(
          label: revealed ? 'Photo' : 'Photo hidden until you both reveal',
          excludeSemantics: true,
          child: ImageFiltered(
            enabled: !revealed,
            imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Text(initial, style: KType.hero.copyWith(color: KColors.avatarPlumText)),
          ),
        ),
      ),
    ),
  );
}

/// Bars that move with the other person's voice.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.level});

  final double level;

  // Resting shape from the design; live audio scales it.
  static const _heights = [
    10,
    18,
    28,
    40,
    22,
    48,
    34,
    16,
    26,
    44,
    56,
    38,
    20,
    30,
    46,
    24,
    14,
    32,
    20,
    12,
    8,
  ];

  @override
  Widget build(BuildContext context) {
    final gain = 0.25 + 0.75 * level.clamp(0, 1);
    return ExcludeSemantics(
      child: SizedBox(
        height: 56,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, h) in _heights.indexed) ...[
              if (i > 0) const SizedBox(width: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 6,
                height: math.max(6, h * gain),
                decoration: BoxDecoration(
                  color: KColors.lilac,
                  borderRadius: BorderRadius.circular(KRadius.xs),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Icebreaker extends StatelessWidget {
  const _Icebreaker({required this.question, required this.onShuffle});

  final String question;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(KSpacing.lg),
    decoration: BoxDecoration(
      color: KColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: KColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ICEBREAKER', style: KType.label.copyWith(color: KColors.muted)),
        const SizedBox(height: 10),
        Text(question, style: KType.icebreaker),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onShuffle,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: KColors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadius.md)),
            textStyle: KType.body.copyWith(fontWeight: FontWeight.w500),
          ),
          child: const Text('Shuffle question'),
        ),
      ],
    ),
  );
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.state, required this.name, required this.onTap});

  final Reveal state;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, waiting) = switch (state) {
      Reveal.none => ('Reveal photos (both must agree)', false),
      Reveal.waiting => ('Waiting for $name to reveal too…', true),
      Reveal.incoming => ('$name wants to reveal photos · Reveal', false),
      Reveal.revealed => ('Photos revealed', true),
    };
    return SizedBox(
      width: double.infinity,
      child: waiting
          ? CustomPaint(
              painter: _DashedRect(color: KColors.lilac),
              child: SizedBox(
                height: 52,
                child: Center(
                  child: Text(
                    label,
                    style: KType.button.copyWith(fontWeight: FontWeight.w700, color: KColors.lilac),
                  ),
                ),
              ),
            )
          : FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: KColors.text,
                foregroundColor: KColors.background,
                textStyle: KType.button.copyWith(fontWeight: FontWeight.w700),
              ),
              child: Text(label),
            ),
    );
  }
}

class _DashedRect extends CustomPainter {
  const _DashedRect({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          const Radius.circular(KRadius.xl),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 4, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRect old) => old.color != color;
}
