// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/session_detail.dart';

part 'sessions_client.g.dart';

@RestApi()
abstract class SessionsClient {
  factory SessionsClient(Dio dio, {String? baseUrl}) = _SessionsClient;

  /// A session the user took part in, with its messages (to resume after a reconnect).
  @GET('/api/v1/sessions/{session_id}')
  Future<SessionDetail> sessionsRetrieve({@Path('session_id') required String sessionId});
}
