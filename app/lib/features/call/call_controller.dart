import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../platform/permissions.dart';
import '../../realtime/realtime_client.dart';
import '../match/match_controller.dart';
import 'call_engine.dart';
import 'icebreakers.dart';

/// FR-13: both people must agree before photos are shown.
enum Reveal { none, waiting, incoming, revealed }

/// FR-14: voice → video needs the other person to accept.
enum Upgrade { none, waiting, incoming }

class CallState {
  const CallState({
    this.sessionId,
    this.startedAt,
    this.video = false,
    this.videoSince,
    this.reveal = Reveal.none,
    this.upgrade = Upgrade.none,
    this.icebreaker = 0,
    this.notice,
  });

  final String? sessionId;
  final DateTime? startedAt;

  /// Video call, or a voice call both agreed to switch to video.
  final bool video;

  /// When video started (match or upgrade): the remote video is blurred for 5 s (FR-11).
  final DateTime? videoSince;
  final Reveal reveal;
  final Upgrade upgrade;
  final int icebreaker;

  /// One-off message for a snackbar ("Tobi wants to stay on voice.").
  final String? notice;

  CallState copyWith({
    bool? video,
    DateTime? videoSince,
    Reveal? reveal,
    Upgrade? upgrade,
    int? icebreaker,
    String? notice,
    bool clearNotice = false,
  }) => CallState(
    sessionId: sessionId,
    startedAt: startedAt,
    video: video ?? this.video,
    videoSince: videoSince ?? this.videoSince,
    reveal: reveal ?? this.reveal,
    upgrade: upgrade ?? this.upgrade,
    icebreaker: icebreaker ?? this.icebreaker,
    notice: clearNotice ? null : notice ?? this.notice,
  );
}

/// Runs the call for the current match: joins LiveKit, rejoins after a drop, and handles
/// photo reveal and voice → video (FR-10..FR-14).
class CallController extends Notifier<CallState> {
  DateTime Function() now = DateTime.now;

  CallEngine get _engine => ref.read(callEngineProvider);
  RealtimeClient get _rt => ref.read(realtimeClientProvider);
  bool _rejoining = false;

  @override
  CallState build() {
    final sub = _rt.events.listen(_onEvent);
    ref.listen(matchControllerProvider, (prev, next) {
      final left = next.phase != MatchPhase.matched || next.sessionId != state.sessionId;
      if (state.sessionId != null && left) _hangUp();
    });
    ref.onDispose(sub.cancel);
    return const CallState();
  }

  /// Joins the media room for the current match (voice or video).
  Future<void> start() async {
    final match = ref.read(matchControllerProvider);
    final id = match.sessionId;
    if (id == null || match.mediaToken == null || match.mediaUrl == null) return;
    if (state.sessionId == id) return; // already in this call
    final video = match.mode == MatchMode.video;
    state = CallState(
      sessionId: id,
      startedAt: now(),
      video: video,
      videoSince: video ? now() : null,
      icebreaker: icebreakerFor(id),
    );
    _engine.onLost = _rejoin;
    await _engine.join(url: match.mediaUrl!, token: match.mediaToken!, camera: video);
  }

  /// LiveKit gave up reconnecting: get a fresh token and join again (NFR: within 10 s).
  Future<void> _rejoin() async {
    final id = state.sessionId;
    if (id == null || _rejoining) return;
    _rejoining = true;
    try {
      for (var attempt = 0; attempt < 5 && state.sessionId == id; attempt++) {
        try {
          final fresh = await ref.read(mediaTokenFetcherProvider)(id);
          await _engine.join(url: fresh.mediaUrl, token: fresh.mediaToken, camera: state.video);
          return;
        } catch (_) {
          await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    } finally {
      _rejoining = false;
    }
  }

  Future<void> _hangUp() async {
    state = const CallState();
    await _engine.leave();
  }

  // --- Controls (FR-14) ------------------------------------------------------------------

  Future<void> toggleMic() => _engine.setMic(!_engine.micOn);

  Future<void> toggleCamera() => _engine.setCamera(!_engine.cameraOn);

  Future<void> toggleSpeaker() => _engine.setSpeaker(!_engine.speakerOn);

  void shuffleIcebreaker() =>
      state = state.copyWith(icebreaker: (state.icebreaker + 1) % icebreakers.length);

  void next() => ref.read(matchControllerProvider.notifier).next();

  void end() => ref.read(matchControllerProvider.notifier).end();

  void clearNotice() => state = state.copyWith(clearNotice: true);

  // --- Photo reveal (FR-13) ------------------------------------------------------------

  void reveal() {
    final id = state.sessionId;
    if (id == null || state.reveal == Reveal.revealed || state.reveal == Reveal.waiting) return;
    final answering = state.reveal == Reveal.incoming;
    _rt.send({'type': answering ? 'reveal.accept' : 'reveal.request', 'session_id': id});
    if (!answering) state = state.copyWith(reveal: Reveal.waiting);
  }

  // --- Voice → video (FR-14) -----------------------------------------------------------

  void requestVideo() {
    final id = state.sessionId;
    if (id == null || state.video || state.upgrade != Upgrade.none) return;
    _rt.send({'type': 'upgrade.request', 'session_id': id});
    state = state.copyWith(upgrade: Upgrade.waiting);
  }

  /// Accepting needs the camera (FR-5); without it we decline.
  Future<void> answerVideo(bool accept) async {
    final id = state.sessionId;
    if (id == null || state.upgrade != Upgrade.incoming) return;
    if (accept) {
      final gateway = ref.read(permissionGatewayProvider);
      var camera = await gateway.status(DevicePermission.camera);
      if (camera != GrantState.granted) camera = await gateway.request(DevicePermission.camera);
      if (camera != GrantState.granted) {
        accept = false;
        state = state.copyWith(notice: 'Allow the camera in Settings to switch to video.');
      }
    }
    _rt.send({'type': accept ? 'upgrade.accept' : 'upgrade.decline', 'session_id': id});
    state = state.copyWith(upgrade: Upgrade.none);
  }

  Future<void> _onEvent(RealtimeEvent e) async {
    if (e['session_id'] != state.sessionId || state.sessionId == null) return;
    final peer = ref.read(matchControllerProvider).peer?.firstName ?? 'They';
    switch (e['type']) {
      case 'reveal.request':
        state = state.copyWith(reveal: Reveal.incoming);
      case 'reveal.accept':
        // Photo URLs arrive with profile photos (M5); until then the avatar unblurs.
        state = state.copyWith(reveal: Reveal.revealed);
      case 'upgrade.request':
        state = state.copyWith(upgrade: Upgrade.incoming);
      case 'upgrade.decline':
        state = state.copyWith(upgrade: Upgrade.none, notice: '$peer wants to stay on voice.');
      case 'upgrade.accept':
        state = state.copyWith(video: true, videoSince: now(), upgrade: Upgrade.none);
        await _engine.setCamera(true);
    }
  }
}

final callControllerProvider = NotifierProvider<CallController, CallState>(CallController.new);

/// `POST sessions/{id}/media-token`: a fresh join token after a drop.
final mediaTokenFetcherProvider = Provider<Future<MediaToken> Function(String sessionId)>(
  (ref) =>
      (id) => ref.read(apiProvider).sessions.sessionsMediaTokenCreate(sessionId: id),
);
