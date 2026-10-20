import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api.dart';
import '../auth/token_store.dart';
import '../config/app_config.dart';

typedef RealtimeEvent = Map<String, dynamic>;

/// Opens a websocket for a URL; swapped out in tests.
typedef SocketConnector = WebSocketChannel Function(Uri uri);

/// The single authenticated websocket at /ws/ (PRD: Realtime). Reconnects with backoff,
/// refreshes the access token when the server closes with 4401, and pings every 25 s so
/// the server's presence count (FR-9) stays fresh.
class RealtimeClient {
  RealtimeClient({
    required TokenStore store,
    required Future<void> Function() refreshToken,
    SocketConnector? connect,
    Uri? endpoint,
  }) : _store = store,
       _refreshToken = refreshToken,
       _connect = connect ?? WebSocketChannel.connect,
       _endpoint = endpoint ?? Uri.parse('${AppConfig.apiBaseUrl.replaceFirst('http', 'ws')}/ws/');

  final TokenStore _store;
  final Future<void> Function() _refreshToken;
  final SocketConnector _connect;
  final Uri _endpoint;

  final _events = StreamController<RealtimeEvent>.broadcast();
  final _connected = StreamController<bool>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _ping;
  Timer? _retry;
  int _attempt = 0;
  bool _wanted = false;
  bool isConnected = false;

  Stream<RealtimeEvent> get events => _events.stream;

  /// Emits true on (re)connect, false on drop.
  Stream<bool> get connection => _connected.stream;

  Future<void> start() async {
    _wanted = true;
    if (_channel == null) await _open();
  }

  Future<void> stop() async {
    _wanted = false;
    _retry?.cancel();
    await _close();
  }

  void send(RealtimeEvent event) {
    _channel?.sink.add(jsonEncode(event));
  }

  Future<void> _open() async {
    final tokens = await _store.readTokens();
    if (tokens == null || !_wanted) return;
    final channel = _connect(_endpoint.replace(queryParameters: {'token': tokens.access}));
    _channel = channel;
    try {
      await channel.ready;
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _attempt = 0;
    isConnected = true;
    _connected.add(true);
    _ping = Timer.periodic(const Duration(seconds: 25), (_) => send({'type': 'ping'}));
    _sub = channel.stream.listen(
      (data) {
        final decoded = jsonDecode(data as String);
        if (decoded is Map<String, dynamic>) _events.add(decoded);
      },
      onDone: () => _dropped(channel.closeCode),
      onError: (_) => _dropped(null),
    );
  }

  Future<void> _dropped(int? code) async {
    await _close();
    if (!_wanted) return;
    if (code == 4401) {
      try {
        await _refreshToken();
      } catch (_) {
        return; // signed out; the session controller takes it from here
      }
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _channel = null;
    if (!_wanted) return;
    // 0.5 s, 1 s, 2 s … capped at 8 s, so a dropped link is back well within 10 s (NFR).
    final delay = Duration(milliseconds: min(8000, 500 * pow(2, _attempt).toInt()));
    _attempt++;
    _retry?.cancel();
    _retry = Timer(delay, _open);
  }

  Future<void> _close() async {
    _ping?.cancel();
    await _sub?.cancel();
    _sub = null;
    final channel = _channel;
    _channel = null;
    if (isConnected) {
      isConnected = false;
      _connected.add(false);
    }
    await channel?.sink.close();
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _connected.close();
  }
}

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient(
    store: ref.watch(tokenStoreProvider),
    // Any authenticated call runs the dio interceptor, which refreshes the token.
    refreshToken: () => ref.read(apiProvider).me.meVerificationRetrieve(),
  );
  ref.onDispose(client.dispose);
  return client;
});
