import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_store.dart';

/// Our own user id, from the access token's `user_id` claim (to tell our messages apart).
Future<String?> readMyUserId(TokenStore store) async {
  final token = (await store.readTokens())?.access;
  final parts = token?.split('.');
  if (parts == null || parts.length != 3) return null;
  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    return (payload as Map<String, dynamic>)['user_id'] as String?;
  } catch (_) {
    return null;
  }
}

final myUserIdProvider = FutureProvider<String?>(
  (ref) => readMyUserId(ref.watch(tokenStoreProvider)),
);
