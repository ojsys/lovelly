import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_store.dart';
import '../config/app_config.dart';
import 'package:korram_api/korram_api.dart';

export 'package:korram_api/korram_api.dart';

/// A server error with its stable `code` (see backend core/exceptions.py).
class ApiFailure implements Exception {
  const ApiFailure(this.code, this.detail, {this.retryAfter, this.status});

  final String code;
  final String detail;
  final int? retryAfter;
  final int? status;

  static const network = ApiFailure('network', "Can't reach Korram. Check your connection.");

  factory ApiFailure.from(Object error) {
    if (error is ApiFailure) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['code'] is String) {
        return ApiFailure(
          data['code'] as String,
          (data['detail'] as String?) ?? 'Something went wrong.',
          retryAfter: (data['retry_after'] as num?)?.toInt(),
          status: error.response?.statusCode,
        );
      }
      if (error.response == null) return network;
    }
    return const ApiFailure('unknown', 'Something went wrong. Try again.');
  }

  @override
  String toString() => 'ApiFailure($code: $detail)';
}

/// Attaches the access token and refreshes it once on a 401.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._store, this._refreshDio, {required this.onSignedOut});

  final TokenStore _store;
  final Dio _refreshDio;
  final void Function() onSignedOut;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final tokens = await _store.readTokens();
    if (tokens != null) options.headers['Authorization'] = 'Bearer ${tokens.access}';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final tokens = await _store.readTokens();
    final retried = err.requestOptions.extra['retried'] == true;
    if (err.response?.statusCode != 401 || tokens == null || retried) {
      return handler.next(err);
    }
    try {
      final fresh = await KorramApi(
        _refreshDio,
      ).auth.authRefreshCreate(body: TokenRefreshRequest(refresh: tokens.refresh));
      await _store.writeTokens(access: fresh.access, refresh: fresh.refresh);
      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${fresh.access}'
        ..extra['retried'] = true;
      handler.resolve(await _refreshDio.fetch(options));
    } on DioException {
      onSignedOut();
      handler.next(err);
    }
  }
}

final dioProvider = Provider<Dio>((ref) {
  final options = BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  );
  final dio = Dio(options);
  dio.interceptors.add(
    AuthInterceptor(
      ref.watch(tokenStoreProvider),
      Dio(options),
      onSignedOut: () => ref.read(signedOutSignalProvider.notifier).fire(),
    ),
  );
  return dio;
});

final apiProvider = Provider<KorramApi>((ref) => KorramApi(ref.watch(dioProvider)));

/// Fires when a refresh fails, so the session can sign out.
final signedOutSignalProvider = NotifierProvider<SignedOutSignal, int>(SignedOutSignal.new);

class SignedOutSignal extends Notifier<int> {
  @override
  int build() => 0;

  void fire() => state++;
}
