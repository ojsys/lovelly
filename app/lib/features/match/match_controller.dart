import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../auth/session.dart';
import '../../auth/token_store.dart';
import '../../realtime/realtime_client.dart';

enum MatchMode {
  video('Video', 'Video chat'),
  voice('Voice', 'Voice only'),
  text('Text', 'Text only');

  const MatchMode(this.label, this.tag);

  final String label;
  final String tag;
}

enum MatchPhase { idle, searching, matched, ended }

class Peer {
  const Peer({
    required this.firstName,
    this.age,
    this.city = '',
    this.sharedInterests = const [],
    this.sharedLanguages = const [],
    this.verified = false,
  });

  factory Peer.fromJson(Map<String, dynamic> json) => Peer(
    firstName: json['first_name'] as String? ?? '',
    age: (json['age'] as num?)?.toInt(),
    city: json['city'] as String? ?? '',
    sharedInterests: [...?(json['shared_interests'] as List?)?.cast<String>()],
    sharedLanguages: [...?(json['shared_languages'] as List?)?.cast<String>()],
    verified: json['verified'] as bool? ?? false,
  );

  final String firstName;
  final int? age;
  final String city;
  final List<String> sharedInterests;
  final List<String> sharedLanguages;
  final bool verified;

  String get initial =>
      firstName.isEmpty ? '?' : String.fromCharCode(firstName.runes.first).toUpperCase();
  String get title => age == null ? firstName : '$firstName, $age';
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.mine,
    required this.body,
    required this.sentAt,
    this.seen = false,
    this.flagged = false,
    this.flagReason = '',
    this.system = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String myId) => ChatMessage(
    id: json['id'] as String,
    mine: json['sender_id'] == myId,
    body: json['body'] as String,
    sentAt: DateTime.parse(json['sent_at'] as String).toLocal(),
    seen: json['seen_at'] != null,
    flagged: json['flagged'] as bool? ?? false,
    flagReason: json['flag_reason'] as String? ?? '',
    system: json['kind'] == 'system',
  );

  final String id;
  final bool mine;
  final String body;
  final DateTime sentAt;
  final bool seen;
  final bool flagged;
  final String flagReason;

  /// "Missed video call" and similar lines (not typed by anyone).
  final bool system;

  ChatMessage copyWith({bool? seen}) => ChatMessage(
    id: id,
    mine: mine,
    body: body,
    sentAt: sentAt,
    seen: seen ?? this.seen,
    flagged: flagged,
    flagReason: flagReason,
    system: system,
  );
}

class MatchError {
  const MatchError(this.code, this.detail, {this.retryAfter});

  final String code;
  final String detail;
  final int? retryAfter;
}

class MatchState {
  const MatchState({
    this.phase = MatchPhase.idle,
    this.mode = MatchMode.video,
    this.searchingSince,
    this.widened = false,
    this.sessionId,
    this.peer,
    this.roomName,
    this.mediaToken,
    this.mediaUrl,
    this.chatId,
    this.messages = const [],
    this.peerTyping = false,
    this.endReason,
    this.error,
  });

  final MatchPhase phase;
  final MatchMode mode;
  final DateTime? searchingSince;
  final bool widened;
  final String? sessionId;
  final Peer? peer;
  final String? roomName;
  final String? mediaToken;
  final String? mediaUrl;

  /// Set for a direct call between friends (FR-16); null for random matches.
  final String? chatId;
  final List<ChatMessage> messages;
  final bool peerTyping;

  /// Why the session ended: peer_next | peer_left | blocked.
  final String? endReason;
  final MatchError? error;

  MatchState copyWith({
    MatchPhase? phase,
    MatchMode? mode,
    DateTime? searchingSince,
    bool? widened,
    String? sessionId,
    Peer? peer,
    String? roomName,
    String? mediaToken,
    String? mediaUrl,
    List<ChatMessage>? messages,
    bool? peerTyping,
    String? endReason,
    MatchError? error,
    bool clearError = false,
  }) => MatchState(
    phase: phase ?? this.phase,
    mode: mode ?? this.mode,
    searchingSince: searchingSince ?? this.searchingSince,
    widened: widened ?? this.widened,
    sessionId: sessionId ?? this.sessionId,
    peer: peer ?? this.peer,
    roomName: roomName ?? this.roomName,
    mediaToken: mediaToken ?? this.mediaToken,
    mediaUrl: mediaUrl ?? this.mediaUrl,
    chatId: chatId,
    messages: messages ?? this.messages,
    peerTyping: peerTyping ?? this.peerTyping,
    endReason: endReason ?? this.endReason,
    error: clearError ? null : error ?? this.error,
  );
}

