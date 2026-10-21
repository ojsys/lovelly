import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lovelly_api/lovelly_api.dart' as gen show ChatMessage;

import '../../api/api.dart' hide ChatMessage;
import '../../auth/my_id.dart';
import '../../platform/permissions.dart';
import '../../realtime/realtime_client.dart';
import '../match/match_controller.dart';
import '../plus/plus_repository.dart';
import 'friends_repository.dart';

/// The Friends screen (07): friends, unread counts and incoming requests (FR-16, FR-17).
class FriendsController extends AsyncNotifier<Friends> {
  FriendsRepository get _repo => ref.read(friendsRepositoryProvider);

  @override
  Future<Friends> build() async {
    final rt = ref.read(realtimeClientProvider);
    final sub = rt.events.listen((e) {
      final t = e['type'];
      if (t == 'friend.request' ||
          t == 'friend.accepted' ||
          (t == 'chat.message' && e['chat_id'] != null)) {
        refresh();
      }
    });
    // Presence (the "online now" row) changes without events: refresh while watched.
    final timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    ref.onDispose(() {
      sub.cancel();
      timer.cancel();
    });
    await rt.start();
    return _repo.friends();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.friends);
  }

  Future<void> accept(String requestId) async {
    await _repo.accept(requestId);
    await refresh();
  }

  Future<void> decline(String requestId) async {
    await _repo.decline(requestId);
    await refresh();
  }
}

final friendsControllerProvider = AsyncNotifierProvider<FriendsController, Friends>(
  FriendsController.new,
);

// --- Friend chat (FR-15, FR-16, FR-17) ---------------------------------------------------

class FriendChatState {
  const FriendChatState({
    this.friend,
    this.messages = const [],
    this.more = false,
    this.loading = true,
    this.peerTyping = false,
    this.error,
  });

  final FriendSummary? friend;

  /// Oldest first.
  final List<ChatMessage> messages;
  final bool more;
  final bool loading;
  final bool peerTyping;
  final String? error;

  FriendChatState copyWith({
    FriendSummary? friend,
    List<ChatMessage>? messages,
    bool? more,
    bool? loading,
    bool? peerTyping,
    String? error,
  }) => FriendChatState(
    friend: friend ?? this.friend,
    messages: messages ?? this.messages,
    more: more ?? this.more,
    loading: loading ?? this.loading,
    peerTyping: peerTyping ?? this.peerTyping,
    error: error,
  );
}

class FriendChatController extends Notifier<FriendChatState> {
  FriendChatController(this.chatId);

  final String chatId;
  Timer? _typingTimer;
  DateTime? _lastTypingSent;
  String? _myId;

  RealtimeClient get _rt => ref.read(realtimeClientProvider);

  ChatMessage _toMessage(gen.ChatMessage m) => ChatMessage(
    id: m.id,
    mine: m.senderId == _myId,
    body: m.body,
    sentAt: m.sentAt.toLocal(),
    seen: m.seenAt != null,
    flagged: m.flagged,
    flagReason: m.flagReason,
    system: m.kind == 'system',
    gift: m.kind == 'gift',
  );

  @override
  FriendChatState build() {
    final sub = _rt.events.listen(_onEvent);
    ref.onDispose(() {
      sub.cancel();
      _typingTimer?.cancel();
    });
    _load();
    return const FriendChatState();
  }

  Future<void> _load() async {
    try {
      _myId = await ref.read(myUserIdProvider.future);
      await _rt.start();
      final page = await ref.read(friendsRepositoryProvider).history(chatId);
      state = state.copyWith(
        friend: page.friend,
        messages: [for (final m in page.messages.reversed) _toMessage(m)],
        more: page.more,
        loading: false,
      );
      markSeen();
    } on ApiFailure catch (e) {
      state = state.copyWith(loading: false, error: e.detail);
    }
  }

