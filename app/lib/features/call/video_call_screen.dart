import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../friends/friends_controller.dart';
import '../match/match_controller.dart';
import '../wallet/gift_sheet.dart';
import 'call_controller.dart';
import 'call_engine.dart';
import 'call_widgets.dart';

/// 04 Video call — design/screens/04-VideoCall.dc.html (FR-10, FR-11, FR-12, FR-14).
class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({super.key});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> with CallScreenLifecycle {
  static const _languageCodes = {
    'english': 'EN',
    'pidgin': 'Pidgin',
    'yoruba': 'Yorùbá',
    'hausa': 'Hausa',
    'igbo': 'Igbo',
    'french': 'FR',
  };

  @override
  Widget build(BuildContext context) {
    listenToCall(context);
    final engine = ref.watch(callEngineProvider);
    final call = ref.watch(callControllerProvider);
    final match = ref.watch(matchControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);
    final peer = match.peer;
    final insets = MediaQuery.viewPaddingOf(context);
    final chips = [
      if (peer?.sharedInterests.isNotEmpty ?? false) 'Both like ${peer!.sharedInterests.first}',
      if (peer?.sharedLanguages.isNotEmpty ?? false)
        peer!.sharedLanguages.map((l) => _languageCodes[l] ?? l).join(' · '),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.end();
      },
      child: Scaffold(
        backgroundColor: KColors.cameraBackground,
        body: ListenableBuilder(
          listenable: engine,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              // Remote feed, blurred for its first 5 seconds (FR-11); hidden while the
              // report sheet is open (SF-4) or after a moderation hit (SF-2).
              SafetyCover(
                active: call.safetyBlur || call.paused,
                child: BlurForFirstSeconds(
                  since: call.videoSince,
                  child: engine.remoteVideoOn
                      ? engine.remoteVideo()
                      : Center(
                          child: Text(
                            engine.link == CallLink.connected
                                ? '${peer?.firstName ?? 'They'} turned their camera off'
                                : 'Connecting…',
                            style: KType.body.copyWith(color: KColors.cameraText),
                          ),
                        ),
                ),
              ),
              const Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: ColoredBox(color: KColors.scrimTop),
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: ColoredBox(color: KColors.scrimBottom),
                ),
              ),
              Positioned(
                top: math.max(52, insets.top + 8),
                left: 16,
                right: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: KColors.tileClay,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: KColors.text, width: 2),
                                ),
                                child: Text(
                                  peer?.initial ?? '',
                                  style: KType.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: KColors.tileClayText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            peer?.title ?? '',
                                            overflow: TextOverflow.ellipsis,
                                            style: KType.input.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (peer?.verified ?? false) ...[
                                          const SizedBox(width: 6),
                                          Semantics(
                                            label: 'Verified',
                                            child: const KIconView(
                                              KIcon.check,
                                              size: 16,
                                              color: KColors.mint,
                                              stroke: 2.4,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    CallClock(
                                      since: call.startedAt,
                                      builder: (t) => Text(
                                        [
                                          if (peer?.city.isNotEmpty ?? false) peer!.city,
                                          t,
                                        ].join(' · '),
                                        style: KType.caption.copyWith(color: KColors.textOnVideo),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (chips.isNotEmpty) ...[
                            const SizedBox(height: KSpacing.sm),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [for (final c in chips) _GlassChip(c)],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: KSpacing.md),
                    CallButton(
                      icon: KIcon.shield,
                      label: 'Report or block',
                      size: 44,
                      background: KColors.glassDark,
                      onPressed: () => openReport(call.sessionId),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: math.max(52, insets.top + 8) + 148,
                right: 16,
                child: Container(
                  width: 104,
                  height: 148,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: KColors.avatarPlum,
                    borderRadius: BorderRadius.circular(KRadius.field),
                    border: Border.all(color: KColors.text, width: 2),
                  ),
                  child: engine.cameraOn
                      ? engine.localVideo()
                      : Center(
                          child: Text(
                            'Camera off',
                            style: KType.small.copyWith(color: KColors.avatarPlumText),
                          ),
                        ),
                ),
              ),
              // 11: the gift moment, over the call.
              Positioned(
                top: 230,
                left: 16,
                right: 16,
                child: Center(
                  child: GiftMoment(
                    peerName: match.peer?.firstName ?? '',
                    sessionId: call.sessionId,
                  ),
                ),
              ),
              Positioned(
                top: math.max(52, insets.top + 8) + 310,
                left: 0,
                right: 0,
                child: Center(child: ReconnectingBanner(link: engine.link)),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: math.max(36, insets.bottom + 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CallButton(
                          icon: engine.micOn ? KIcon.mic : KIcon.micOff,
                          label: engine.micOn ? 'Mute microphone' : 'Unmute microphone',
                          pressed: !engine.micOn,
                          background: engine.micOn ? KColors.glass : KColors.text,
                          foreground: engine.micOn ? KColors.text : KColors.background,
                          onPressed: controller.toggleMic,
                        ),
                        CallButton(
                          icon: engine.cameraOn ? KIcon.video : KIcon.videoOff,
                          label: engine.cameraOn ? 'Turn camera off' : 'Turn camera on',
                          pressed: !engine.cameraOn,
                          background: engine.cameraOn ? KColors.glass : KColors.text,
                          foreground: engine.cameraOn ? KColors.text : KColors.background,
                          onPressed: controller.toggleCamera,
                        ),
                        if (call.sessionId != null)
                          CallButton(
                            icon: KIcon.giftBow,
                            label: 'Send a gift',
                            foreground: KColors.gold,
                            onPressed: () => showGiftSheet(context, sessionId: call.sessionId),
                          ),
                        if (match.chatId == null && call.sessionId != null)
                          _AddFriendButton(sessionId: call.sessionId!),
                        CallButton(
                          icon: KIcon.close,
                          label: 'End call',
                          background: KColors.danger,
                          foreground: KColors.white,
                          onPressed: controller.end,
                        ),
                      ],
                    ),
                    if (match.chatId == null) ...[
                      const SizedBox(height: 18),
                      Semantics(
                        button: true,
                        label: 'Next person',
                        excludeSemantics: true,
                        child: Material(
                          color: KColors.coral,
                          borderRadius: BorderRadius.circular(KRadius.field),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(KRadius.field),
                            onTap: controller.next,
                            child: SizedBox(
                              height: 60,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Next person',
                                    style: KType.buttonLarge.copyWith(color: KColors.onCoral),
                                  ),
                                  const SizedBox(width: 10),
                                  const KIconView(
                                    KIcon.arrowRight,
                                    size: 20,
                                    color: KColors.onCoral,
                                    stroke: 2.4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: KColors.glass, borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: KType.small.copyWith(height: 1.2, fontWeight: FontWeight.w500)),
  );
}

/// FR-14: ask to be friends from the call; turns mint once sent.
class _AddFriendButton extends ConsumerWidget {
  const _AddFriendButton({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sent = ref.watch(friendRequestsSentProvider).contains(sessionId);
    return CallButton(
      icon: KIcon.addFriend,
      label: sent ? 'Friend request sent' : 'Add as friend',
      pressed: sent,
      background: sent ? KColors.mint : KColors.glass,
      foreground: sent ? KColors.background : KColors.text,
      onPressed: sent
          ? null
          : () async {
              final error = await ref.read(friendRequestsSentProvider.notifier).add(sessionId);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              }
            },
    );
  }
}