/// Client side of matching and stranger chat (FR-6, FR-9, FR-12, FR-15, FR-17).
class MatchController extends Notifier<MatchState> {
  /// Overridable clock for tests.
  DateTime Function() now = DateTime.now;

  RealtimeClient get _rt => ref.read(realtimeClientProvider);
  String? _myId;
  Timer? _typingTimer;
  DateTime? _lastTypingSent;

  @override
  MatchState build() {
    final subs = [_rt.events.listen(_onEvent), _rt.connection.listen(_onConnection)];
    ref.onDispose(() {
      for (final s in subs) {
        s.cancel();
      }
      _typingTimer?.cancel();
    });
    return const MatchState();
  }

  void setMode(MatchMode mode) {
    if (state.phase == MatchPhase.idle) state = state.copyWith(mode: mode);
  }

  /// Starts searching in [mode] (Home's "Start matching").
  Future<void> start([MatchMode? mode]) async {
    _myId ??= await _readMyId();
    final m = mode ?? state.mode;
    state = MatchState(phase: MatchPhase.searching, mode: m, searchingSince: now());
    await _rt.start();
    _rt.send({'type': 'queue.join', 'mode': m.name, 'filters': <String, dynamic>{}});
  }

  void cancel() {
    _rt.send({'type': 'queue.leave'});
    state = MatchState(mode: state.mode);
  }

  /// Next: end this match and go straight back to searching (FR-12).
  void next() {
    final id = state.sessionId;
    if (id == null) return;
    _rt.send({'type': 'session.next', 'session_id': id});
    state = MatchState(phase: MatchPhase.searching, mode: state.mode, searchingSince: now());
  }

  /// End: leave this match and go home (FR-12).
  void end() {
    final id = state.sessionId;
    if (id != null && state.phase == MatchPhase.matched) {
      _rt.send({'type': 'session.end', 'session_id': id});
    }
    state = MatchState(mode: state.mode);
  }

  void clearError() => state = state.copyWith(clearError: true);

  void sendMessage(String body) {
    final text = body.trim();
    final id = state.sessionId;
    if (text.isEmpty || id == null || state.phase != MatchPhase.matched) return;
    _rt.send({'type': 'chat.message', 'session_id': id, 'body': text});
  }

  /// Tells the peer we've seen their latest message (FR-17).
  void markSeen() {
    final id = state.sessionId;
    final last = state.messages.where((m) => !m.mine).lastOrNull;
    if (id == null || last == null || state.phase != MatchPhase.matched) return;
    _rt.send({'type': 'chat.seen', 'session_id': id, 'message_id': last.id});
  }

  /// At most one typing event every 3 s.
  void typing() {
    final id = state.sessionId;
    if (id == null || state.phase != MatchPhase.matched) return;
    final t = now();
    if (_lastTypingSent != null && t.difference(_lastTypingSent!).inSeconds < 3) return;
    _lastTypingSent = t;
    _rt.send({'type': 'chat.typing', 'session_id': id});
  }