  Future<void> loadOlder() async {
    if (!state.more || state.messages.isEmpty) return;
    final oldest = state.messages.first.sentAt.toUtc().toIso8601String();
    final page = await ref.read(friendsRepositoryProvider).history(chatId, before: oldest);
    state = state.copyWith(
      messages: [for (final m in page.messages.reversed) _toMessage(m), ...state.messages],
      more: page.more,
    );
  }

  void send(String body) {
    final text = body.trim();
    if (text.isEmpty) return;
    _rt.send({'type': 'chat.message', 'chat_id': chatId, 'body': text});
  }

  void markSeen() {
    final last = state.messages.where((m) => !m.mine && !m.system).lastOrNull;
    if (last != null) _rt.send({'type': 'chat.seen', 'chat_id': chatId, 'message_id': last.id});
  }

  void typing() {
    final now = DateTime.now();
    if (_lastTypingSent != null && now.difference(_lastTypingSent!).inSeconds < 3) return;
    _lastTypingSent = now;
    _rt.send({'type': 'chat.typing', 'chat_id': chatId});
  }

  void _onEvent(RealtimeEvent e) {
    if (e['chat_id'] != chatId) return;
    switch (e['type']) {
      case 'chat.message':
        final m = ChatMessage.fromJson(e['message'] as Map<String, dynamic>, _myId ?? '');
        if (state.messages.any((x) => x.id == m.id)) return;
        state = state.copyWith(messages: [...state.messages, m], peerTyping: false);
        if (!m.mine) markSeen();
      case 'chat.seen':
        final upto = state.messages.indexWhere((m) => m.id == e['message_id']);
        state = state.copyWith(
          messages: [
            for (final (i, m) in state.messages.indexed)
              m.mine && i <= upto ? m.copyWith(seen: true) : m,
          ],
        );
      case 'chat.typing':
        state = state.copyWith(peerTyping: true);
        _typingTimer?.cancel();
        _typingTimer = Timer(
          const Duration(seconds: 4),
          () => state = state.copyWith(peerTyping: false),
        );
      case 'error':
        state = state.copyWith(error: e['detail'] as String?);
    }
  }
}

final friendChatProvider = NotifierProvider.autoDispose
    .family<FriendChatController, FriendChatState, String>(FriendChatController.new);

// --- Friend calls (FR-16) ------------------------------------------------------------------

enum InviteDirection { none, outgoing, incoming }

class CallInvite {
  const CallInvite({
    this.direction = InviteDirection.none,
    this.inviteId,
    this.chatId,
    this.mode = MatchMode.video,
    this.name = '',
    this.notice,
    this.rematch = false,
  });

  final InviteDirection direction;
  final String? inviteId;
  final String? chatId;
  final MatchMode mode;
  final String name;

  /// "Kwame declined", "No answer" — shown once.
  final String? notice;

  /// A paid rematch with someone skipped earlier (FR-7), not a friend call.
  final bool rematch;
}

class CallInviteController extends Notifier<CallInvite> {
  RealtimeClient get _rt => ref.read(realtimeClientProvider);

  @override
  CallInvite build() {
    final sub = _rt.events.listen(_onEvent);
    ref.onDispose(sub.cancel);
    return const CallInvite();
  }

  Future<void> call(String chatId, MatchMode mode, String name) async {
    await _rt.start();
    _rt.send({'type': 'call.invite', 'chat_id': chatId, 'mode': mode.name});
    state = CallInvite(direction: InviteDirection.outgoing, chatId: chatId, mode: mode, name: name);
  }

  /// FR-7: ring someone you just skipped (20 coins, held now; free with Plus).
  Future<String?> rematch(String sessionId, String name, MatchMode mode) async {
    try {
      await _rt.start();
      final inviteId = await ref.read(plusRepositoryProvider).rematch(sessionId);
      state = CallInvite(
        direction: InviteDirection.outgoing,
        inviteId: inviteId,
        mode: mode,
        name: name,
        rematch: true,
      );
      return null;
    } on ApiFailure catch (e) {
      return e.detail;
    }
  }

