// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/gift_send_request_request.dart';
import '../models/gift_sent.dart';
import '../models/media_token.dart';
import '../models/session_detail.dart';

part 'sessions_client.g.dart';

@RestApi()
abstract class SessionsClient {
  factory SessionsClient(Dio dio, {String? baseUrl}) = _SessionsClient;

  /// A session the user took part in, with its messages (to resume after a reconnect).
  @GET('/api/v1/sessions/{session_id}')
  Future<SessionDetail> sessionsRetrieve({@Path('session_id') required String sessionId});

  @POST('/api/v1/sessions/{session_id}/gifts')
  Future<GiftSent> sessionsGiftsCreate({
    @Path('session_id') required String sessionId,
    @Body() required GiftSendRequestRequest body,
  });

  /// A fresh LiveKit join token to rejoin a call after a drop.
  @POST('/api/v1/sessions/{session_id}/media-token')
  Future<MediaToken> sessionsMediaTokenCreate({@Path('session_id') required String sessionId});
}