  void _onEvent(RealtimeEvent e) {
    final forSession = e['session_id'] == state.sessionId;
    switch (e['type']) {
      case 'match.found':
        state = MatchState(
          phase: MatchPhase.matched,
          mode: MatchMode.values.byName(e['mode'] as String),
          sessionId: e['session_id'] as String,
          peer: Peer.fromJson(e['peer'] as Map<String, dynamic>),
          roomName: e['room_name'] as String?,
          mediaToken: e['media_token'] as String?,
          mediaUrl: e['media_url'] as String?,
          chatId: e['chat_id'] as String?,
        );
      case 'match.widened' when state.phase == MatchPhase.searching:
        state = state.copyWith(widened: true);
      case 'session.ended' when forSession:
        _sessionEnded(e['reason'] as String);
      case 'chat.message' when forSession:
        final message = ChatMessage.fromJson(e['message'] as Map<String, dynamic>, _myId ?? '');
        state = state.copyWith(messages: [...state.messages, message], peerTyping: false);
      case 'chat.seen' when forSession:
        final upto = state.messages.indexWhere((m) => m.id == e['message_id']);
        state = state.copyWith(
          messages: [
            for (final (i, m) in state.messages.indexed)
              m.mine && i <= upto ? m.copyWith(seen: true) : m,
          ],
        );
      case 'chat.typing' when forSession:
        state = state.copyWith(peerTyping: true);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 4), () {
          if (state.peerTyping) state = state.copyWith(peerTyping: false);
        });
      case 'error':
        _onError(e);
      case 'account.closed':
        // SF-6: suspended or banned. The session screen takes over.
        state = MatchState(mode: state.mode);
        ref.read(sessionProvider.notifier).refresh();
    }
  }

  void _sessionEnded(String reason) {
    switch (reason) {
      case 'next':
        break; // we pressed Next: already searching, and the server re-queued us
      case 'end' || 'blocked':
        if (state.phase == MatchPhase.matched) state = MatchState(mode: state.mode);
      case 'moderation':
        // SF-2: ended by the moderation agent or a moderator. Never auto-requeue.
        state = state.copyWith(phase: MatchPhase.ended, endReason: reason, peerTyping: false);
      default: // peer_next | peer_left
        if (state.chatId != null) {
          state = MatchState(mode: state.mode); // friend call over: back to the chat
          return;
        }
        if (state.mode == MatchMode.text) {
          // Text: show "<name> left" and let the user choose (M2 decision 1).
          state = state.copyWith(phase: MatchPhase.ended, endReason: reason, peerTyping: false);
        } else {
          // Calls: straight back into the queue, so Next puts both back in it.
          start(state.mode);
        }
    }
  }

  void _onError(RealtimeEvent e) {
    final error = MatchError(
      e['code'] as String? ?? 'error',
      e['detail'] as String? ?? 'Something went wrong.',
      retryAfter: (e['retry_after'] as num?)?.toInt(),
    );
    if (e['request'] == 'queue.join' && error.code != 'in_session') {
      state = MatchState(mode: state.mode, error: error);
    } else {
      state = state.copyWith(error: error);
    }
  }

  /// After a reconnect: re-join the queue (the server drops queued users on disconnect)
  /// or resync the chat we were in (the server keeps it for 10 s).
  Future<void> _onConnection(bool connected) async {
    if (!connected) return;
    if (state.phase == MatchPhase.searching) {
      _rt.send({'type': 'queue.join', 'mode': state.mode.name, 'filters': <String, dynamic>{}});
    } else if (state.phase == MatchPhase.matched && state.sessionId != null) {
      try {
        final detail = await ref
            .read(apiProvider)
            .sessions
            .sessionsRetrieve(sessionId: state.sessionId!);
        if (detail.endedAt != null) {
          state = state.copyWith(phase: MatchPhase.ended, endReason: 'peer_left');
          return;
        }
        state = state.copyWith(
          messages: [
            for (final m in detail.messages)
              ChatMessage(
                id: m.id,
                mine: m.senderId == _myId,
                body: m.body,
                sentAt: m.sentAt.toLocal(),
                seen: m.seenAt != null,
                flagged: m.flagged,
                flagReason: m.flagReason,
              ),
          ],
        );
      } catch (_) {
        // Keep what we have; the next event will correct it.
      }
    }
  }

  /// Our user id, from the access token's `user_id` claim.
  Future<String?> _readMyId() async {
    final token = (await ref.read(tokenStoreProvider).readTokens())?.access;
    final parts = token?.split('.');
    if (parts == null || parts.length != 3) return null;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return (payload as Map<String, dynamic>)['user_id'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final matchControllerProvider = NotifierProvider<MatchController, MatchState>(MatchController.new);