  /// Shown when the app was opened from a call push (the invite may have ended).
  void incomingFromPush({
    required String inviteId,
    required String chatId,
    required MatchMode mode,
    required String name,
  }) {
    state = CallInvite(
      direction: InviteDirection.incoming,
      inviteId: inviteId,
      chatId: chatId,
      mode: mode,
      name: name,
    );
  }

  /// FR-5: video needs the camera; both need the microphone.
  Future<bool> accept() async {
    final invite = state;
    if (invite.direction != InviteDirection.incoming || invite.inviteId == null) return false;
    final gateway = ref.read(permissionGatewayProvider);
    final needed = [
      if (invite.mode != MatchMode.text) DevicePermission.microphone,
      if (invite.mode == MatchMode.video) DevicePermission.camera,
    ];
    for (final p in needed) {
      var grant = await gateway.status(p);
      if (grant != GrantState.granted) grant = await gateway.request(p);
      if (grant != GrantState.granted) {
        decline();
        state = const CallInvite(
          notice: 'Allow the camera and microphone in Settings to take calls.',
        );
        return false;
      }
    }
    await _rt.start();
    _rt.send({'type': 'call.accept', 'invite_id': invite.inviteId});
    return true;
  }

  void decline() {
    if (state.inviteId != null) _rt.send({'type': 'call.decline', 'invite_id': state.inviteId});
    state = const CallInvite();
  }

  void cancel() {
    if (state.inviteId != null) _rt.send({'type': 'call.cancel', 'invite_id': state.inviteId});
    state = const CallInvite();
  }

  void clearNotice() => state = CallInvite(
    direction: state.direction,
    inviteId: state.inviteId,
    chatId: state.chatId,
    mode: state.mode,
    name: state.name,
    rematch: state.rematch,
  );

  void _onEvent(RealtimeEvent e) {
    switch (e['type']) {
      case 'call.incoming':
        final from = e['from'] as Map<String, dynamic>;
        state = CallInvite(
          direction: InviteDirection.incoming,
          inviteId: e['invite_id'] as String,
          chatId: e['chat_id'] as String?,
          mode: MatchMode.values.byName(e['mode'] as String),
          name: from['first_name'] as String? ?? '',
          rematch: e['rematch'] as bool? ?? false,
        );
      case 'call.ringing' when state.direction == InviteDirection.outgoing:
        state = CallInvite(
          direction: InviteDirection.outgoing,
          inviteId: e['invite_id'] as String,
          chatId: state.chatId,
          mode: state.mode,
          name: state.name,
          rematch: state.rematch,
        );
      case 'call.declined':
        state = CallInvite(notice: '${state.name} can’t talk right now.');
      case 'call.missed':
        state = CallInvite(
          notice: state.direction == InviteDirection.outgoing ? 'No answer.' : 'You missed a call.',
        );
      case 'call.cancelled':
        state = const CallInvite();
      case 'match.found' when e['chat_id'] != null || e['rematch'] == true:
        state = const CallInvite(); // connected: the call screens take over
      case 'error' when state.direction == InviteDirection.outgoing:
        state = CallInvite(notice: e['detail'] as String?);
    }
  }
}

final callInviteProvider = NotifierProvider<CallInviteController, CallInvite>(
  CallInviteController.new,
);

/// Sessions where we've already tapped "Add friend" (FR-14), so the button shows "sent".
class FriendRequestsSent extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  Future<String?> add(String sessionId) async {
    if (state.contains(sessionId)) return null;
    try {
      await ref.read(friendsRepositoryProvider).request(sessionId);
      state = {...state, sessionId};
      return null;
    } on ApiFailure catch (e) {
      if (e.code == 'already_friends') state = {...state, sessionId};
      return e.detail;
    }
  }
}

final friendRequestsSentProvider = NotifierProvider<FriendRequestsSent, Set<String>>(
  FriendRequestsSent.new,
);
