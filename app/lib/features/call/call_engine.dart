import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

enum CallLink { idle, connecting, connected, reconnecting, lost }

/// The media side of a call (LiveKit), behind an interface so widgets can be tested
/// without WebRTC. Media never goes over our websocket (PRD: Realtime).
abstract class CallEngine extends ChangeNotifier {
  CallLink link = CallLink.idle;
  bool micOn = true;
  bool cameraOn = false;
  /// Voice starts on the earpiece like a phone call; video starts on the speaker.
  bool speakerOn = false;
  bool remoteVideoOn = false;
  bool remoteMicOn = true;

  /// 0..1, refreshed about 10 times a second (voice waveform).
  double remoteAudioLevel = 0;

  /// Called when the media connection is gone for good (LiveKit gave up reconnecting).
  VoidCallback? onLost;

  Future<void> join({required String url, required String token, required bool camera});
  Future<void> leave();
  Future<void> setMic(bool on);
  Future<void> setCamera(bool on);
  Future<void> setSpeaker(bool on);
  Widget remoteVideo();
  Widget localVideo();
}

class LiveKitCallEngine extends CallEngine {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  Timer? _levels;
  bool _leaving = false;

  // NFR weak networks: adaptive stream + dynacast + simulcast let 3G receive the low
  // layer; speech-quality audio (24 kbps) stays under the 32 kbps voice budget.
  static const _options = lk.RoomOptions(
    adaptiveStream: true,
    dynacast: true,
    defaultAudioPublishOptions: lk.AudioPublishOptions(encoding: lk.AudioEncoding.presetSpeech),
    defaultVideoPublishOptions: lk.VideoPublishOptions(simulcast: true),
  );

  lk.RemoteParticipant? get _peer => _room?.remoteParticipants.values.firstOrNull;

  @override
  Future<void> join({required String url, required String token, required bool camera}) async {
    await _dispose();
    _leaving = false;
    link = CallLink.connecting;
    notifyListeners();
    final room = lk.Room(roomOptions: _options);
    _room = room;
    _listener = room.createListener()
      ..on<lk.RoomReconnectingEvent>((_) => _setLink(CallLink.reconnecting))
      ..on<lk.RoomReconnectedEvent>((_) => _setLink(CallLink.connected))
      ..on<lk.RoomDisconnectedEvent>((e) {
        if (_leaving || e.reason == lk.DisconnectReason.clientInitiated) return;
        _setLink(CallLink.lost);
        onLost?.call();
      })
      ..on<lk.TrackSubscribedEvent>((_) => _refreshRemote())
      ..on<lk.TrackUnsubscribedEvent>((_) => _refreshRemote())
      ..on<lk.TrackMutedEvent>((_) => _refreshRemote())
      ..on<lk.TrackUnmutedEvent>((_) => _refreshRemote())
      ..on<lk.TrackUnpublishedEvent>((_) => _refreshRemote())
      ..on<lk.ParticipantDisconnectedEvent>((_) => _refreshRemote());
    await room.connect(url, token);
    await room.localParticipant?.setMicrophoneEnabled(micOn);
    if (camera) await setCamera(true);
    speakerOn = camera;
    await lk.Hardware.instance.setSpeakerphoneOn(speakerOn);
    _levels = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final level = _peer?.audioLevel ?? 0;
      if ((level - remoteAudioLevel).abs() > 0.01) {
        remoteAudioLevel = level;
        notifyListeners();
      }
    });
    _refreshRemote();
    _setLink(CallLink.connected);
  }

  void _setLink(CallLink value) {
    link = value;
    notifyListeners();
  }

  void _refreshRemote() {
    final peer = _peer;
    final video = peer?.videoTrackPublications.where((p) => p.subscribed && !p.muted);
    remoteVideoOn = video?.isNotEmpty ?? false;
    remoteMicOn = peer?.audioTrackPublications.any((p) => !p.muted) ?? false;
    notifyListeners();
  }

  @override
  Future<void> setMic(bool on) async {
    micOn = on;
    notifyListeners();
    await _room?.localParticipant?.setMicrophoneEnabled(on);
  }

  @override
  Future<void> setCamera(bool on) async {
    cameraOn = on;
    notifyListeners();
    await _room?.localParticipant?.setCameraEnabled(on);
  }

  @override
  Future<void> setSpeaker(bool on) async {
    speakerOn = on;
    notifyListeners();
    await lk.Hardware.instance.setSpeakerphoneOn(on);
  }

  @override
  Widget remoteVideo() {
    final track = _peer?.videoTrackPublications
        .where((p) => p.subscribed)
        .map((p) => p.track)
        .nonNulls
        .firstOrNull;
    if (track == null) return const SizedBox.expand();
    return lk.VideoTrackRenderer(track, fit: lk.VideoViewFit.cover);
  }

  @override
  Widget localVideo() {
    final track = _room?.localParticipant?.videoTrackPublications
        .map((p) => p.track)
        .nonNulls
        .firstOrNull;
    if (track == null) return const SizedBox.expand();
    return lk.VideoTrackRenderer(track, fit: lk.VideoViewFit.cover);
  }

  @override
  Future<void> leave() async {
    _leaving = true;
    await _dispose();
    link = CallLink.idle;
    remoteVideoOn = false;
    cameraOn = false;
    notifyListeners();
  }

  Future<void> _dispose() async {
    _levels?.cancel();
    await _listener?.dispose();
    _listener = null;
    final room = _room;
    _room = null;
    await room?.disconnect();
    await room?.dispose();
  }
}

/// Widgets listen with ListenableBuilder; the controller drives it.
final callEngineProvider = Provider<CallEngine>((ref) {
  final engine = LiveKitCallEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
